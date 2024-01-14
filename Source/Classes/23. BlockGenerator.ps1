using namespace System.Management.Automation.Language
using namespace System.Collections.Generic

class BlockGenerator : ModuleBuilderGenerator {
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
