using namespace System.Management.Automation.Language
using namespace System.Collections.Generic

class ParameterGenerator : ModuleBuilderGenerator {
    [System.Management.Automation.HiddenAttribute()]
    [ParameterExtractor]$AdditionalParameterCache

    ParameterGenerator($Path) : base($Path) {}

    [System.Collections.Generic.Dictionary[string, TextReplacement]]GetAdditional() {
        if (!$this.AdditionalParameterCache) {
            $this.AdditionalParameterCache = [ParameterExtractor]$this.Ast
        }
        return $this.AdditionalParameterCache.Parameters
    }

    [AstVisitAction] VisitFunctionDefinition([FunctionDefinitionAst]$ast) {
        if (!$ast.Where($this.Where)) {
            return [AstVisitAction]::SkipChildren
        }

        $Existing = [ParameterExtractor]$ast

        $AdditionalParameters = $this.GetAdditional()
        $Additional = $AdditionalParameters.Keys.Where{ $_.Name -notin $Existing.Parameters.Name }
        if (($Text = $AdditionalParameters.Values.Text -join ",`n`n")) {
            $Replacement = [TextReplacement]@{
                StartOffset = $Existing.InsertOffset
                EndOffset   = $Existing.InsertOffset
                Text        = if ($Existing.Parameters.Count -gt 0) {
                    ",`n`n" + $Text
                } else {
                    "`n" + $Text
                }
            }

            Write-Debug "Adding parameters to $($ast.name): $($Additional.Keys -join ', ')"
            $this.Replacements.Add($Replacement)
        }
        return [AstVisitAction]::SkipChildren
    }
}
