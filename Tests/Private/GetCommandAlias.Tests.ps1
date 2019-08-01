Describe "GetCommandAlias" {
    Import-Module ModuleBuilder -DisableNameChecking -Verbose:$False

    Context "Mandatory Parameter" {
        $CommandInfo = InModuleScope ModuleBuilder { Get-Command GetCommandAlias }

        It 'has a mandatory AST parameter' {
            $AST = $CommandInfo.Parameters['AST']
            $AST | Should -Not -BeNullOrEmpty
            $AST.ParameterType | Should -Be ([System.Management.Automation.Language.Ast])
            $AST.Attributes.Where{ $_ -is [Parameter] }.Mandatory | Should -Be $true
        }

    }

    Context "Parsing Code" {
        It "returns a hashtable of command names to aliases" {
            $Result = InModuleScope ModuleBuilder {
                GetCommandAlias -Ast {
                    function Test-Alias {
                        [Alias("Foo","Bar","Alias")]
                        param()
                    }
                }.Ast
            }

            $Result["Test-Alias"] | Should -Be @("Foo", "Bar", "Alias")
        }
    }

    Context "Parsing Code" {
        It "Parses only top-level functions, and returns them in order" {
            $Result = InModuleScope ModuleBuilder {
                GetCommandAlias -Ast {
                    function Test-Alias {
                        [Alias("TA", "TAlias")]
                        param()
                    }

                    function TestAlias {
                        [Alias("T")]
                        param()

                        function Test-Negative {
                            [Alias("TN")]
                            param()
                        }
                    }
                }.Ast
            }

            $Result.Keys | Should -Be "Test-Alias", "TestAlias"
            $Result["Test-Alias"] | Should -Be "TA","TAlias"
            $Result["TestAlias"] | Should -Be "T"
        }
    }
}
