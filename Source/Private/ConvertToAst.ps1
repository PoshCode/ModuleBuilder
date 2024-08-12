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

        if ($Code -is [System.Management.Automation.FunctionInfo]) {
            Write-Debug "      Parse Code as Function"
            $AST = [System.Management.Automation.Language.Parser]::ParseInput($Code.Definition, "function:$($Code.Name)", [ref]$Tokens, [ref]$ParseErrors)
        } else {
            $Provider = $null
            try {
                [string[]]$Files = $ExecutionContext.SessionState.Path.GetResolvedProviderPathFromPSPath($Code, [ref]$Provider)
            } catch {
                Write-Debug ("Exception resolving Code as Path " + $_.Exception.Message)
            }

            if ($Provider.Name -eq "FileSystem" -and $Files.Count -gt 0) {
                Write-Debug "      Parse Code as File Path"
                $AST = [System.Management.Automation.Language.Parser]::ParseFile(($Files[0] | Convert-Path), [ref]$Tokens, [ref]$ParseErrors)
            } else {
                Write-Debug "      Parse Code as String"
                $AST = [System.Management.Automation.Language.Parser]::ParseInput([String]$Code, [ref]$Tokens, [ref]$ParseErrors)
            }
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
