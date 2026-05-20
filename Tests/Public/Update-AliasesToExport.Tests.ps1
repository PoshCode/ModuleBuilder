#requires -Module ModuleBuilder
Describe "Update-AliasesToExport" {
    BeforeAll {
        $ManifestPath = Join-Path $TestDrive "TestModule.psd1"
    }

    Context "Parsing [Alias()] attributes on functions" {
        BeforeEach {
            New-ModuleManifest -Path $ManifestPath -AliasesToExport @()
        }

        It "Returns a collection of aliases from the [Alias()] attribute" {
            Invoke-ScriptGenerator -Code {
                function Test-Alias {
                    [Alias("Foo", "Bar", "Alias")]
                    param()
                }
            } -Generator Update-AliasesToExport -Parameters @{ ModuleManifest = $ManifestPath }

            $aliases = Get-Metadata -Path $ManifestPath -PropertyName AliasesToExport
            $aliases | Sort-Object | Should -Be (@("Foo", "Bar", "Alias") | Sort-Object)
        }

        It "Parses only top-level functions (skips nested function aliases)" {
            Invoke-ScriptGenerator -Code {
                function Test-Alias {
                    [Alias("TA", "TAlias")]
                    param()
                }

                function TestAlias {
                    [Alias("T")]
                    param()

                    # This nested function's alias should NOT be exported
                    function Test-Negative {
                        [Alias("TN")]
                        param()
                    }
                }
            } -Generator Update-AliasesToExport -Parameters @{ ModuleManifest = $ManifestPath }

            $aliases = Get-Metadata -Path $ManifestPath -PropertyName AliasesToExport
            $aliases | Should -HaveCount 3
            $aliases | Should -BeIn @("TA", "TAlias", "T")
            "TN" | Should -Not -BeIn $aliases
        }
    }

    Context "Parsing New-Alias" {
        BeforeEach {
            New-ModuleManifest -Path $ManifestPath -AliasesToExport @()
        }

        It "Parses alias names regardless of parameter order" {
            Invoke-ScriptGenerator -Code {
                New-Alias -N 'Alias1' -Va 'Write-Verbose'
                New-Alias -Value 'Write-Verbose' -Name 'Alias2'
                New-Alias Alias3 Write-Verbose
                New-Alias -Value 'Write-Verbose' 'Alias4'
                New-Alias 'Alias5' -Value 'Write-Verbose'
            } -Generator Update-AliasesToExport -Parameters @{ ModuleManifest = $ManifestPath }

            $aliases = Get-Metadata -Path $ManifestPath -PropertyName AliasesToExport
            $aliases | Sort-Object | Should -Be (@('Alias1', 'Alias2', 'Alias3', 'Alias4', 'Alias5') | Sort-Object)
        }

        It "Ignores aliases defined in nested function scope" {
            Invoke-ScriptGenerator -Code {
                New-Alias -Name 'Alias1' -Value 'Write-Verbose'
                New-Alias -Value 'Write-Verbose' -Name 'Alias2'
                New-Alias 'Alias3' 'Write-Verbose'
                function Get-Something {
                    param()
                    New-Alias -Name Alias4 -Value 'Write-Verbose'
                    New-Alias -Name Alias5 -Va 'Write-Verbose'
                }
            } -Generator Update-AliasesToExport -Parameters @{ ModuleManifest = $ManifestPath }

            $aliases = Get-Metadata -Path $ManifestPath -PropertyName AliasesToExport
            $aliases | Sort-Object | Should -Be (@('Alias1', 'Alias2', 'Alias3') | Sort-Object)
        }

        It "Ignores aliases that have global scope" {
            Invoke-ScriptGenerator -Code {
                New-Alias -Name Alias1 -Scope Global -Value Write-Verbose
                New-Alias -Scope Global -Value 'Write-Verbose' -Name 'Alias2'
                New-Alias -Sc Global 'Alias3' 'Write-Verbose'
                New-Alias -Va 'Write-Verbose' 'Alias4' -S Global
                New-Alias Alias5 -Value 'Write-Verbose' -Scope Global
            } -Generator Update-AliasesToExport -Parameters @{ ModuleManifest = $ManifestPath }

            $aliases = Get-Metadata -Path $ManifestPath -PropertyName AliasesToExport
            $aliases | Should -BeNullOrEmpty
        }
    }

    Context "Parsing Set-Alias" {
        BeforeEach {
            New-ModuleManifest -Path $ManifestPath -AliasesToExport @()
        }

        It "Parses alias names regardless of parameter order" {
            Invoke-ScriptGenerator -Code {
                Set-Alias -Name Alias1 -Value Write-Verbose
                Set-Alias -Va 'Write-Verbose' -N 'Alias2'
                Set-Alias Alias3 Write-Verbose
                Set-Alias -Va 'Write-Verbose' 'Alias4'
                Set-Alias 'Alias5' -Value 'Write-Verbose'
            } -Generator Update-AliasesToExport -Parameters @{ ModuleManifest = $ManifestPath }

            $aliases = Get-Metadata -Path $ManifestPath -PropertyName AliasesToExport
            $aliases | Sort-Object | Should -Be (@('Alias1', 'Alias2', 'Alias3', 'Alias4', 'Alias5') | Sort-Object)
        }

        It "Ignores aliases defined in nested function scope" {
            Invoke-ScriptGenerator -Code {
                Set-Alias -Name 'Alias1' -Value 'Write-Verbose'
                Set-Alias -Value 'Write-Verbose' -Name 'Alias2'
                Set-Alias 'Alias3' 'Write-Verbose'
                function Get-Something {
                    param()
                    Set-Alias -Name 'Alias4' -Value 'Write-Verbose'
                    Set-Alias -Name 'Alias5' -Value 'Write-Verbose'
                }
            } -Generator Update-AliasesToExport -Parameters @{ ModuleManifest = $ManifestPath }

            $aliases = Get-Metadata -Path $ManifestPath -PropertyName AliasesToExport
            $aliases | Sort-Object | Should -Be (@('Alias1', 'Alias2', 'Alias3') | Sort-Object)
        }

        It "Ignores aliases that have global scope" {
            Invoke-ScriptGenerator -Code {
                Set-Alias -N 'Alias1' -Scope Global -Value 'Write-Verbose'
                Set-Alias -Scope Global -Value 'Write-Verbose' -Name 'Alias2'
                Set-Alias -Sc Global Alias3 Write-Verbose
                Set-Alias -Va 'Write-Verbose' 'Alias4' -Sc Global
                Set-Alias 'Alias5' -Value 'Write-Verbose' -Scope Global
            } -Generator Update-AliasesToExport -Parameters @{ ModuleManifest = $ManifestPath }

            $aliases = Get-Metadata -Path $ManifestPath -PropertyName AliasesToExport
            $aliases | Should -BeNullOrEmpty
        }

        # It "Detects variable Name as dynamic alias generation and sets AliasesToExport = '*'" {
        #     Invoke-ScriptGenerator -Code {
        #         $taskAlias = "my-task"
        #         Set-Alias -Name $taskAlias -Value 'Write-Verbose'
        #     } -Generator Update-AliasesToExport -Parameters @{ ModuleManifest = $ManifestPath } -WarningVariable warnings 3>$null

        #     $aliases = Get-Metadata -Path $ManifestPath -PropertyName AliasesToExport
        #     $aliases | Should -Be '*'
        #     $warnings | Should -Not -BeNullOrEmpty
        # }

        # It "Detects dynamic alias generation inside ForEach-Object and sets AliasesToExport = '*'" {
        #     Invoke-ScriptGenerator -Code {
        #         @('a', 'b') | ForEach-Object {
        #             $taskAlias = "task-$_"
        #             Set-Alias -Name $taskAlias -Value 'Write-Verbose'
        #         }
        #     } -Generator Update-AliasesToExport -Parameters @{ ModuleManifest = $ManifestPath } -WarningVariable warnings 3>$null

        #     $aliases = Get-Metadata -Path $ManifestPath -PropertyName AliasesToExport
        #     $aliases | Should -Be '*'
        #     $warnings | Should -Not -BeNullOrEmpty
        # }

        It "Does NOT flag Set-Alias with variable Name inside a function definition as dynamic" {
            Invoke-ScriptGenerator -Code {
                Set-Alias 'TopAlias' 'Write-Verbose'
                function Set-DynamicAlias {
                    param($name)
                    Set-Alias -Name $name -Value 'Write-Verbose'
                }
            } -Generator Update-AliasesToExport -Parameters @{ ModuleManifest = $ManifestPath } -WarningVariable warnings 3>$null

            $aliases = Get-Metadata -Path $ManifestPath -PropertyName AliasesToExport
            $aliases | Should -Be 'TopAlias'
            $warnings | Should -BeNullOrEmpty
        }
    }

    Context "Remove-Alias cancels Alias exports" {
        BeforeEach {
            New-ModuleManifest -Path $ManifestPath -AliasesToExport @()
        }

        It "Parses Remove-Alias regardless of parameter order" {
            Invoke-ScriptGenerator -Code {
                New-Alias -Name Alias1 -Value Write-Verbose
                Set-Alias -Value 'Write-Verbose' -Name 'Alias2'
                New-Alias Alias3 Write-Verbose
                Set-Alias -Value 'Write-Verbose' 'Alias4'
                Set-Alias 'Alias5' -Value 'Write-Verbose'
                Remove-Alias Alias1
                Remove-Alias -Name Alias2
                Remove-Alias -N Alias5
            } -Generator Update-AliasesToExport -Parameters @{ ModuleManifest = $ManifestPath }

            $aliases = Get-Metadata -Path $ManifestPath -PropertyName AliasesToExport
            $aliases | Sort-Object | Should -Be (@('Alias3', 'Alias4') | Sort-Object)
        }

        It "Ignores Remove-Alias in nested function scopes" {
            Invoke-ScriptGenerator -Code {
                Set-Alias -Name 'Alias1' -Value 'Write-Verbose'
                New-Alias -Value 'Write-Verbose' -Name 'Alias2'
                Set-Alias 'Alias3' 'Write-Verbose'
                function Get-Something {
                    param()
                    Set-Alias -Name 'Alias4' -Value 'Write-Verbose'
                    Set-Alias -Name 'Alias5' -Value 'Write-Verbose'
                    Remove-Alias -Name Alias1
                }
            } -Generator Update-AliasesToExport -Parameters @{ ModuleManifest = $ManifestPath }

            $aliases = Get-Metadata -Path $ManifestPath -PropertyName AliasesToExport
            $aliases | Sort-Object | Should -Be (@('Alias1', 'Alias2', 'Alias3') | Sort-Object)
        }

        It "Does not fail when removing an alias that was already global scope (never added)" {
            Invoke-ScriptGenerator -Code {
                Set-Alias -Name Alias1 -Scope Global -Value Write-Verbose
                Remove-Alias -Name Alias1
            } -Generator Update-AliasesToExport -Parameters @{ ModuleManifest = $ManifestPath }

            $aliases = Get-Metadata -Path $ManifestPath -PropertyName AliasesToExport
            $aliases | Should -BeNullOrEmpty
        }
    }

    Context "When AliasesToExport is missing in the manifest" {
        It "Writes a warning and does not throw" {
            # Minimal manifest without AliasesToExport
            New-ModuleManifest -Path $ManifestPath
            (Get-Content $ManifestPath) -replace "^(.*AliasesToExport.*)$", '# $1' | Set-Content $ManifestPath

            Mock Write-Warning -ModuleName ModuleBuilder
            Mock Update-Metadata -ModuleName ModuleBuilder

            Invoke-ScriptGenerator -Code {
                function Test-Alias {
                    [Alias("TA")] param()
                }
            } -Generator Update-AliasesToExport -Parameters @{ ModuleManifest = $ManifestPath }

            Assert-MockCalled Write-Warning -ModuleName ModuleBuilder -Exactly 1 -Scope It
            # It does not even try to update the metadata
            Assert-MockCalled Update-Metadata -ModuleName ModuleBuilder -Exactly 0 -Scope It
            # It does not, in fact, update the AliasesToExport
            Get-Metadata -Path $ManifestPath -PropertyName AliasesToExport -ErrorAction Ignore | Should -BeNullOrEmpty
        }
    }

    Context "WhenNoAliases parameter" {
        BeforeEach {
            New-ModuleManifest -Path $ManifestPath -AliasesToExport @('ExistingAlias')
        }

        It "Does not update the manifest by default (DoNotSet) when no aliases are found" {
            Invoke-ScriptGenerator -Code {
                function Get-Something {
                    param()
                }
            } -Generator Update-AliasesToExport -Parameters @{ ModuleManifest = $ManifestPath }

            $aliases = Get-Metadata -Path $ManifestPath -PropertyName AliasesToExport
            $aliases | Should -Be 'ExistingAlias'
        }

        It "Sets AliasesToExport = '*' when WhenNoAliases = 'Wildcard' and no aliases found" {
            Invoke-ScriptGenerator -Code {
                function Get-Something {
                    param()
                }
            } -Generator Update-AliasesToExport -Parameters @{ ModuleManifest = $ManifestPath; WhenNoAliases = 'Wildcard' }

            $aliases = Get-Metadata -Path $ManifestPath -PropertyName AliasesToExport
            $aliases | Should -Be '*'
        }

        It "Sets AliasesToExport = @() when WhenNoAliases = 'EmptyArray' and no aliases found" {
            Invoke-ScriptGenerator -Code {
                function Get-Something {
                    param()
                }
            } -Generator Update-AliasesToExport -Parameters @{ ModuleManifest = $ManifestPath; WhenNoAliases = 'EmptyArray' }

            $aliases = Get-Metadata -Path $ManifestPath -PropertyName AliasesToExport
            $aliases | Should -BeNullOrEmpty
        }

        It "Always updates with found static aliases regardless of WhenNoAliases" {
            Invoke-ScriptGenerator -Code {
                function Test-Alias {
                    [Alias("TA")] param()
                }
            } -Generator Update-AliasesToExport -Parameters @{ ModuleManifest = $ManifestPath; WhenNoAliases = 'DoNotSet' }

            $aliases = Get-Metadata -Path $ManifestPath -PropertyName AliasesToExport
            $aliases | Should -Be 'TA'
        }
    }
}
