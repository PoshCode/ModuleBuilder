class AddParameterAspect : ModuleBuilderAspect {
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
