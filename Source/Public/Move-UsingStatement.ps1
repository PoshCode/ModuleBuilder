using namespace System.Management.Automation.Language

function Move-UsingStatement {
    <#
        .SYNOPSIS
            A Script Generator that commetnts out using statements and copies them to the top of the file
        .DESCRIPTION
            Move-UsingStatement supports having using statements repeated in multiple files that are merged by ModuleBuilder.
            When all the files are merged together, the using statements from individual files
            don't necessarily end up at the beginning of the PSM1, which creates Parsing Errors.

            This function uses the AST to generate TextReplacements to:
            1. Comment out the original using statements (to preserve line numbering)
            2. Insert the using statements (conserving order, but removing duplicates) at the top of the script
    #>
    [CmdletBinding()]
    [OutputType([TextReplacement])]
    param(
        # The AST of the original script module to refactor
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias("Ast")]
        [Ast]$InputObject,

        # Parser Errors from parsing the original script module
        [Parameter(ValueFromPipelineByPropertyName)]
        [AllowNull()]
        [ParseError[]]$ParseErrors
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
        $UsingStatementExtents = $InputObject.FindAll(
            { $Args[0] -is [System.Management.Automation.Language.UsingStatementAst] },
            $false
        ).Extent

        # Edit the Script content by commenting out existing statements (conserving line numbering)
        $StatementsToCopy = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($UsingSatement in $UsingStatementExtents) {
            [TextReplacement]@{
                StartOffset = $UsingSatement.StartOffset
                EndOffset   = $UsingSatement.EndOffset
                Text        = '# ' + $UsingSatement.Text
            }
            # Keep track of unique statements we'll need to insert at the top
            $null = $StatementsToCopy.Add($UsingSatement.Text)
        }
        if ($StatementsToCopy.Count -gt 0) {
            [TextReplacement]@{
                StartOffset = 0
                EndOffset   = 0
                Text        = ($StatementsToCopy -join "`r`n")+ "`r`n"
            }
        }
    }
}
