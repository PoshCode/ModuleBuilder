using namespace System.Management.Automation.Language
using namespace System.Collections.Generic

filter Merge-ScriptBlock {
    <#
        .SYNOPSIS
            A Script Generator to merge boilerplate script blocks into other scriptblocks
        .DESCRIPTION
            Merge-ScriptBlock takes an input AST and one or more boilerplate scriptblocks and will merge them into the input.

            Note that THIS generator does not work on script files directly, but only on functions defined in the InputObject.
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
        '@

        Invoke-ScriptGenerator $Source -Generator Merge-ScriptBlock -Parameters @{ FunctionName = "*"; Boilerplate = $Boilerplate }

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
            $ForegroundColor.ToVt() + $BackgroundColor.ToVt($true) + (
                Get-Date -Format $Format
            ) +"`e[0m"
        }
    #>
    [CmdletBinding()]
    [OutputType([TextReplacement])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'FunctionName', Justification = "It's passed into the Generator")]
    param(
        # The AST of the original script module to refactor
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias("Ast")]
        [Ast]$InputObject,

        [Parameter()]
        [string[]]$FunctionName = "*",

        [Parameter(Mandatory)]
        [string]$Boilerplate
    )
    begin {
        class BlockGenerator : AstVisitor {
            [List[TextReplacement]]$Replacements = @()
            [ScriptBlock]$FunctionFilter = { $true }

            hidden [NamedBlockAst]$BeginBlockTemplate
            hidden [NamedBlockAst]$ProcessBlockTemplate
            hidden [NamedBlockAst]$EndBlockTemplate

            [string] GetExtentText([NamedBlockAst]$Ast) {
                if ($Ast.UnNamed -and $Ast.Parent.ParamBlock.Extent.Text) {
                    # Trim the paramBlock out of the what we're injecting into the boilerplate template
                    return $Ast.Extent.Text.Remove(
                        $Ast.Parent.ParamBlock.Extent.StartOffset - $Ast.Extent.StartOffset,
                        $Ast.Parent.ParamBlock.Extent.EndOffset - $Ast.Parent.ParamBlock.Extent.StartOffset).Trim("`r`n").TrimEnd("`r`n ")
                } else {
                    # Trim the `end {` ... `}` off if they're there
                    return ($Ast.Extent.Text -replace "^$($Ast.BlockKind)[\s\r\n]*{|}[\s\r\n]*$", "`n").Trim("`r`n").TrimEnd("`r`n ")
                }
            }

            Replace([NamedBlockAst]$Template, [NamedBlockAst]$Ast) {
                if ($Template -and $Ast) {
                    # If there's a ParamBlock, we don't want to replace that
                    $Extent = $Ast.Extent
                    if ($Ast.UnNamed -and $Ast.Parent.ParamBlock.Extent.Text) {
                        # Make sure we don't replace the ParamBlock
                        $StartOffset = $Ast.Parent.ParamBlock.Extent.EndOffset
                    } else {
                        $StartOffset = $Extent.StartOffset
                    }
                    Write-Debug "Adding Boilerplate for $($Ast.BlockKind)"
                    $this.Replacements.Add(@{
                        StartOffset = $StartOffset
                        EndOffset   = $Extent.EndOffset
                        # We end up having to normalize the template to be named blocks...
                        # Just in case the InputObject has named blocks
                        Text        = "$($Ast.BlockKind) {`n" +
                                        $this.GetExtentText($Template).Replace("Use-OriginalBlock", $this.GetExtentText($Ast)) +
                                        "`n}"
                    })
                }
            }

            # The [Alias(...)] attribute on functions matters, but we can't export aliases that are defined inside a function
            [AstVisitAction] VisitFunctionDefinition([FunctionDefinitionAst]$Ast) {
                if (!$Ast.Where($this.FunctionFilter)) {
                    return [AstVisitAction]::SkipChildren
                }
                Write-Debug "Merging $($Ast.Name) with boilerplate"
                $this.Replace($this.BeginBlockTemplate, $Ast.Body.BeginBlock)
                $this.Replace($this.ProcessBlockTemplate, $Ast.Body.ProcessBlock)
                $this.Replace($this.EndBlockTemplate, $Ast.Body.EndBlock)

                return [AstVisitAction]::SkipChildren
            }
        }
    }
    process {
        $Template = (ConvertToAst $Boilerplate).AST
        $Generator = [BlockGenerator]@{
            FunctionFilter       = { $Func = $_; $FunctionName.ForEach({ $Func.Name -like $_ }) -contains $true }.GetNewClosure()
            BeginBlockTemplate   = $Template.Find({ $args[0] -is [NamedBlockAst] -and $args[0].BlockKind -eq "Begin" }, $false)
            ProcessBlockTemplate = $Template.Find({ $args[0] -is [NamedBlockAst] -and $args[0].BlockKind -eq "Process" }, $false)
            EndBlockTemplate     = $Template.Find({ $args[0] -is [NamedBlockAst] -and $args[0].BlockKind -eq "End" }, $false)
        }

        $InputObject.Visit($Generator)

        Write-Debug "Total Replacements: $($Generator.Replacements.Count)"

        $Generator.Replacements
    }
}
