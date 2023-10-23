function MergeAspect {
    <#
        .SYNOPSIS
            Merge features of a script into commands from a module, using a ModuleBuilderAspect
        .DESCRIPTION
            This is an aspect-oriented programming approach for adding cross-cutting features to functions in a module.

            The [ModuleBuilderAspect] implementations are [AstVisitors] that return [TextReplace] object representing modifications to be performed on the source.
    #>
    [CmdletBinding()]
    param(
        # The path to the RootModule psm1 to merge the aspect into
        [Parameter(Mandatory, Position = 0)]
        [string]$RootModule,

        # The name of the ModuleBuilder Generator to invoke.
        # There are two built in:
        # - MergeBlocks. Supports Before/After/Around blocks for aspects like error handling or authentication.
        # - AddParameter. Supports adding common parameters to functions (usually in conjunction with MergeBlock that use those parameters)
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({ (($_ -As [Type]), ("${_}Aspect" -As [Type])).BaseType -eq [ModuleBuilderAspect] })]
        [string]$Action,

        # The name(s) of functions in the module to run the generator against. Supports wildcards.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string[]]$Function,

        # The name of the script path or function that contains the base which drives the generator
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Source
    )
    process {
        #! We can't reuse the AST because it needs to be updated after we change it
        #! But we can handle this in a wrapper
        Write-Verbose "Parsing $RootModule for $Action with $Source"
        $Ast = ConvertToAst $RootModule

        $Action = if ($Action -As [Type]) {
            $Action
        } elseif ("${Action}Aspect" -As [Type]) {
            "${Action}Aspect"
        } else {
            throw "Can't find $Action ModuleBuilderAspect"
        }

        $Aspect = New-Object $Action -Property @{
            Where  = { $Func = $_; $Function.ForEach({ $Func.Name -like $_ }) -contains $true }.GetNewClosure()
            Aspect = @(Get-Command (Join-Path $AspectDirectory $Source), $Source -ErrorAction Ignore)[0].ScriptBlock.Ast
        }

        #! Process replacements from the bottom up, so the line numbers work
        $Content = Get-Content $RootModule -Raw
        Write-Verbose "Generating $Action in $RootModule"
        foreach ($replacement in $Aspect.Generate($Ast.Ast) | Sort-Object StartOffset -Descending) {
            $Content = $Content.Remove($replacement.StartOffset, ($replacement.EndOffset - $replacement.StartOffset)).Insert($replacement.StartOffset, $replacement.Text)
        }
        Set-Content $RootModule $Content
    }
}
