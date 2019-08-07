function ConvertToAst {
    <#
        .SYNOPSIS
            Parses the given code and returns an object with the AST, Tokens and ParseErrors
    #>
    param(
        # The script content, or script or module file path to parse
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("Path", "PSPath", "Definition", "ScriptBlock", "Module")]
        $Code
    )
    process {
        Write-Debug "    ENTER: ConvertToAst $Code"
        $ParseErrors = $null
        $Tokens = $null
        if ($Code | Test-Path -ErrorAction SilentlyContinue) {
            Write-Debug "      Parse Code as Path"
            $AST = [System.Management.Automation.Language.Parser]::ParseFile(($Code | Convert-Path), [ref]$Tokens, [ref]$ParseErrors)
        } elseif ($Code -is [System.Management.Automation.FunctionInfo]) {
            Write-Debug "      Parse Code as Function"
            $String = "function $($Code.Name) { $($Code.Definition) }"
            $AST = [System.Management.Automation.Language.Parser]::ParseInput($String, [ref]$Tokens, [ref]$ParseErrors)
        } else {
            Write-Debug "      Parse Code as String"
            $AST = [System.Management.Automation.Language.Parser]::ParseInput([String]$Code, [ref]$Tokens, [ref]$ParseErrors)
        }

        Write-Debug "    EXIT: ConvertToAst"
        [PSCustomObject]@{
            PSTypeName  = "PoshCode.ModuleBuilder.ParseResults"
            ParseErrors = $ParseErrors
            Tokens      = $Tokens
            AST         = $AST
        }
    }
}
