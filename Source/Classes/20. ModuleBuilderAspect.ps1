class ModuleBuilderAspect : AstVisitor {
    [List[TextReplace]]$Replacements = @()
    [ScriptBlock]$Where = { $true }
    [Ast]$Aspect

    [List[TextReplace]]Generate([Ast]$ast) {
        $ast.Visit($this)
        return $this.Replacements
    }
}
