#requires -Module ModuleBuilder
Describe "Build-Module" {
    BeforeAll {
        . $PSScriptRoot\..\Convert-FolderSeparator.ps1

        $PSDefaultParameterValues = @{
            "Mock:ModuleName" = "ModuleBuilder"
            "Assert-MockCalled:ModuleName" = "ModuleBuilder"
        }
    }

    Context "Parameter Binding" {
        BeforeAll {
            $Parameters = (Get-Command Build-Module).Parameters
        }

        It "has an optional string parameter for the SourcePath" {
            $parameters.ContainsKey("SourcePath") | Should -Be $true
            $parameters["SourcePath"].ParameterType | Should -Be ([string])
            $parameters["SourcePath"].Attributes.Where{$_ -is [Parameter]}.Mandatory | Should -Be $false
        }
        It "throws if the SourcePath doesn't exist" {
            { Build-Module -SourcePath TestDrive:/NoSuchPath } | Should -Throw "*Source must point to a valid module*"
        }

        It "has an optional string parameter for the OutputDirectory" {
            $parameters.ContainsKey("OutputDirectory") | Should -Be $true
            $parameters["OutputDirectory"].ParameterType | Should -Be ([string])
            $parameters["OutputDirectory"].Attributes.Where{$_ -is [Parameter]}.Mandatory | Should -Be $false
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
            $parameters["Encoding"].Attributes.Where{$_ -is [Parameter]}.Mandatory | Should -Be $false
        }

        It "Warns if you set the encoding to anything but UTF8" {
            $warns = @()
            # Note: Using WarningAction Stop just to avoid testing anything else here ;)
            try { Build-Module -Encoding ASCII -WarningAction Stop -WarningVariable +warns } catch {}
            $warns.Message | Should -Match "recommend you build your script modules with UTF8 encoding"
        }

        It "has an optional string parameter for a Prefix" {
            $parameters.ContainsKey("Prefix") | Should -Be $true
            $parameters["Prefix"].ParameterType | Should -Be ([string])
            $parameters["Prefix"].Attributes.Where{$_ -is [Parameter]}.Mandatory | Should -Be $false
        }

        It "has an optional string parameter for a Suffix" {
            $parameters.ContainsKey("Suffix") | Should -Be $true
            $parameters["Suffix"].ParameterType | Should -Be ([string])
            $parameters["Suffix"].Attributes.Where{$_ -is [Parameter]}.Mandatory | Should -Be $false
        }

        It "supports setting the Target to Clean, Build or both" {
            $parameters.ContainsKey("Target") | Should -Be $true

            # Techincally we could implement this a few other ways ...
            $parameters["Target"].ParameterType | Should -Be ([string])
            $parameters["Target"].Attributes.Where{$_ -is [ValidateSet]}.ValidValues | Should -Be "Clean", "Build", "CleanBuild"
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
        BeforeAll {
            InModuleScope ModuleBuilder {
                Mock MoveUsingStatements
                Mock SetModuleContent
            }
            Mock Update-Metadata
            Mock Copy-Item
            Mock Set-Location

            Mock Join-Path {
                [IO.Path]::Combine($Path, $ChildPath)
            }

            Mock Get-Metadata {
                "First Release"
            }

            $global:Mock_OutputPath = Convert-FolderSeparator "TestDrive:/Output/MyModule"

            Mock New-Item { [IO.DirectoryInfo]("$TestDrive/Output/MyModule") } -Parameter {
            (Convert-FolderSeparator "$Path") -eq $Mock_OutputPath -and
                $ItemType -eq "Directory" -and $Force
            }

            Mock Test-Path { $True } -Parameter {
            (Convert-FolderSeparator "$Path") -eq $Mock_OutputPath -and ($PathType -notin "Any", "Leaf")
            }

            Mock Remove-Item -Parameter {
            (Convert-FolderSeparator "$Path") -eq $Mock_OutputPath
            }
        }


        Context "When run without parameters" {
            BeforeAll {
                Push-Location TestDrive:/ -StackName BuildModuleTest
                New-Item -ItemType Directory -Path TestDrive:/Output/MyModule/1.0.0/ -Force

                Mock ConvertToAst {
                    [PSCustomObject]@{
                        PSTypeName  = "PoshCode.ModuleBuilder.ParseResults"
                        ParseErrors = $null
                        Tokens      = $null
                        AST         = { }.AST
                    }
                }
                Mock GetCommandAlias { @{'Get-MyInfo' = @('GMI') } }
                Mock InitializeBuild {
                    # These are actually all the values that we need
                    [PSCustomObject]@{
                        OutputDirectory = "TestDrive:/Output"
                        Name            = "MyModule"
                        Version         = [Version]"1.0.0"
                        Target          = "CleanBuild"
                        ModuleBase      = "TestDrive:/MyModule/"
                        CopyDirectories = @()
                        Encoding        = "UTF8"
                        PublicFilter    = "Public/*.ps1"
                    }
                }

                Mock Push-Location {}

                # So it doesn't have to exist
                Mock Convert-Path { $Path }
                Mock Get-ChildItem {
                    [IO.FileInfo]"$TestDrive/Output/MyModule/Public/Get-MyInfo.ps1"
                }


                try {
                    Build-Module
                } finally {
                    Pop-Location -StackName BuildModuleTest
                }
            }

            # NOTE: We're not just clearing output, but the whole folder
            It "Should remove the output folder if it exists" {
                Assert-MockCalled Remove-Item -Scope Context
            }

            It "Should always (re)create the OutputDirectory" {
                Assert-MockCalled New-Item -Scope Context
            }

            It "Should run in the module source folder" {
                Assert-MockCalled Push-Location -Parameter {
                    $Path -eq "TestDrive:/MyModule/"
                } -Scope Context
            }

            It "Should call ConvertToAst to parse the module" {
                Assert-MockCalled ConvertToAst -Scope Context
            }

            It "Should call MoveUsingStatements to move the using statements, just in case" {
                Assert-MockCalled MoveUsingStatements -Parameter {
                    $AST.Extent.Text -eq "{ }"
                } -Scope Context
            }

            It "Should call SetModuleContent to combine the source files" {
                Assert-MockCalled SetModuleContent -Scope Context
            }

            It "Should call Update-Metadata to set the FunctionsToExport" {
                Assert-MockCalled Update-Metadata -Parameter {
                    $PropertyName -eq "FunctionsToExport"
                } -Scope Context
            }

            It "Should call Update-Metadata to set the AliasesToExport" {
                Assert-MockCalled Update-Metadata -Parameter {
                    $PropertyName -eq "AliasesToExport"
                } -Scope Context
            }
        }

        Context "When run without 'Clean' in the target" {
            BeforeAll {
                $PSDefaultParameterValues = @{
                    "Mock:ModuleName"              = "ModuleBuilder"
                    "Assert-MockCalled:ModuleName" = "ModuleBuilder"
                }

                Push-Location TestDrive:/ -StackName BuildModuleTest
                New-Item -ItemType Directory -Path TestDrive:/MyModule/Public -Force
                New-Item -ItemType File -Path TestDrive:/MyModule/Public/Get-MyInfo.ps1 -Force
                Start-Sleep -Milliseconds 200 # to ensure the output is after the input
                New-Item -ItemType Directory -Path TestDrive:/1.0.0/ -Force
                New-Item -ItemType File -Path TestDrive:/1.0.0/MyModule.psm1 -Force

                Mock InitializeBuild {
                    # These are actually all the values that we need
                    [PSCustomObject]@{
                        OutputDirectory = "TestDrive:/Output"
                        Name            = "MyModule"
                        Version         = [Version]"1.0.0"
                        Target          = "Build"
                        ModuleBase      = "TestDrive:/MyModule/"
                        CopyDirectories = @()
                        Encoding        = "UTF8"
                        PublicFilter    = "Public/*.ps1"
                    }
                }

                Mock Convert-Path { $Path }

                Mock Get-ChildItem {
                    [IO.FileInfo]"$TestDrive/MyModule/Public/Get-MyInfo.ps1"
                }

                Mock Get-Item {
                    [PSCustomObject]@{ LastWriteTime = Get-Date }
                }

                try {
                    Build-Module -Target Build
                } finally {
                    Pop-Location -StackName BuildModuleTest
                }
            }

            # NOTE: We're not just clearing output, but the whole folder
            It "Should NOT remove the output folder" {
                Assert-MockCalled Remove-Item -Times 0 -Scope Context
            }

            It "Should check the dates on the output" {
                Assert-MockCalled Get-Item -Times 1 -Scope Context
            }

            It "Should always (re)create the OutputDirectory" {
                Assert-MockCalled New-Item -Times 1 -Scope Context
            }

            It "Should not rebuild the source files" {
                Assert-MockCalled SetModuleContent -Times 0 -Scope Context
            }
        }

        Context "Setting the version to a SemVer string" {
            BeforeAll {
                $SemVer = "1.0.0-beta03+sha.22c35ffff166f34addc49a3b80e622b543199cc5.Date.2018-10-11"
                $global:ExpectedVersion = "1.0.0"
                Push-Location TestDrive:/ -StackName BuildModuleTest
                New-Item -ItemType Directory -Path TestDrive:/MyModule/ -Force
                New-Item -ItemType Directory -Path "TestDrive:/Output/MyModule/$ExpectedVersion" -Force

                Mock ResolveBuildManifest { "TestDrive:/MyModule/build.psd1" }

                Mock GetBuildInfo {
                    [PSCustomObject]@{
                        OutputDirectory = "TestDrive:/Output"
                        SourcePath      = "TestDrive:/MyModule/"
                        SemVer          = $SemVer ?? "1.0.0-beta03+sha.22c35ffff166f34addc49a3b80e622b543199cc5.Date.2018-10-11"
                        Target          = "CleanBuild"
                        CopyPaths       = @()
                        Encoding        = "UTF8"
                        PublicFilter    = "Public/*.ps1"
                        VersionedOutputDirectory = $true
                    }
                }

                Mock ImportModuleManifest {
                    [PSCustomObject]@{
                        Name = "MyModule"
                        ModuleBase = "TestDrive:/MyModule/"
                    }
                }

                $global:Mock_OutputPath = Convert-FolderSeparator "TestDrive:/Output/MyModule/$ExpectedVersion"

                Mock Get-ChildItem {
                    [IO.FileInfo]"$TestDrive/MyModule/Public/Get-MyInfo.ps1"
                }

                try {
                    Build-Module -SemVer $SemVer
                } catch {
                    Pop-Location -StackName BuildModuleTest
                    throw
                }
            }

            It "Should build to an output folder with the simple version." {
                Assert-MockCalled Remove-Item -Scope Context
                Assert-MockCalled New-Item -Scope Context
            }

            It "Should update the module version to the simple version." {
                Assert-MockCalled Update-Metadata -ParameterFilter {
                    $PropertyName -eq "ModuleVersion" -and $Value -eq $ExpectedVersion
                } -Scope Context
            }
            It "Should update the module pre-release version" {
                Assert-MockCalled Update-Metadata -ParameterFilter {
                    $PropertyName -eq "PrivateData.PSData.Prerelease" -and $Value -eq "beta03"
                } -Scope Context
            }
            It "When there are simple release notes, it should insert a line with the module name and full semver" {
                Assert-MockCalled Update-Metadata -ParameterFilter {
                    $PropertyName -eq "PrivateData.PSData.ReleaseNotes" -and $Value -eq "MyModule v$($SemVer)`nFirst Release"
                } -Scope Context
            }

            It "When there's no release notes, it should insert the module name and full semver" {
                # If there's no release notes, but it was left uncommented
                Mock Get-Metadata { "" }

                try {
                    Build-Module -SemVer $SemVer
                } catch {
                    Pop-Location -StackName BuildModuleTest
                    throw
                }

                Assert-MockCalled Update-Metadata -ParameterFilter {
                    $PropertyName -eq "PrivateData.PSData.ReleaseNotes" -and $Value -eq "MyModule v$SemVer"
                }
            }

            It "When there's a prefix empty line, it should insert the module name and full semver the same way" {
                # If there's no release notes, but it was left uncommented
                Mock Get-Metadata { "
                        Multi-line Release Notes
                        With a prefix carriage return" }

                try {
                    Build-Module -SemVer $SemVer
                }  catch {
                    Pop-Location -StackName BuildModuleTest
                    throw
                }

                Assert-MockCalled Update-Metadata -ParameterFilter {
                    $PropertyName -eq "PrivateData.PSData.ReleaseNotes" -and $Value -eq "
                        MyModule v$SemVer
                        Multi-line Release Notes
                        With a prefix carriage return"
                }
            }
            AfterAll {
                Pop-Location -StackName BuildModuleTest
            }
        }

        Context "Setting the version and pre-release" {
            BeforeAll {
                # $SemVer = "1.0.0-beta03+sha.22c35ffff166f34addc49a3b80e622b543199cc5.Date.2018-10-11"
                $SemVer = @{
                    Version       = "1.0.0"
                    Prerelease    = "beta03"
                    BuildMetadata = "Sha.22c35ffff166f34addc49a3b80e622b543199cc5.Date.2018-10-11"
                }
                $global:ExpectedVersion = "1.0.0"
                Push-Location TestDrive:/ -StackName BuildModuleTest
                New-Item -ItemType Directory -Path TestDrive:/MyModule/ -Force
                New-Item -ItemType Directory -Path "TestDrive:/Output/MyModule" -Force

                Mock ResolveBuildManifest { "TestDrive:/MyModule/build.psd1" }

                Mock GetBuildInfo {
                    [PSCustomObject]@{
                        OutputDirectory = "TestDrive:/Output"
                        SourcePath      = "TestDrive:/MyModule/"
                        Version         = "1.0.0"
                        Prerelease      = "beta03"
                        BuildMetadata   = "Sha.22c35ffff166f34addc49a3b80e622b543199cc5.Date.2018-10-11"
                        Target          = "CleanBuild"
                        CopyPaths       = @()
                        Encoding        = "UTF8"
                        PublicFilter    = "Public/*.ps1"
                    }
                }

                Mock ImportModuleManifest {
                    [PSCustomObject]@{
                        Name       = "MyModule"
                        ModuleBase = "TestDrive:/MyModule/"
                    }
                }

                $global:Mock_OutputPath = Convert-FolderSeparator "TestDrive:/Output/MyModule"
                Mock Get-ChildItem {
                    [IO.FileInfo]"$TestDrive/MyModule/Public/Get-MyInfo.ps1"
                }

                try {
                    Build-Module @SemVer
                } catch {
                    Pop-Location -StackName BuildModuleTest
                    throw
                }
            }

            It "Should build to an output folder with the simple version." {
                Assert-MockCalled Remove-Item -Scope Context
                Assert-MockCalled New-Item -Scope Context
            }

            It "Should update the module version to the simple version." {
                Assert-MockCalled Update-Metadata -ParameterFilter {
                    $PropertyName -eq "ModuleVersion" -and $Value -eq $ExpectedVersion
                } -Scope Context
            }
            It "Should update the module pre-release version" {
                Assert-MockCalled Update-Metadata -ParameterFilter {
                    $PropertyName -eq "PrivateData.PSData.Prerelease" -and $Value -eq "beta03"
                } -Scope Context
            }
            It "When there are simple release notes, it should insert a line with the module name and full semver" {
                Assert-MockCalled Update-Metadata -ParameterFilter {
                    $PropertyName -eq "PrivateData.PSData.ReleaseNotes" -and
                        $Value -eq "MyModule v$($SemVer.Version)-$($SemVer.Prerelease)+$($SemVer.BuildMetadata)`nFirst Release"
                } -Scope Context
            }

            It "When there's no release notes, it should insert the module name and full semver" {
                # If there's no release notes, but it was left uncommented
                Mock Get-Metadata { "" }

                try {
                    Build-Module @SemVer
                } catch {
                    Pop-Location -StackName BuildModuleTest
                    throw
                }

                Assert-MockCalled Update-Metadata -ParameterFilter {
                    $PropertyName -eq "PrivateData.PSData.ReleaseNotes" -and
                        $Value -eq "MyModule v$($SemVer.Version)-$($SemVer.Prerelease)+$($SemVer.BuildMetadata)"
                }
            }

            It "When there's a prefix empty line, it should insert the module name and full semver the same way" {
                # If there's no release notes, but it was left uncommented
                Mock Get-Metadata { "
                        Multi-line Release Notes
                        With a prefix carriage return" }

                try {
                    Build-Module @SemVer
                }  catch {
                    Pop-Location -StackName BuildModuleTest
                    throw
                }

                Assert-MockCalled Update-Metadata -ParameterFilter {
                    $PropertyName -eq "PrivateData.PSData.ReleaseNotes" -and $Value -eq "
                        MyModule v$($SemVer.Version)-$($SemVer.Prerelease)+$($SemVer.BuildMetadata)
                        Multi-line Release Notes
                        With a prefix carriage return"
                }
            }
            AfterAll {
                Pop-Location -StackName BuildModuleTest
            }
        }

        Context "Setting the version with no pre-release" {
            BeforeAll {
                # $SemVer = "1.0.0-beta03+sha.22c35ffff166f34addc49a3b80e622b543199cc5.Date.2018-10-11"
                $SemVer = @{
                    Version       = "1.0.0"
                    BuildMetadata = "Sha.22c35ffff166f34addc49a3b80e622b543199cc5.Date.2018-10-11"
                }
                $global:ExpectedVersion = "1.0.0"
                Push-Location TestDrive:/ -StackName BuildModuleTest
                New-Item -ItemType Directory -Path TestDrive:/MyModule/ -Force
                New-Item -ItemType Directory -Path "TestDrive:/Output/MyModule" -Force

                Mock InitializeBuild {
                    # These are actually all the values that we need
                    [PSCustomObject]@{
                        OutputDirectory = "TestDrive:/Output"
                        Name            = "MyModule"
                        Version         = [Version]"1.0.0"
                        Target          = "CleanBuild"
                        ModuleBase      = "TestDrive:/MyModule/"
                        CopyPaths       = @()
                        Encoding        = "UTF8"
                        PublicFilter    = "Public/*.ps1"
                    }
                }
                Mock Convert-Path { $Path }
                $global:Mock_OutputPath = Convert-FolderSeparator "TestDrive:/Output/MyModule"

                Mock Get-ChildItem {
                    [IO.FileInfo]"$TestDrive/MyModule/Public/Get-MyInfo.ps1"
                }

                try {
                    Build-Module @SemVer
                } catch {
                    Pop-Location -StackName BuildModuleTest
                    throw
                }
            }

            It "Should build to an output folder with the simple version." {
                Assert-MockCalled Remove-Item -Scope Context
                Assert-MockCalled New-Item -Scope Context
            }

            It "Should update the module version to the simple version." {
                Assert-MockCalled Update-Metadata -ParameterFilter {
                    $PropertyName -eq "ModuleVersion" -and $Value -eq $ExpectedVersion
                } -Scope Context
            }
            It "Should not change the module pre-release value" {
                Assert-MockCalled Update-Metadata -Times 0 -ParameterFilter {
                    $PropertyName -eq "PrivateData.PSData.Prerelease"
                } -Scope Context
            }
            AfterAll {
                Pop-Location -StackName BuildModuleTest
            }
        }

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

                    Assert-MockCalled Update-Metadata -ParameterFilter {
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

                    Assert-MockCalled Update-Metadata -ParameterFilter {
                        $PropertyName -eq "PrivateData.PSData.Prerelease" -and $Value -eq "pre-release"
                    }
                }
            }
        }
    }

}
