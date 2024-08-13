#requires -Module ModuleBuilder
Describe "GetCommandAlias" {
    BeforeAll {
        $CommandInfo = InModuleScope ModuleBuilder { Get-Command GetCommandAlias }
    }

    Context "Mandatory Parameter" {
        It 'has a mandatory AST parameter' {
            $AST = $CommandInfo.Parameters['AST']
            $AST | Should -Not -BeNullOrEmpty
            $AST.ParameterType | Should -Be ([System.Management.Automation.Language.Ast])
            $AST.Attributes.Where{ $_ -is [Parameter] }.Mandatory | Should -Be $true
        }

    }

    Context "Parsing Alias Parameters" {
        # It used to return a hashtable, but we no longer care what the alias points to
        It "Returns a collection of aliases" {
            $Result = &$CommandInfo -Ast {
                function Test-Alias {
                    [Alias("Foo","Bar","Alias")]
                    param()
                }
            }.Ast

            $Result | Should -Be @("Foo", "Bar", "Alias")
        }

        It "Parses only top-level functions, and returns them in order" {
            $Result = &$CommandInfo -Ast {
                function Test-Alias {
                    [Alias("TA", "TAlias")]
                    param()
                }

                function TestAlias {
                    [Alias("T")]
                    param()

                    # This should not return
                    function Test-Negative {
                        [Alias("TN")]
                        param()
                    }
                }
            }.Ast

            $Result | Should -Be "TA","TAlias", "T"
        }
    }

    Context "Parsing New-Alias" {
        It "Parses alias names regardless of parameter order" {
            $Result = &$CommandInfo -Ast {
                New-Alias -N 'Alias1' -Va 'Write-Verbose'
                New-Alias -Value 'Write-Verbose' -Name 'Alias2'
                New-Alias Alias3 Write-Verbose
                New-Alias -Value 'Write-Verbose' 'Alias4'
                New-Alias 'Alias5' -Value 'Write-Verbose'
            }.Ast

            $Result | Should -Be 'Alias1', 'Alias2', 'Alias3', 'Alias4', 'Alias5'
        }

        It "Ignores aliases defined in nested function scope" {
            $Result = &$CommandInfo -Ast {
                New-Alias -Name 'Alias1' -Value 'Write-Verbose'
                New-Alias -Value 'Write-Verbose' -Name 'Alias2'
                New-Alias 'Alias3' 'Write-Verbose'
                function Get-Something {
                    param()

                    New-Alias -Name Alias4 -Value 'Write-Verbose'
                    New-Alias -Name Alias5 -Va 'Write-Verbose'
                }
            }.Ast

            $Result | Should -Be 'Alias1', 'Alias2', 'Alias3'
        }

        It "Ignores aliases that already have global scope" {
            $Result = &$CommandInfo -Ast {
                New-Alias -Name Alias1 -Scope Global -Value Write-Verbose
                New-Alias -Scope Global -Value 'Write-Verbose' -Name 'Alias2'
                New-Alias -Sc Global 'Alias3' 'Write-Verbose'
                New-Alias -Va 'Write-Verbose' 'Alias4' -S Global
                New-Alias Alias5 -Value 'Write-Verbose' -Scope Global
            }.Ast

            $Result | Should -BeNullOrEmpty
        }
    }

    Context "Parsing Set-Alias" {
        It "Parses alias names regardless of parameter order" {
            $Result = &$CommandInfo -Ast {
                Set-Alias -Name Alias1 -Value Write-Verbose
                Set-Alias -Va 'Write-Verbose' -N 'Alias2'
                Set-Alias Alias3 Write-Verbose
                Set-Alias -Va 'Write-Verbose' 'Alias4'
                Set-Alias 'Alias5' -Value 'Write-Verbose'
            }.Ast

            $Result | Should -Be 'Alias1', 'Alias2', 'Alias3', 'Alias4', 'Alias5'
        }

        It "Ignores aliases defined in nested function scope" {
            $Result = &$CommandInfo -Ast {
                Set-Alias -Name 'Alias1' -Value 'Write-Verbose'
                Set-Alias -Value 'Write-Verbose' -Name 'Alias2'
                Set-Alias 'Alias3' 'Write-Verbose'
                function Get-Something {
                    param()

                    Set-Alias -Name 'Alias4' -Value 'Write-Verbose'
                    Set-Alias -Name 'Alias5' -Value 'Write-Verbose'
                }
            }.Ast

            $Result | Should -Be 'Alias1', 'Alias2', 'Alias3'
        }

        It "Ignores aliases that already have global scope" {
            $Result = &$CommandInfo -Ast {
                Set-Alias -N 'Alias1' -Scope Global -Value 'Write-Verbose'
                Set-Alias -Scope Global -Value 'Write-Verbose' -Name 'Alias2'
                Set-Alias -Sc Global Alias3 Write-Verbose
                Set-Alias -Va 'Write-Verbose' 'Alias4' -Sc Global
                Set-Alias 'Alias5' -Value 'Write-Verbose' -Scope Global
            }.Ast

            $Result | Should -BeNullOrEmpty
        }
    }


    Context "Remove-Alias cancels Alias exports" {
        It "Parses parameters regardless of name" {
            $Result = &$CommandInfo -Ast {
                New-Alias -Name Alias1 -Value Write-Verbose
                Set-Alias -Value 'Write-Verbose' -Name 'Alias2'
                New-Alias Alias3 Write-Verbose
                Set-Alias -Value 'Write-Verbose' 'Alias4'
                Set-Alias 'Alias5' -Value 'Write-Verbose'
                Remove-Alias Alias1
                Remove-Alias -Name Alias2
                Remove-Alias -N Alias5
            }.Ast

            $Result | Should -Be 'Alias3', 'Alias4'
        }

        It "Ignores removals in function scopes" {
            $Result = &$CommandInfo -Ast {
                Set-Alias -Name 'Alias1' -Value 'Write-Verbose'
                New-Alias -Value 'Write-Verbose' -Name 'Alias2'
                Set-Alias 'Alias3' 'Write-Verbose'
                function Get-Something {
                    param()

                    Set-Alias -Name 'Alias4' -Value 'Write-Verbose'
                    Set-Alias -Name 'Alias5' -Value 'Write-Verbose'
                    Remove-Alias -Name Alias1
                }
            }.Ast

            $Result | Should -Be 'Alias1', 'Alias2', 'Alias3'
        }

        It "Does not fail when removing aliases that were ignored because of global scope" {
            $Result = &$CommandInfo -Ast {
                Set-Alias -Name Alias1 -Scope Global -Value Write-Verbose
                Remove-Alias -Name Alias1
            }.Ast

            $Result | Should -BeNullOrEmpty
        }
    }
}
