Import-Module "../HelpUsers/johlju/SqlServerDsc/output/RequiredModules/Pester"

Remove-Module -Name 'ModuleBuilder' -Force -ErrorAction 'SilentlyContinue'

New-Module -Name 'ModuleBuilder' -ScriptBlock {
    . $PSScriptRoot\..\..\Source\Private\GetCommandAlias.ps1
} | Import-Module

Describe "GetCommandAlias" {

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
                        [Alias("Foo", "Bar", "Alias")]
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
            $Result["Test-Alias"] | Should -Be "TA", "TAlias"
            $Result["TestAlias"] | Should -Be "T"
        }
    }

    Context "Parsing Code For New-Alias" {
        BeforeAll {
            # Must write a mock module script file and parse it to replicate real conditions
            "
            New-Alias -Name 'Alias1' -Value 'Write-Verbose'
            New-Alias -Value 'Write-Verbose' -Name 'Alias2'
            New-Alias 'Alias3' 'Write-Verbose'
            " | Out-File -FilePath "$TestDrive/MockBuiltModule.psm1" -Encoding ascii -Force
        }

        It "returns a hashtable with correct aliases" {
            $Result = InModuleScope ModuleBuilder {
                $ParseErrors, $Tokens = $null
                $mockAST = [System.Management.Automation.Language.Parser]::ParseFile("$TestDrive/MockBuiltModule.psm1", [ref]$Tokens, [ref]$ParseErrors)

                GetCommandAlias -Ast $mockAST
            }

            $Result.Count | Should -Be 3
            $Result['Alias1'] | Should -Be 'Alias1'
            $Result['Alias2'] | Should -Be 'Alias2'
            $Result['Alias3'] | Should -Be 'Alias3'
        }
    }

    Context "Parsing Code For Set-Alias" {
        BeforeAll {
            # Must write a mock module script file and parse it to replicate real conditions
            "
            Set-Alias -Name 'Alias1' -Value 'Write-Verbose'
            Set-Alias -Value 'Write-Verbose' -Name 'Alias2'
            Set-Alias 'Alias3' 'Write-Verbose'
            " | Out-File -FilePath "$TestDrive/MockBuiltModule.psm1" -Encoding ascii -Force
        }

        It "returns a hashtable with correct aliases" {
            $Result = InModuleScope ModuleBuilder {
                $ParseErrors, $Tokens = $null
                $mockAST = [System.Management.Automation.Language.Parser]::ParseFile("$TestDrive/MockBuiltModule.psm1", [ref]$Tokens, [ref]$ParseErrors)

                GetCommandAlias -Ast $mockAST
            }

            $Result.Count | Should -Be 3
            $Result['Alias1'] | Should -Be 'Alias1'
            $Result['Alias2'] | Should -Be 'Alias2'
            $Result['Alias3'] | Should -Be 'Alias3'
        }
    }

    Context "Parsing Code For New-Alias" {
        BeforeAll {
            # Must write a mock module script file and parse it to replicate real conditions
            "
            function Get-Something {
                param()

                New-Alias -Name 'Alias1' -Value 'Write-Verbose'
                Set-Alias -Name 'Alias2' -Value 'Write-Verbose'
            }

            New-Alias -Name 'Alias3' -Value 'Write-Verbose'
            " | Out-File -FilePath "$TestDrive/MockBuiltModule.psm1" -Encoding ascii -Force
        }

        It "returns a hashtable with just the aliases at script-level" {
            $Result = InModuleScope ModuleBuilder {
                $ParseErrors, $Tokens = $null
                $mockAST = [System.Management.Automation.Language.Parser]::ParseFile("$TestDrive/MockBuiltModule.psm1", [ref]$Tokens, [ref]$ParseErrors)

                GetCommandAlias -Ast $mockAST
            }

            $Result.Count | Should -Be 2
            $Result['Get-Something'] | Should -BeNullOrEmpty # Does not return any alias for this function
            $Result['Alias3'] | Should -Be 'Alias3'
        }
    }

    Context "Parsing Code For *-Alias Using Global Scope" {
        BeforeAll {
            # Must write a mock module script file and parse it to replicate real conditions
            "
            Set-Alias -Name 'Alias1' -Value 'Write-Verbose' -Scope Global
            Set-Alias -Name 'Alias2' -Value 'Write-Verbose' -Scope 'Global'
            Set-Alias -Value 'Write-Verbose' -Scope Global -Name 'Alias3'
            Set-Alias -Scope Global -Value 'Write-Verbose' -Name 'Alias4'
            Set-Alias 'Alias5' 'Write-Verbose' -Scope Global
            Set-Alias 'Alias6' -Scope Global 'Write-Verbose'
            Set-Alias -Scope Global 'Alias7' 'Write-Verbose'

            New-Alias -Name 'Alias8' -Value 'Write-Verbose' -Scope Global
            New-Alias -Name 'Alias9' -Value 'Write-Verbose' -Scope 'Global'
            New-Alias -Value 'Write-Verbose' -Scope Global -Name 'Alias10'
            New-Alias -Scope Global -Value 'Write-Verbose' -Name 'Alias11'
            New-Alias 'Alias12' 'Write-Verbose' -Scope Global
            New-Alias 'Alias13' -Scope Global 'Write-Verbose'
            New-Alias -Scope Global 'Alias14' 'Write-Verbose'

            New-Alias 'Alias15' 'Write-Verbose'
            " | Out-File -FilePath "$TestDrive/MockBuiltModule.psm1" -Encoding ascii -Force
        }

        It "returns a hashtable with correct aliases" {
            $Result = InModuleScope ModuleBuilder {
                $ParseErrors, $Tokens = $null
                $mockAST = [System.Management.Automation.Language.Parser]::ParseFile("$TestDrive/MockBuiltModule.psm1", [ref]$Tokens, [ref]$ParseErrors)

                GetCommandAlias -Ast $mockAST
            }

            $Result.Count | Should -Be 1
            $Result['Alias15'] | Should -Be 'Alias15'
        }
    }

    Context "Parsing Code For Remove-Alias" {
        BeforeAll {
            # Must write a mock module script file and parse it to replicate real conditions
            "
            New-Alias -Name 'Alias1' -Value 'Write-Verbose'
            New-Alias -Name 'Alias2' -Value 'Write-Verbose'
            Remove-Alias -Name 'Alias2'
            " | Out-File -FilePath "$TestDrive/MockBuiltModule.psm1" -Encoding ascii -Force

            Mock -CommandName Write-Warning -ModuleName 'ModuleBuilder'

        }

        It "returns a hashtable with correct aliases" {
            $Result = InModuleScope ModuleBuilder {
                $ParseErrors, $Tokens = $null
                $mockAST = [System.Management.Automation.Language.Parser]::ParseFile("$TestDrive/MockBuiltModule.psm1", [ref]$Tokens, [ref]$ParseErrors)

                GetCommandAlias -Ast $mockAST
            }

            $Result.Count | Should -Be 1
            $Result['Alias1'] | Should -Be 'Alias1'

            Assert-MockCalled -CommandName Write-Warning -Exactly -Times 1 -Scope It -ModuleName 'ModuleBuilder'
        }
    }
}
