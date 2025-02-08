#requires -Module ModuleBuilder
Describe "ConvertToAst" {

    Context "It returns a ParseResult for file paths" {
        BeforeAll {
            $ParseResult = InModuleScope ModuleBuilder {
                ConvertToAst $PSCommandPath
            }
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
        BeforeAll {
            $ParseResult = InModuleScope ModuleBuilder {
                Get-Command ConvertToAst | ConvertToAst
            }
        }

        It "Returns a ParseResult object with the AST" {
            $ParseResult.PSTypeNames[0] | Should -Match .*\.ParseResult
            $ParseResult.AST | Should -BeOfType [System.Management.Automation.Language.Ast]
        }
    }

    Context "It parses piped in modules" {
        BeforeAll {
            $ParseResult = InModuleScope ModuleBuilder {
                Get-Module ModuleBuilder | ConvertToAst
            }
        }

        It "Returns a ParseResult object with the AST" {
            $ParseResult.PSTypeNames[0] | Should -Match .*\.ParseResult
            $ParseResult.AST | Should -BeOfType [System.Management.Automation.Language.Ast]
        }
    }
}
