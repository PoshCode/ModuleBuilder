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
