function MoveUsingStatements {
    <#
        .SYNOPSIS
            A command to comment out and copy to the top of the file the Using Statements
        .DESCRIPTION
            When all files are merged together, the Using statements from individual files
            don't  necessarily end up at the beginning of the PSM1, creating Parsing Errors.

            This function uses AST to comment out those statements (to preserver line numbering)
            and insert them (conserving order) at the top of the script.
    #>
    [CmdletBinding()]
    param(
        # Path to the PSM1 file to amend
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [System.Management.Automation.Language.Ast]$AST,

        [Parameter(ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [AllowNull()]
        [System.Management.Automation.Language.ParseError[]]$ParseErrors,

        # The encoding defaults to UTF8 (or UTF8NoBom on Core)
        [Parameter(DontShow)]
        [string]$Encoding = $(if ($IsCoreCLR) {
                "UTF8NoBom"
            } else {
                "UTF8"
            })
    )
    process {
        # Avoid modifying the file if there's no Parsing Error caused by Using Statements or other errors
        if (!$ParseErrors.Where{ $_.ErrorId -eq 'UsingMustBeAtStartOfScript' }) {
            Write-Debug "No using statement errors found."
            return
        } else {
            # as decided https://github.com/PoshCode/ModuleBuilder/issues/96
            Write-Debug "Parsing errors found. We'll still attempt to Move using statements."
        }

        # Find all Using statements including those non erroring (to conserve their order)
        $UsingStatementExtents = $AST.FindAll(
            { $Args[0] -is [System.Management.Automation.Language.UsingStatementAst] },
            $false
        ).Extent

        # Edit the Script content by commenting out existing statements (conserving line numbering)
        $ScriptText = $AST.Extent.Text
        $InsertedCharOffset = 0
        $StatementsToCopy = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($UsingSatement in $UsingStatementExtents) {
            $ScriptText = $ScriptText.Insert($UsingSatement.StartOffset + $InsertedCharOffset, '#')
            $InsertedCharOffset++

            # Keep track of unique statements we'll need to insert at the top
            $null = $StatementsToCopy.Add($UsingSatement.Text)
        }

        $ScriptText = $ScriptText.Insert(0, ($StatementsToCopy -join "`r`n") + "`r`n")
        $null = Set-Content -Value $ScriptText -Path $RootModule -Encoding $Encoding

        # Verify we haven't introduced new Parsing errors
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $RootModule,
            [ref]$null,
            [ref]$ParseErrors
        )

        if ($ParseErrors.Count) {
            $Message = $ParseErrors |
                Format-Table -Auto @{n = "File"; expr = { $_.Extent.File | Split-Path -Leaf }},
                                @{n = "Line"; expr = { $_.Extent.StartLineNumber }},
                                Extent, ErrorId, Message | Out-String
            Write-Warning "Parse errors in build output:`n$Message"
        }
    }
}
