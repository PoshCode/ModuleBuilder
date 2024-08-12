using namespace System.Management.Automation.Language

function Add-Parameter {
    <#
        .SYNOPSIS
            Adds parameters from one script or function to another.
        .DESCRIPTION
            Add-Parameter will copy parameters from the boilerplate to the function(s) in the InputObject without overwriting existing parameters.

            It is usually used in conjunction with Merge-Block to merge a common implementation from the boilerplate.

            Note that THIS generator does not add parameters to script files directly, but only to functions defined in the InputObject.
        .EXAMPLE
        # Or use a file path instead
        $Boilerplate = @'
            param(
                # The Foreground Color (name, #rrggbb, etc)
                [Alias('Fg')]
                [PoshCode.Pansies.RgbColor]$ForegroundColor,

                # The Background Color (name, #rrggbb, etc)
                [Alias('Bg')]
                [PoshCode.Pansies.RgbColor]$BackgroundColor
            )
            $ForegroundColor.ToVt() + $BackgroundColor.ToVt($true) + (
            Use-OriginalBlock
            ) +"`e[0m" # Reset colors
        '@

        # Or use a file path instead
        $Source = @'
        function Show-Date {
            param(
                # The text to display
                [string]$Format
            )
            Get-Date -Format $Format
        }
        '@

        Invoke-ScriptGenerator $Source -Generator Add-Parameter -Parameters @{ FunctionName = "*"; Boilerplate = $Boilerplate } -OutVariable Source

        function Show-Date {
            param(
                # The text to display
                [string]$Format,

                # The Foreground Color (name, #rrggbb, etc)
                [Alias('Fg')]
                [PoshCode.Pansies.RgbColor]$ForegroundColor,

                # The Background Color (name, #rrggbb, etc)
                [Alias('Bg')]
                [PoshCode.Pansies.RgbColor]$BackgroundColor
            )
            Get-Date -Format $Format
        }
    #>
    [CmdletBinding()]
    [OutputType([TextReplacement])]
    param(
        #
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias("Ast")]
        [Ast]$InputObject,

        [Parameter()]
        [string[]]$FunctionName = "*",

        [Parameter(Mandatory)]
        [string]$Boilerplate
    )
    begin {

        class ParameterPosition {
            [string]$Name
            [int]$StartOffset
            [string]$Text
        }

        class ParameterExtractor : AstVisitor {
            [ParameterPosition[]]$Parameters = @()
            [int]$InsertLineNumber = -1
            [int]$InsertColumnNumber = -1
            [int]$InsertOffset = -1

            ParameterExtractor([Ast]$Ast) {
                $ast.Visit($this)
            }

            [AstVisitAction] VisitParamBlock([ParamBlockAst]$ast) {
                if ($Ast.Parameters) {
                    $Text = $ast.Extent.Text -split "\r?\n"

                    $FirstLine = $ast.Extent.StartLineNumber
                    $NextLine = 1
                    $this.Parameters = @(
                        foreach ($parameter in $ast.Parameters | Select-Object Name -Expand Extent) {
                            [ParameterPosition]@{
                                Name        = $parameter.Name
                                StartOffset = $parameter.StartOffset
                                Text        = if (($parameter.StartLineNumber - $FirstLine) -ge $NextLine) {
                                    Write-Debug "Extracted parameter $($Parameter.Name) with surrounding lines"
                                    # Take lines after the last parameter
                                    $Lines = @($Text[$NextLine..($parameter.EndLineNumber - $FirstLine)].Where{ ![string]::IsNullOrWhiteSpace($_) })
                                    # If the last line extends past the end of the parameter, trim that line
                                    if ($Lines.Length -gt 0 -and $parameter.EndColumnNumber -lt $Lines[-1].Length) {
                                        $Lines[-1] = $Lines[-1].SubString($parameter.EndColumnNumber)
                                    }
                                    # Don't return the commas, we'll add them back later
                                    ($Lines -join "`n").TrimEnd(",")
                                } else {
                                    Write-Debug "Extracted parameter $($Parameter.Name) text exactly"
                                    $parameter.Text.TrimEnd(",")
                                }
                            }
                            $NextLine = 1 + $parameter.EndLineNumber - $FirstLine
                        }
                    )

                    $this.InsertLineNumber = $ast.Parameters[-1].Extent.EndLineNumber
                    $this.InsertColumnNumber = $ast.Parameters[-1].Extent.EndColumnNumber
                    $this.InsertOffset = $ast.Parameters[-1].Extent.EndOffset
                } else {
                    $this.InsertLineNumber = $ast.Extent.EndLineNumber
                    $this.InsertColumnNumber = $ast.Extent.EndColumnNumber - 1
                    $this.InsertOffset = $ast.Extent.EndOffset - 1
                }
                return [AstVisitAction]::StopVisit
            }
        }

        # By far the fastest way to parse things out is with an AstVisitor
        class ParameterGenerator : AstVisitor {
            [List[TextReplacement]]$Replacements = @()
            [ScriptBlock]$FunctionFilter = { $true }

            [ParameterExtractor]$ParameterSource

            [AstVisitAction] VisitFunctionDefinition([FunctionDefinitionAst]$ast) {
                if (!$ast.Where($this.FunctionFilter)) {
                    return [AstVisitAction]::SkipChildren
                }

                [ParameterExtractor]$ExistingParameters = $ast

                Write-Debug "Existing parameters in $($ast.Name): $($ExistingParameters.Parameters.Name -join ', ')"
                $Additional = $this.ParameterSource.Parameters.Where{ $_.Name -notin $ExistingParameters.Parameters.Name }
                if (($Text = $Additional.Text -join ",`n`n")) {
                    Write-Debug "Adding parameters to $($ast.Name): $($Additional.Name -join ', ')"
                    $this.Replacements.Add(@{
                        StartOffset = $ExistingParameters.InsertOffset
                        EndOffset   = $ExistingParameters.InsertOffset
                        Text        = if ($ExistingParameters.Parameters.Count -gt 0) {
                                ",`n`n" + $Text
                            } else {
                                "`n" + $Text
                            }
                    })
                }
                return [AstVisitAction]::SkipChildren
            }
        }
    }
    process {
        Write-Debug "Add-Parameter $InputObject $FunctionName $Boilerplate"

        $Generator = [ParameterGenerator]@{
            FunctionFilter  = { $Func = $_; $FunctionName.ForEach({ $Func.Name -like $_ }) -contains $true }.GetNewClosure()
            ParameterSource = (ConvertToAst $Boilerplate).AST
        }

        $InputObject.Visit($Generator)

        Write-Debug "Total Replacements: $($Generator.Replacements.Count)"

        $Generator.Replacements
    }
}
