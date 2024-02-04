function InvokeGenerator {
    <#
        .SYNOPSIS
            Generate code using a ModuleBuilderGenerator
        .DESCRIPTION
            This is an aspect-oriented programming approach for adding cross-cutting features to functions in a module.

            The [ModuleBuilderGenerator] implementations are [AstVisitors] that return [TextReplacement] objects representing modifications to be performed on the source.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Function', Justification = 'PSSA reads the AST wrong')]
    [CmdletBinding()]
    param(
        # The path to the RootModule psm1 to apply the Generator to
        [Parameter(Mandatory, Position = 0)]
        [string]$RootModule,

        # The name of the ModuleBuilder Generator to invoke.
        # There are only two Generators built in:
        # - ParameterGenerator. Supports adding parameters to functions in the module. Parameters come from a template file, which must be a script with a param block.
        # - BlockGenerator.  Supports adding code before, after, and around existing blocks for generators like error handling, authentication, and implementations for common parameters. The added blocks come from a template file, which must be a script with named begin/process/end blocks.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({ (($_ -As [Type]), ("${_}Generator" -As [Type])).BaseType -eq [ModuleBuilderGenerator] })]
        [string]$Generator,

        # The name(s) of functions in the RootModule to run the generator against. Supports wildcards.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string[]]$Function,

        # The name of a template file that customizes the generator
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Template
    )
    process {
        #! We can't reuse the AST because it needs to be updated after we change it
        #! But we can handle this in a wrapper
        Write-Verbose "Parsing $RootModule for $Generator with $Template"
        $Ast = ConvertToAst $RootModule

        $Generator = if ($Generator -As [Type]) {
            $Generator
        } elseif ("${Generator}Generator" -As [Type]) {
            "${Generator}Generator"
        } else {
            throw "Can't find $Generator ModuleBuilderGenerator"
        }

        $Generator = New-Object $Generator -Property @{
            Where  = { $Func = $_; $Function.ForEach({ $Func.Name -like $_ }) -contains $true }.GetNewClosure()
            Generator = @(Get-Command (Join-Path $GeneratorDirectory $Template), $Template -ErrorAction Ignore)[0].ScriptBlock.Ast
        }

        #! Process replacements from the bottom up, so the line numbers work
        $Content = Get-Content $RootModule -Raw
        Write-Verbose "Generating $Generator in $RootModule"
        foreach ($replacement in $Generator.Generate($Ast.Ast) | Sort-Object StartOffset -Descending) {
            $Content = $Content.Remove($replacement.StartOffset, ($replacement.EndOffset - $replacement.StartOffset)).Insert($replacement.StartOffset, $replacement.Text)
        }
        Set-Content $RootModule $Content
    }
}
