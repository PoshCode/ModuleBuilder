using namespace System.Management.Automation.Language
using namespace System.Collections.Generic





# There should be an abstract class for ModuleBuilderGenerator that has a contract for this:


# Should be called on a block to extract the (first) parameters from that block
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
                        Name = $parameter.Name
                        StartOffset = $parameter.StartOffset
                        Text =  if (($parameter.StartLineNumber - $FirstLine) -ge $NextLine) {
                                    Write-Debug "Extracted parameter $($Parameter.Name) with surrounding lines"
                                    # Take lines after the last parameter
                                    $Lines = @($Text[$NextLine..($parameter.EndLineNumber - $FirstLine)].Where{![string]::IsNullOrWhiteSpace($_)})
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

class AddParameter : ModuleBuilderGenerator {
    [System.Management.Automation.HiddenAttribute()]
    [ParameterExtractor]$AdditionalParameterCache

    [ParameterExtractor]GetAdditional() {
        if (!$this.AdditionalParameterCache) {
            $this.AdditionalParameterCache = $this.Aspect
        }
        return $this.AdditionalParameterCache
    }

    [AstVisitAction] VisitFunctionDefinition([FunctionDefinitionAst]$ast) {
        if (!$ast.Where($this.Where)) {
            return [AstVisitAction]::SkipChildren
        }
        $Existing = [ParameterExtractor]$ast
        $Additional = $this.GetAdditional().Parameters.Where{ $_.Name -notin $Existing.Parameters.Name }
        if (($Text = $Additional.Text -join ",`n`n")) {
            $Replacement = [TextReplace]@{
                StartOffset = $Existing.InsertOffset
                EndOffset   = $Existing.InsertOffset
                Text        = if ($Existing.Parameters.Count -gt 0) {
                                ",`n`n" + $Text
                            } else {
                                "`n" + $Text
                            }
            }

            Write-Debug "Adding parameters to $($ast.name): $($Additional.Name -join ', ')"
            $this.Replacements.Add($Replacement)
        }
        return [AstVisitAction]::SkipChildren
    }
}

class MergeBlocks : ModuleBuilderGenerator {
    [System.Management.Automation.HiddenAttribute()]
    [NamedBlockAst]$BeginBlockTemplate

    [System.Management.Automation.HiddenAttribute()]
    [NamedBlockAst]$ProcessBlockTemplate

    [System.Management.Automation.HiddenAttribute()]
    [NamedBlockAst]$EndBlockTemplate

    [List[TextReplace]]Generate([Ast]$ast) {
        if (!($this.BeginBlockTemplate = $this.Aspect.Find({ $args[0] -is [NamedBlockAst] -and $args[0].BlockKind -eq "Begin" }, $false))) {
            Write-Debug "No Aspect for BeginBlock"
        } else {
            Write-Debug "BeginBlock Aspect: $($this.BeginBlockTemplate)"
        }
        if (!($this.ProcessBlockTemplate = $this.Aspect.Find({ $args[0] -is [NamedBlockAst] -and $args[0].BlockKind -eq "Process" }, $false))) {
            Write-Debug "No Aspect for ProcessBlock"
        } else {
            Write-Debug "ProcessBlock Aspect: $($this.ProcessBlockTemplate)"
        }
        if (!($this.EndBlockTemplate = $this.Aspect.Find({ $args[0] -is [NamedBlockAst] -and $args[0].BlockKind -eq "End" }, $false))) {
            Write-Debug "No Aspect for EndBlock"
        } else {
            Write-Debug "EndBlock Aspect: $($this.EndBlockTemplate)"
        }

        $ast.Visit($this)
        return $this.Replacements
    }

    # The [Alias(...)] attribute on functions matters, but we can't export aliases that are defined inside a function
    [AstVisitAction] VisitFunctionDefinition([FunctionDefinitionAst]$ast) {
        if (!$ast.Where($this.Where)) {
            return [AstVisitAction]::SkipChildren
        }

        if ($this.BeginBlockTemplate) {
            if ($ast.Body.BeginBlock) {
                $BeginExtent = $ast.Body.BeginBlock.Extent
                $BeginBlockText = ($BeginExtent.Text -replace "^begin[\s\r\n]*{|}[\s\r\n]*$", "`n").Trim("`r`n").TrimEnd("`r`n ")

                $Replacement = [TextReplace]@{
                    StartOffset = $BeginExtent.StartOffset
                    EndOffset   = $BeginExtent.EndOffset
                    Text        = $this.BeginBlockTemplate.Extent.Text.Replace("existingcode", $BeginBlockText)
                }

                $this.Replacements.Add( $Replacement )
            } else {
                Write-Debug "$($ast.Name) Missing BeginBlock"
            }
        }

        if ($this.ProcessBlockTemplate) {
            if ($ast.Body.ProcessBlock) {
                # In a "filter" function, the process block may contain the param block
                $ProcessBlockExtent = $ast.Body.ProcessBlock.Extent

                if ($ast.Body.ProcessBlock.UnNamed -and $ast.Body.ParamBlock.Extent.Text) {
                    # Trim the paramBlock out of the end block
                    $ProcessBlockText = $ProcessBlockExtent.Text.Remove(
                        $ast.Body.ParamBlock.Extent.StartOffset - $ProcessBlockExtent.StartOffset,
                        $ast.Body.ParamBlock.Extent.EndOffset - $ast.Body.ParamBlock.Extent.StartOffset)
                    $StartOffset = $ast.Body.ParamBlock.Extent.EndOffset
                } else {
                    # Trim the `process {` ... `}` because we're inserting it into the template process
                    $ProcessBlockText = ($ProcessBlockExtent.Text -replace "^process[\s\r\n]*{|}[\s\r\n]*$", "`n").Trim("`r`n").TrimEnd("`r`n ")
                    $StartOffset = $ProcessBlockExtent.StartOffset
                }

                $Replacement = [TextReplace]@{
                    StartOffset = $StartOffset
                    EndOffset   = $ProcessBlockExtent.EndOffset
                    Text        = $this.ProcessBlockTemplate.Extent.Text.Replace("existingcode", $ProcessBlockText)
                }

                $this.Replacements.Add( $Replacement )
            } else {
                Write-Debug "$($ast.Name) Missing ProcessBlock"
            }
        }

        if ($this.EndBlockTemplate) {
            if ($ast.Body.EndBlock) {
                # The end block is a problem because it frequently contains the param block, which must be left alone
                $EndBlockExtent = $ast.Body.EndBlock.Extent

                $EndBlockText = $EndBlockExtent.Text
                $StartOffset = $EndBlockExtent.StartOffset
                if ($ast.Body.EndBlock.UnNamed -and $ast.Body.ParamBlock.Extent.Text) {
                    # Trim the paramBlock out of the end block
                    $EndBlockText = $EndBlockExtent.Text.Remove(
                        $ast.Body.ParamBlock.Extent.StartOffset - $EndBlockExtent.StartOffset,
                        $ast.Body.ParamBlock.Extent.EndOffset - $ast.Body.ParamBlock.Extent.StartOffset)
                    $StartOffset = $ast.Body.ParamBlock.Extent.EndOffset
                } else {
                    # Trim the `end {` ... `}` because we're inserting it into the template end
                    $EndBlockText = ($EndBlockExtent.Text -replace "^end[\s\r\n]*{|}[\s\r\n]*$", "`n").Trim("`r`n").TrimEnd("`r`n ")
                }

                $Replacement = [TextReplace]@{
                    StartOffset = $StartOffset
                    EndOffset   = $EndBlockExtent.EndOffset
                    Text        = $this.EndBlockTemplate.Extent.Text.Replace("existingcode", $EndBlockText)
                }

                $this.Replacements.Add( $Replacement )
            } else {
                Write-Debug "$($ast.Name) Missing EndBlock"
            }
        }

        return [AstVisitAction]::SkipChildren
    }
}

