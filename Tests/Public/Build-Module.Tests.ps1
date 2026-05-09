Describe "Build-Module" {
    BeforeAll {
        . $PSScriptRoot\..\Convert-FolderSeparator.ps1
        $PSDefaultParameterValues = @{
            "Mock:ModuleName" = "ModuleBuilder"
        }
    }

    Context "Parameter Binding" {
        BeforeAll {
            $Parameters = (Get-Command Build-Module).Parameters
        }

        It "has an optional string parameter for the SourcePath" {
            $parameters.ContainsKey("SourcePath") | Should -Be $true
            $parameters["SourcePath"].ParameterType | Should -Be ([string])
            $parameters["SourcePath"].Attributes.Where{ $_ -is [Parameter] }.Mandatory | Should -Be $false
        }
        It "throws if the SourcePath doesn't exist" {
            { Build-Module -SourcePath TestDrive:/NoSuchPath } | Should -Throw "*Source must point to a valid module*"
        }

        It "has an optional string parameter for the OutputDirectory" {
            $parameters.ContainsKey("OutputDirectory") | Should -Be $true
            $parameters["OutputDirectory"].ParameterType | Should -Be ([string])
            $parameters["OutputDirectory"].Attributes.Where{ $_ -is [Parameter] }.Mandatory | Should -Be $false
        }

        It "has an optional parameter for setting the Version" {
            $parameters.ContainsKey("Version") | Should -Be $true
            $parameters["Version"].ParameterType | Should -Be ([version])
            $parameters["Version"].ParameterSets.Keys | Should -Not -Be "__AllParameterSets"
        }

        It "has an optional parameter for setting the Encoding" {
            $parameters.ContainsKey("Encoding") | Should -Be $true
            # Note that in PS Core, we can't use encoding types for parameters
            $parameters["Encoding"].ParameterType | Should -Be ([string])
            $parameters["Encoding"].Attributes.Where{ $_ -is [Parameter] }.Mandatory | Should -Be $false
        }

        It "Warns if you set the encoding to anything but UTF8" {
            $warns = @()
            # Note: Using WarningAction Stop just to avoid testing anything else here ;)
            try {
                Build-Module -Encoding ASCII -WarningAction Stop -WarningVariable +warns
            } catch {
                $warns.Message | Should -Match "recommend you build your script modules with UTF8 encoding"
            }
        }

        It "has an optional string parameter for a Prefix" {
            $parameters.ContainsKey("Prefix") | Should -Be $true
            $parameters["Prefix"].ParameterType | Should -Be ([string])
            $parameters["Prefix"].Attributes.Where{ $_ -is [Parameter] }.Mandatory | Should -Be $false
        }

        It "has an optional string parameter for a Suffix" {
            $parameters.ContainsKey("Suffix") | Should -Be $true
            $parameters["Suffix"].ParameterType | Should -Be ([string])
            $parameters["Suffix"].Attributes.Where{ $_ -is [Parameter] }.Mandatory | Should -Be $false
        }

        It "supports setting the Target to Clean, Build or both" {
            $parameters.ContainsKey("Target") | Should -Be $true

            # Techincally we could implement this a few other ways ...
            $parameters["Target"].ParameterType | Should -Be ([string])
            $parameters["Target"].Attributes.Where{ $_ -is [ValidateSet] }.ValidValues | Should -Be "Clean", "Build", "CleanBuild"
        }

        It "supports an optional string array parameter CopyPaths (which used to be CopyDirectories)" {
            $parameters.ContainsKey("CopyPaths") | Should -Be $true

            # Techincally we could implement this a few other ways ...
            $parameters["CopyPaths"].ParameterType | Should -Be ([string[]])
            $parameters["CopyPaths"].Aliases | Should -Contain "CopyDirectories"
        }

        It "has an Passthru switch parameter" {
            $parameters.ContainsKey("Passthru") | Should -Be $true
            $parameters["Passthru"].ParameterType | Should -Be ([switch])
        }
    }

    Context "Testing" {

        Context "When run with no parameters" {
            BeforeAll {
                Copy-Item $PSScriptRoot/../Integration/Source2 $TestDrive -Recurse
                Push-Location $TestDrive -StackName BuildModuleTest
                $script:OutputDirectory = New-Item -ItemType Directory -Path "$TestDrive/Output/Source2/1.0.0" -Force |
                    Convert-FolderSeparator
                $script:OutputManifest = Join-Path $OutputDirectory "Source2.psd1"
                $script:RootModule = Join-Path $OutputDirectory "Source2.psm1"
                $script:StaleFile = Join-Path $OutputDirectory "stale.txt"

                Set-Content -Path $StaleFile -Value "stale build output"

                try {
                    Build-Module
                } finally {
                    Pop-Location -StackName BuildModuleTest
                }

                $script:ModuleContent = Get-Content $RootModule
                $script:ManifestData = Import-PowerShellDataFile $OutputManifest
            }

            # NOTE: We're not just clearing output, but the whole folder
            It "Removes the output folder if it exists" {
                $StaleFile | Should -Not -Exist
            }

            It "Always (re)creates the OutputDirectory" {
                $OutputDirectory | Should -Exist
            }


            It "Moves all the using statements to the top of the module" {
                $ModuleContent[0] | Should -Be "using module ModuleBuilder"
                @($ModuleContent -eq "using module ModuleBuilder" ).Count | Should -Be 1
                @($ModuleContent -eq "# using module ModuleBuilder" ).Count | Should -Be 2
            }

            It "Combines the source files to a single psm1" {
                $RootModule | Should -FileContentMatch "function Get-Source"
                $RootModule | Should -FileContentMatch "function Set-Source"
            }

            It "Updates the metadata to set the FunctionsToExport" {
                $ManifestData.FunctionsToExport | Should -Be @("Get-Source", "Set-Source")
            }

            It "Updates the metadata to set the AliasesToExport" {
                @($ManifestData.AliasesToExport | Sort-Object) | Should -Be @("gs", "gsou", "ss", "ssou")
            }
        }

        Context "When run without 'Clean' in the target" {
            BeforeAll {
                Copy-Item $PSScriptRoot/../Integration/Source2 $TestDrive -Recurse
                Push-Location $TestDrive -StackName BuildModuleTest
                $script:OutputDirectory = New-Item -ItemType Directory -Path "$TestDrive/Output/Source2/1.0.0" -Force |
                    Convert-FolderSeparator
                $script:OutputManifest = Join-Path $OutputDirectory "Source2.psd1"
                $script:RootModule = Join-Path $OutputDirectory "Source2.psm1"
                $script:StaleFile = Join-Path $OutputDirectory "stale.txt"

                Set-Content -Path $RootModule -Value "prebuilt sentinel"
                Copy-Item "$TestDrive/Source2/Source2.psd1" $OutputManifest -Force
                Set-Content -Path $StaleFile -Value "stale build output"

                # Force the date so we can prove it didn't get overwritten
                $script:ExpectedLastWriteTime = (Get-Date).AddMinutes(5)
                (Get-Item $RootModule).LastWriteTime = $ExpectedLastWriteTime
                (Get-Item $OutputManifest).LastWriteTime = $ExpectedLastWriteTime

                try {
                    Build-Module -Target Build
                } finally {
                    Pop-Location -StackName BuildModuleTest
                }
            }

            # NOTE: We're not just clearing output, but the whole folder
            It "Does NOT remove the output folder" {
                $StaleFile | Should -Exist
            }

            It "Still (re)creates the OutputDirectory" {
                $OutputDirectory | Should -Exist
            }

            It "Does not rebuild the source files" {
                (Get-Item $RootModule).LastWriteTime | Should -Be $ExpectedLastWriteTime
                Get-Content $RootModule -Raw | Should -Match "prebuilt sentinel"
            }
        }

        Context "Setting the version to a SemVer string" {
            BeforeAll {
                $SemVer = "2.1.0-beta03+sha.22c35ffff166f34addc49a3b80e622b543199cc5.Date.2018-10-11"
                $global:ExpectedVersion = "2.1.0"

                Copy-Item $PSScriptRoot/../Integration/Source2 $TestDrive -Recurse
                Push-Location $TestDrive -StackName BuildModuleTest

                $script:OutputDirectory = Convert-FolderSeparator "$TestDrive/Output/Source2/$ExpectedVersion/"
                $script:OutputManifest = Join-Path $OutputDirectory "Source2.psd1"

                Build-Module -SemVer $SemVer
                $script:ManifestData = Import-PowerShellDataFile $OutputManifest
            }
            AfterAll {
                Pop-Location -StackName BuildModuleTest
            }

            It "Creates an output folder with the expected version." {
                $OutputDirectory | Should -Exist
            }

            It "Updates the module version to the expected version." {
                $ManifestData.ModuleVersion | Should -Be $ExpectedVersion
            }
            It "Updates the module pre-release version" {
                $ManifestData.PrivateData.PSData.Prerelease | Should -Be "beta03"
            }
            It "When there are simple release notes, it inserts a new line with the module name and full semver" {
                Mock Get-Metadata { "First Release" }
                Mock Update-Metadata

                Build-Module -SemVer $SemVer

                Should -Invoke Update-Metadata -ModuleName ModuleBuilder -ParameterFilter {
                    $PropertyName -eq "PrivateData.PSData.ReleaseNotes" -and $Value -eq "Source2 v$($SemVer)`nFirst Release"
                } -Scope Context
            }

            It "When there's no release notes, it inserts a new line with the module name and full semver" {
                # If there's no release notes, but it was left uncommented
                Mock Get-Metadata { "" }
                Mock Update-Metadata

                Build-Module -SemVer $SemVer

                Should -Invoke Update-Metadata -ModuleName ModuleBuilder -ParameterFilter {
                    $PropertyName -eq "PrivateData.PSData.ReleaseNotes" -and $Value -eq "Source2 v$SemVer"
                }
            }

            It "When there's a prefix empty line, it inserts a new line with the module name and full semver the same way" {
                Mock Get-Metadata { "
                        Multi-line Release Notes
                        With a prefix carriage return"
                }

                Mock Update-Metadata

                Build-Module -SemVer $SemVer

                Should -Invoke Update-Metadata -ModuleName ModuleBuilder -ParameterFilter {
                    $PropertyName -eq "PrivateData.PSData.ReleaseNotes" -and $Value -eq "
                        Source2 v$SemVer
                        Multi-line Release Notes
                        With a prefix carriage return"
                }
            }
        }

        Context "Setting the version and pre-release" {
            BeforeAll {
                $SemVer = @{
                    Version       = "2.1.0"
                    Prerelease    = "beta03"
                    BuildMetadata = "Sha.22c35ffff166f34addc49a3b80e622b543199cc5.Date.2018-10-11"
                }
                $global:ExpectedSemVer = "2.1.0-beta03+sha.22c35ffff166f34addc49a3b80e622b543199cc5.Date.2018-10-11"
                $global:ExpectedVersion = "2.1.0"
                Copy-Item $PSScriptRoot/../Integration/Source2 $TestDrive -Recurse
                Push-Location $TestDrive -StackName BuildModuleTest
                $script:OutputDirectory = Convert-FolderSeparator "$TestDrive/Output/Source2/$ExpectedVersion/"
                $script:OutputManifest = Join-Path $OutputDirectory "Source2.psd1"
                New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

                Build-Module @SemVer
                $script:ManifestData = Import-PowerShellDataFile $OutputManifest
            }

            AfterAll {
                Pop-Location -StackName BuildModuleTest
            }

            It "Builds an output folder with the expected version." {
                $OutputDirectory | Should -Exist
            }

            It "Updates the module version to the expected version." {
                $ManifestData.ModuleVersion | Should -Be $ExpectedVersion
            }
            It "Updates the module pre-release version" {
                $ManifestData.PrivateData.PSData.Prerelease | Should -Be "beta03"
            }

            It "When there are simple release notes, it inserts a new line with the module name and full semver" {
                Mock Get-Metadata { "First Release" }
                Mock Update-Metadata

                Build-Module @SemVer

                Should -Invoke Update-Metadata -ModuleName ModuleBuilder -ParameterFilter {
                    $PropertyName -eq "PrivateData.PSData.ReleaseNotes" -and $Value -eq "Source2 v$($ExpectedSemVer)`nFirst Release"
                } -Scope Context
            }

            It "When there's no release notes, it inserts a new line with the module name and full semver" {
                # If there's no release notes, but it was left uncommented
                Mock Get-Metadata { "" }
                Mock Update-Metadata

                Build-Module @SemVer

                Should -Invoke Update-Metadata -ModuleName ModuleBuilder -ParameterFilter {
                    $PropertyName -eq "PrivateData.PSData.ReleaseNotes" -and $Value -eq "Source2 v$ExpectedSemVer"
                }
            }

            It "When there's a prefix empty line, it inserts a new line with the module name and full semver the same way" {
                Mock Get-Metadata { "
                        Multi-line Release Notes
                        With a prefix carriage return"
                }

                Mock Update-Metadata

                Build-Module @SemVer

                Should -Invoke Update-Metadata -ModuleName ModuleBuilder -ParameterFilter {
                    $PropertyName -eq "PrivateData.PSData.ReleaseNotes" -and $Value -eq "
                        Source2 v$ExpectedSemVer
                        Multi-line Release Notes
                        With a prefix carriage return"
                }
            }
        }

        Context "Setting the version with no pre-release" {
            BeforeAll {
                $SemVer = @{
                    Version       = "2.1.0"
                    BuildMetadata = "Sha.22c35ffff166f34addc49a3b80e622b543199cc5.Date.2018-10-11"
                }
                $global:ExpectedSemVer = "2.1.0+sha.22c35ffff166f34addc49a3b80e622b543199cc5.Date.2018-10-11"
                $global:ExpectedVersion = "2.1.0"
                Copy-Item $PSScriptRoot/../Integration/Source2 $TestDrive -Recurse
                Push-Location $TestDrive -StackName BuildModuleTest
                $script:OutputDirectory = Convert-FolderSeparator "$TestDrive/Output/Source2/$ExpectedVersion/"
                $script:OutputManifest = Join-Path $OutputDirectory "Source2.psd1"
                New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

                Build-Module @SemVer
                $script:ManifestData = Import-PowerShellDataFile $OutputManifest
            }
            AfterAll {
                Pop-Location -StackName BuildModuleTest
            }

            It "Builds to an output folder with the simple version." {
                $OutputDirectory | Should -Exist
            }

            It "Updates the module version to the simple version." {
                $ManifestData.ModuleVersion | Should -Be $ExpectedVersion
            }
            It "Does not change the module pre-release value" {
                $ManifestData.PrivateData.PSData.Prerelease | Should -Be ""
            }
        }
        <#
        Context "Bug #70 Cannot build 1.2.3-pre-release" {
            BeforeEach {
                Push-Location TestDrive:/ -StackName BuildModuleTest
                New-Item -ItemType Directory -Path TestDrive:/MyModule/ -Force
                New-Item -ItemType Directory -Path "TestDrive:/$ExpectedVersion/" -Force

                Mock ImportModuleManifest {
                    [PSCustomObject]@{
                        Name       = "MyModule"
                        ModuleBase = "TestDrive:/MyModule/"
                    }
                }

                $global:Mock_OutputPath = Convert-FolderSeparator "TestDrive:/MyModule/$ExpectedVersion"

                Mock Get-ChildItem {
                    [IO.FileInfo]"$TestDrive/MyModule/Public/Get-MyInfo.ps1"
                }
            }
            AfterEach {
                Pop-Location -StackName BuildModuleTest
            }

            Context "When I Build-Module -Version 1.2.3 -Prerelease pre-release" {
                It "Should set the prerelese to 'pre-release'" {
                    Mock Update-Metadata -ParameterFilter {
                        $PropertyName -eq "PrivateData.PSData.Prerelease"
                    } -MockWith {
                        $Value | Should -Be "pre-release"
                    }

                    Mock GetBuildInfo {
                        # These are actually all the values that we need
                        [PSCustomObject]@{
                            OutputDirectory = "TestDrive:/$Version"
                            Name            = "MyModule"
                            Version         = [Version]"1.2.3"
                            PreRelease      = "pre-release"
                            Target          = "CleanBuild"
                            SourcePath      = "TestDrive:/MyModule/"
                            CopyPaths       = @()
                            Encoding        = "UTF8"
                            PublicFilter    = "Public/*.ps1"
                        }
                    }


                    try {
                        Build-Module -Version "1.2.3" -Prerelease "pre-release"
                    } catch {
                        throw
                    }

                    Should -Invoke Update-Metadata -ModuleName ModuleBuilder -ParameterFilter {
                        $PropertyName -eq "PrivateData.PSData.Prerelease" -and $Value -eq "pre-release"
                    } -Scope It
                }
            }


            Context "When I Build-Module -SemVer 1.2.3-pre-release" {

                It "Should set the prerelese to 'pre-release'" {
                    Mock Update-Metadata -ParameterFilter {
                        $PropertyName -eq "PrivateData.PSData.Prerelease"
                    } -MockWith {
                        $Value | Should -Be "pre-release"
                    }

                    Mock GetBuildInfo {
                        # These are actually all the values that we need
                        [PSCustomObject]@{
                            OutputDirectory = "TestDrive:/$Version"
                            Name            = "MyModule"
                            Version         = [Version]"1.2.3"
                            PreRelease      = "pre-release"
                            Target          = "CleanBuild"
                            SourcePath      = "TestDrive:/MyModule/"
                            CopyPaths       = @()
                            Encoding        = "UTF8"
                            PublicFilter    = "Public/*.ps1"
                        }
                    }

                    try {
                        Build-Module -SemVer "1.2.3-pre-release"
                    } catch {
                        throw
                    }

                    Should -Invoke Update-Metadata -ModuleName ModuleBuilder -ParameterFilter {
                        $PropertyName -eq "PrivateData.PSData.Prerelease" -and $Value -eq "pre-release"
                    }
                }
            }
        }
        #>
    }
}
