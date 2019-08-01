Describe "ConvertToAst" {
    Import-Module ModuleBuilder -DisableNameChecking -Verbose:$False

    Context "It returns a ParseResult for file paths" {
        $ParseResult = InModuleScope ModuleBuilder {
            ConvertToAst $PSCommandPath -Debug
        }

        It "Returns a ParseResult object" {
            $ParseResult.PSTypeNames[0] | Should -Match .*\.ParseResult
        }
        It "Has an AST property" {
            $ParseResult.AST | Should -BeOfType [System.Management.Automation.Language.Ast]
        }
        It "Has a ParseErrors property" {
            $ParseResult.ParseErrors | Should -BeNullOrEmpty # [System.Management.Automation.Language.ParseError[]]
        }
        It "Has a Tokens property" {
            $ParseResult.Tokens | Should -BeOfType [System.Management.Automation.Language.Token]
        }

    }

    Context "It parses piped in commands" {
        $ParseResult = InModuleScope ModuleBuilder {
            Get-Command ConvertToAst | ConvertToAst -Debug
        }

        It "Returns a ParseResult object with the AST" {
            $ParseResult.PSTypeNames[0] | Should -Match .*\.ParseResult
            $ParseResult.AST | Should -BeOfType [System.Management.Automation.Language.Ast]
        }
    }

    Context "It parses piped in modules" {
        $ParseResult = InModuleScope ModuleBuilder {
            Get-Module ModuleBuilder | ConvertToAst -Debug
        }

        It "Returns a ParseResult object with the AST" {
            $ParseResult.PSTypeNames[0] | Should -Match .*\.ParseResult
            $ParseResult.AST | Should -BeOfType [System.Management.Automation.Language.Ast]
        }
    }

<#
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
    #>
}
