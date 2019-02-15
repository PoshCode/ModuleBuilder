function MoveUsingStatements {
    <#
        .SYNOPSIS
            A command to comment out and copy to the top of the file the Using Statements
        .DESCRIPTION
            When all files are merged together, the Using statements from individual files
            don't  necessarily end up at the beginning of the PSM1, creating Parsing Errors.

            This function uses AST to comment out those statements (to preserver line numbering)
            and insert them (conserving order) at the top of the script.

            Should the merged RootModule already have errors not related to the Using statements,
            or no errors caused by misplaced Using statements, this steps is skipped.

            If moving (comment & copy) the Using statements introduce parsing errors to the script,
            those changes won't be applied to the file.
    #>
    [CmdletBinding()]
    Param(
        # Path to the PSM1 file to amend
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        $RootModule,

        # The encoding defaults to UTF8 (or UTF8NoBom on Core)
        [Parameter(DontShow)]
        [string]$Encoding = $(if ($IsCoreCLR) { "UTF8NoBom" } else { "UTF8" })
    )

    $ParseError = $null
    $AST = [System.Management.Automation.Language.Parser]::ParseFile(
        $RootModule,
        [ref]$null,
        [ref]$ParseError
    )

    # Avoid modifying the file if there's no Parsing Error caused by Using Statements or other errors
    if (!$ParseError.Where{$_.ErrorId -eq 'UsingMustBeAtStartOfScript'}) {
        Write-Debug "No Using Statement Error found."
        return
    }
    # Avoid modifying the file if there's other parsing errors than Using Statements misplaced
    if ($ParseError.Where{$_.ErrorId -ne 'UsingMustBeAtStartOfScript'}) {
        Write-Warning "Parsing errors found. Skipping Moving Using statements."
        return
    }

    # Find all Using statements including those non erroring (to conserve their order)
    $UsingStatementExtents = $AST.FindAll(
        {$Args[0] -is [System.Management.Automation.Language.UsingStatementAst]},
        $false
    ).Extent

    # Edit the Script content by commenting out existing statements (conserving line numbering)
    $ScriptText = $AST.Extent.Text
    $InsertedCharOffset = 0
    $StatementsToCopy = New-Object System.Collections.ArrayList
    foreach ($UsingSatement in $UsingStatementExtents) {
        $ScriptText = $ScriptText.Insert($UsingSatement.StartOffset + $InsertedCharOffset, '#')
        $InsertedCharOffset++

        # Keep track of unique statements we'll need to insert at the top
        if (!$StatementsToCopy.Contains($UsingSatement.Text)) {
            $null = $StatementsToCopy.Add($UsingSatement.Text)
        }
    }

    $ScriptText = $ScriptText.Insert(0, ($StatementsToCopy -join "`r`n") + "`r`n")

    # Verify we haven't introduced new Parsing errors
    $null = [System.Management.Automation.Language.Parser]::ParseInput(
        $ScriptText,
        [ref]$null,
        [ref]$ParseError
    )

    if ($ParseError) {
        Write-Warning "Oops, it seems that we introduced parsing error(s) while moving the Using Statements. Cancelling changes."
    }
    else {
        $null = Set-Content -Value $ScriptText -Path $RootModule -Encoding $Encoding
    }
}