function ConvertToAst {
    <#
        .SYNOPSIS
            Parses the given code and returns an object with the AST, Tokens and ParseErrors
    #>
    [CmdletBinding(DefaultParameterSetName = "Path")]
    param(
        # The script content, or script or module file path to parse
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "Code")]
        [Alias("ScriptBlock")]
        $Code,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = "Command", Position = 0)]
        [System.Management.Automation.FunctionInfo]$Command,

        [Parameter(ValueFromPipelineByPropertyName, Position = 1)]
        [Alias("PSPath", "File", "Definition")]
        [string]$Path
    )
    process {
        Write-Debug "    ENTER: ConvertToAst $Path $(("$Command$Code" -split "[\r\n]")[0])"
        $ParseErrors = $null
        $Tokens = $null

        switch($PSCmdlet.ParameterSetName) {
            "Path" {
                $Provider = $null
                try {
                    $Path = $ExecutionContext.SessionState.Path.GetResolvedProviderPathFromPSPath($Path, [ref]$Provider)[0]
                } catch {
                    Write-Debug ("      Exception resolving $Path as Path " + $_.Exception.Message)
                }
                if ($Provider.Name -eq "FileSystem") {
                    Write-Debug "      Parse File Path: $Path"
                    $AST = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$Tokens, [ref]$ParseErrors)
                } else {
                    Write-Debug "      Parse Code $(($Path -split "[\r\n]")[0])"
                    $AST = [System.Management.Automation.Language.Parser]::ParseInput($Path, [ref]$Tokens, [ref]$ParseErrors)
                }
            }
            "Command" {
                Write-Debug "      Parse Function"
                if (!$Path) {
                    $Path = "function:$($Command.Name)"
                }
                $AST = [System.Management.Automation.Language.Parser]::ParseInput($Command.Definition, $Path, [ref]$Tokens, [ref]$ParseErrors)
            }
            "Code" {
                Write-Debug "      Parse Code as ScriptBlock"
                if ($Code -is [System.Management.Automation.ScriptBlock]) {
                    $Code = $Code.GetNewClosure().Invoke().ToString()

                    if (!$Path) {
                        $Path = "scriptblock"
                    }
                    $AST = [System.Management.Automation.Language.Parser]::ParseInput($Code, $Path, [ref]$Tokens, [ref]$ParseErrors)
                } else {
                    $Provider = $null
                    try {
                        $Path = $ExecutionContext.SessionState.Path.GetResolvedProviderPathFromPSPath($Code, [ref]$Provider)[0]
                    } catch {
                        Write-Debug ("      Failed to resolve Code as Path " + $_.Exception.Message)
                    }
                    if ($Provider.Name -eq "FileSystem") {
                        Write-Debug "      Parse File Path: $Path"
                        $AST = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$Tokens, [ref]$ParseErrors)
                    } else {
                        Write-Debug "      Parse Code $(($Path -split "[\r\n]")[0])"
                        $AST = [System.Management.Automation.Language.Parser]::ParseInput($Code, [ref]$Tokens, [ref]$ParseErrors)
                    }
                }
            }
        }

        Write-Debug "    EXIT: ConvertToAst $Path"
        [PSCustomObject]@{
            PSTypeName  = "PoshCode.ModuleBuilder.ParseResults"
            ParseErrors = $ParseErrors
            Tokens      = $Tokens
            Path        = $Path
            AST         = $AST
        }
    }
}
