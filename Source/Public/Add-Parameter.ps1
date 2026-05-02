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
            # The normal way to use Add-Parameter is to set it in the build manifest for your module,
            # to add a common set of parameters to certain functions in the module by wildcard name.
            #
            # Set the Generator to Add-Parameter and pass a file to copy parameters from as `boilerplate`
            # Finally, pass the names of the functions you want to copy them to:
            @{
                ModuleManifest  = "./source/TerminalBlocks.psd1"
                Generators      = @(
                    @{ Generator = "Add-Parameter"; Boilerplate = "NewTerminalBlock.ps1"; Function = "Show-*", "New-TerminalBlock" }
                )
            }
        .EXAMPLE
        # You can also use it through Invoke-ScriptGenerator to add parameters to a function in the wild!
        # The BoilerPlate must have a param block with parameters, whether it's a string, script, file path, function, or scriptblock ...
        # Remember, Add-Parameter will not replace parameters, so if a parameter name already exists, it will not be touched.

        function Show-Date {
            param(
                # The text to display
                [string]$Format
            )
            Get-Date -Format $Format
        }

        ${function:Show-Date} = Invoke-ScriptGenerator ${function:Show-Date} -Generator Add-Parameter -Parameters @{
            FunctionName = "*";
            Boilerplate = {
            param(
                # The Foreground Color (name, #rrggbb, etc)
                [Alias('Fg')]
                [PoshCode.Pansies.RgbColor]$ForegroundColor,

                # The Background Color (name, #rrggbb, etc)
                [Alias('Bg')]
                [PoshCode.Pansies.RgbColor]$BackgroundColor
            )
            }
        }

        Get-Command Show-Date | Format-List

        Name        : Show-Date
        CommandType : Function
        Definition  :
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
    #>
    # [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    #     <#RuleId#>'PSReviewUnusedParameter',
    #     <#ParameterName#>'FunctionName',
    #     Justification = 'This parameter IS used, the rule does not understand scopes'
    # )]
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
                                    # Write-Debug "Extracted parameter $($Parameter.Name) with surrounding lines"
                                    # Take lines after the last parameter
                                    $Lines = @($Text[$NextLine..($parameter.EndLineNumber - $FirstLine)].Where{ ![string]::IsNullOrWhiteSpace($_) })
                                    # If the last line extends past the end of the parameter, trim that line
                                    if ($Lines.Length -gt 0 -and $parameter.EndColumnNumber -lt $Lines[-1].Length) {
                                        $Lines[-1] = $Lines[-1].SubString($parameter.EndColumnNumber)
                                    }
                                    # Don't return the commas, we'll add them back later
                                    ($Lines -join "`n").TrimEnd(",")
                                } else {
                                    # Write-Debug "Extracted parameter $($Parameter.Name) text exactly"
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
                    Write-Debug "Skipping function $($ast.Name) because it does not match the filter"
                    return [AstVisitAction]::SkipChildren
                }
                Write-Debug "Processing function $($ast.Name)"
                return [AstVisitAction]::Continue
            }

            [AstVisitAction] VisitParamBlock([ParamBlockAst]$ast) {

                # [ParameterExtractor]$ExistingParameters = $ast
                $InsertOffset = if ($Ast.Parameters) {
                    $ast.Parameters[-1].Extent.EndOffset
                } else {
                    $ast.Extent.EndOffset - 1
                }

                Write-Debug "Existing parameters: $($Ast.Parameters.Name -join ', ')"
                # $global:ParameterSource = $this.ParameterSource
                $Additional = $this.ParameterSource.Parameters.Where{ $_.Name -notin ([string[]]$Ast.Parameters.Name) }
                Write-Debug "Additional parameters from boilerplate: $($Additional.Count)"
                if (($Text = $Additional.Text -join ",`n`n")) {
                    Write-Debug "Adding parameters: $($Additional.Name -join ', ')"
                    $this.Replacements.Add(@{
                            StartOffset = $InsertOffset
                            EndOffset   = $InsertOffset
                            Text        = if ($Ast.Parameters.Count -gt 0) {
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
        Write-Debug "Add-Parameter $($InputObject.Extent.File -ne "scriptblock" ? $InputObject.Extent.File : ( "L:" + $InputObject.Extent.StartLineNumber + ".." + $InputObject.Extent.EndLineNumber + " C:" + $InputObject.Extent.StartColumnNumber + ".." + $InputObject.Extent.EndColumnNumber)) $FunctionName $Boilerplate"

        $Generator = [ParameterGenerator]@{
            FunctionFilter  = { $Func = $_; $FunctionName.ForEach({ $Func.Name -like $_ }) -contains $true }.GetNewClosure()
            ParameterSource = (ConvertToAst $Boilerplate).AST
        }

        $InputObject.Visit($Generator)

        Write-Debug "Total Replacements: $($Generator.Replacements.Count)"

        $Generator.Replacements
    }
}
