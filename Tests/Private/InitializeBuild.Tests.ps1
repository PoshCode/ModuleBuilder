#requires -Module ModuleBuilder
Describe "InitializeBuild" {
    BeforeAll {
        . $PSScriptRoot\..\Convert-FolderSeparator.ps1
    }

    Context "It collects the initial data" {
        BeforeAll {
            # Note that "Path" is an alias for "SourcePath"
            New-Item "TestDrive:\build.psd1" -Type File -Force -Value '@{
                Path = ".\Source\MyModule.psd1"
                SourceDirectories = @("Classes", "Private", "Public")
            }'

            New-Item "TestDrive:\Source\" -Type Directory

            New-ModuleManifest "TestDrive:\Source\MyModule.psd1" -RootModule "MyModule.psm1" -Author "Test Manager" -ModuleVersion "1.0.0"

            $Result = @{}
        }

        It "Handles Build-Module parameters, and the build.psd1 configuration" {
            Push-Location TestDrive:\
            $Result.Result = InModuleScope -ModuleName ModuleBuilder {
                function Test-Build {
                    [CmdletBinding()]
                    param(
                        [Alias("ModuleManifest", "Path")]
                        $SourcePath = ".\Source",
                        $SourceDirectories = @("Enum", "Classes", "Private", "Public"),
                        $OutputDirectory = ".\Output",
                        $VersionedOutputDirectory = $true,
                        $UnversionedOutputDirectory = $true,
                        $Suffix
                    )
                    try {
                        Write-Warning $($MyInvocation.MyCommand | Out-String)
                        InitializeBuild -SourcePath $SourcePath
                    } catch {
                        $_
                    }
                }

                Test-Build 'TestDrive:\' -Suffix "Export-ModuleMember *"
            }
            Pop-Location
            $Result.Result | Should -Not -BeOfType [System.Management.Automation.ErrorRecord]
        }
        # $Result | Format-List * -Force | Out-Host

        It "Returns the ModuleInfo combined with the BuildInfo" {
            $Result.Result.Name | Should -Be "MyModule"
            $Result.Result.SourceDirectories | Should -Be @("Classes", "Private", "Public")

            (Convert-FolderSeparator $Result.Result.ModuleBase) |
                Should -Be (Convert-FolderSeparator "TestDrive:\Source")

            (Convert-FolderSeparator $Result.Result.SourcePath) |
                Should -Be (Convert-FolderSeparator "TestDrive:\Source\MyModule.psd1")
        }

        It "Returns default values from the Build Command" {
            $Result.Result.OutputDirectory | Should -Be ".\Output"
        }

        It "Returns overridden values from the build manifest" {
            $Result.Result.SourceDirectories | Should -Be @("Classes", "Private", "Public")
        }

        It "Returns overridden values from parameters" {
            $Result.Result.SourcePath | Should -Be (Convert-Path 'TestDrive:\Source\MyModule.psd1')
        }

        It "Sets VersionedOutputDirectory FALSE when UnversionedOutputDirectory is TRUE" {
            $Result.Result.VersionedOutputDirectory | Should -Be $false
        }
    }

    Context "Semver 2.0 to Semver 1.0" {
        BeforeAll {
            # Note that "Path" is an alias for "SourcePath"
            New-Item "TestDrive:\build.psd1" -Type File -Force -Value '@{
                Path = ".\Source\MyModule.psd1"
                SourceDirectories = @("Classes", "Private", "Public")
            }'

            New-Item "TestDrive:\Source\" -Type Directory

            New-ModuleManifest "TestDrive:\Source\MyModule.psd1" -RootModule "MyModule.psm1" -Author "Test Manager" -ModuleVersion "1.0.0"

            $Result = @{}
        }

        It "Handles Semver 2.0 prerelease values" {
            Push-Location TestDrive:\
            $Result.Result = InModuleScope -ModuleName ModuleBuilder {
                function Test-Build {
                    [CmdletBinding()]
                    param(
                        [Alias("ModuleManifest", "Path")]
                        $SourcePath = "./Source",
                        $SourceDirectories = @("Enum", "Classes", "Private", "Public"),
                        $OutputDirectory = "./Output",
                        $VersionedOutputDirectory = $true,
                        $UnversionedOutputDirectory = $false,
                        # ^ those are required for InitializeBuild to not throw
                        # v these are what we're testing
                        [string]$SemVer = "1.0.0-alpha.1+build.12.sha.abcdef",
                        [version]$Version = "1.0.0",
                        [string]$Prerelease = "alpha.1",
                        [string]$BuildMetadata = "build.12.sha.abcdef",
                        [int]$ZeroPadLegacy = 4
                    )
                    try {
                        Write-Warning $($MyInvocation.MyCommand | Out-String)
                        InitializeBuild -SourcePath $SourcePath
                    } catch {
                        $_
                    }
                }

                Test-Build 'TestDrive:\'
            }
            Pop-Location

            $Result.Result | Should -Not -BeOfType [System.Management.Automation.ErrorRecord]
        }

        It "Converts the dots to _ in the Prerelease " {
            $Result.Result.Prerelease | Should -Match "alpha_"
        }

        It "ZeroPads the prerelease numbers to make them sort correctly" {
            $Result.Result.Prerelease | Should -Be "alpha_0001"
        }

        It "Handles multiple numeric sections" {
            Push-Location TestDrive:\
            $Result.Result = InModuleScope -ModuleName ModuleBuilder {
                function Test-Build {
                    [CmdletBinding()]
                    param(
                        [Alias("ModuleManifest", "Path")]
                        $SourcePath = "./Source",
                        $SourceDirectories = @("Enum", "Classes", "Private", "Public"),
                        $OutputDirectory = "./Output",
                        $VersionedOutputDirectory = $true,
                        $UnversionedOutputDirectory = $false,
                        # ^ those are required for InitializeBuild to not throw
                        # v these are what we're testing
                        [string]$SemVer = "1.0.0-alpha.1+build.12.sha.abcdef",
                        [version]$Version = "1.0.0",
                        [string]$Prerelease = "alpha.1.2",
                        [string]$BuildMetadata = "build.12.sha.abcdef",
                        [int]$ZeroPadLegacy = 4
                    )
                    try {
                        Write-Warning $($MyInvocation.MyCommand | Out-String)
                        InitializeBuild -SourcePath $SourcePath
                    } catch {
                        $_
                    }
                }

                Test-Build 'TestDrive:\'
            }
            Pop-Location

            $Result.Result | Should -Not -BeOfType [System.Management.Automation.ErrorRecord]
        }

        It "Converts the dots to _ in the Prerelease " {
            $Result.Result.Prerelease | Should -Match "alpha_"
        }

        It "ZeroPads the prerelease numbers to make them sort correctly" {
            $Result.Result.Prerelease | Should -Be "alpha_0001_0002"
        }
    }
}
