
function GetCommandAlias {
    <#
        .SYNOPSIS
            Parses one or more files for aliases and returns a list of alias names.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.Hashset[string]])]
    param(
        # The AST to find aliases in
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [System.Management.Automation.Language.Ast]$Ast
    )
    begin {
        $Visitor = [AliasVisitor]::new()
    }
    process {
        $Ast.Visit($Visitor)
    }
    end {
        $Visitor.Aliases
    }
}

