function GetCommandAlias {
    [CmdletBinding()]
    param(
        # Path to the PSM1 file to amend
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [System.Management.Automation.Language.Ast]$AST
    )
    begin {
        $Result = [Ordered]@{}
    }
    process {
        foreach($function in $AST.FindAll(
                { $Args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] },
                $false )
        ) {
            $Result[$function.Name] = $function.Body.ParamBlock.Attributes.Where{
                $_.TypeName.Name -eq "Alias" }.PositionalArguments.Value
        }
    }
    end {
        $Result
    }
}
