Describe "InitializeBuild" {
    . $PSScriptRoot\..\Convert-FolderSeparator.ps1

    Mock ResolveModuleSource -ModuleName ModuleBuilder { $SourcePath }
    Mock ResolveModuleManifest -ModuleName ModuleBuilder {
        Convert-FolderSeparator "TestDrive:\Source\MyModule.psd1"
    }
    Mock Push-Location -ModuleName ModuleBuilder {}
    Mock Import-Metadata -ModuleName ModuleBuilder {
    Mock ResolveBuildManifest -ModuleName ModuleBuilder {
        "TestDrive:\Source\build.psd1"
    }
    Mock GetBuildInfo -ModuleName ModuleBuilder {
        @{
            Path = 'TestDrive:\Source\MyModule.psd1'
            OutputDirectory = '..\output'
        }
    }

    #Mock Update-Object -ModuleName ModuleBuilder { $InputObject }
    Mock Get-Variable -ParameterFilter {
        $Name -eq "MyInvocation"
    } -ModuleName ModuleBuilder {
        @{
            MyCommand = @{
                Parameters = @{
                    Encoding          = @{ParameterType = "string"}
                    Target            = @{ParameterType = "string"}
                    SourcePath        = @{ParameterType = "string"}
                    SourceDirectories = @{ParameterType = "string[]"}
                    OutputDirectory   = @{ParameterType = "string"}
                }
            }
        }
    }
    Mock Get-Item -ModuleName ModuleBuilder {
        "TestDrive:\MyModule\Source\MyModule.psd1"
    }
    Mock Get-Module -ModuleName ModuleBuilder {
        [PSCustomObject]@{
            ModuleBase = Convert-FolderSeparator "TestDrive:\Source\"
            Author = "Test Manager"
            Version = [Version]"1.0.0"
            Name = "MyModule"
            RootModule = "MyModule.psm1"
        }
    }

    Context "It collects the initial data" {

        New-Item "TestDrive:\MyModule\Source\build.psd1" -Type File -Force
        New-Item "TestDrive:\MyModule\Source\MyModule.psd1" -Type File -Force

        Push-Location TestDrive:\MyModule\Source\
        $Result = InModuleScope -ModuleName ModuleBuilder {
            [CmdletBinding()]
            param( $SourceDirectories = @("Enum", "Classes", "Private", "Public"), $OutputDirectory = "..\Output")
            InitializeBuild -SourcePath 'TestDrive:\MyModule\Source\'
        }
        Pop-Location

        It "Calls ResolveBuildManifest with the TestDrive path" {
            Assert-MockCalled ResolveBuildManifest -ModuleName ModuleBuilder -ParameterFilter {
                (Convert-FolderSeparator $SourcePath) -eq (Convert-FolderSeparator "TestDrive:\Source\")
            }
        }

        It "Calls GetBuildInfo with the resolved Path" {
            Assert-MockCalled GetBuildInfo -ModuleName ModuleBuilder -ParameterFilter {
                (Convert-FolderSeparator $SourcePath) -eq (Convert-FolderSeparator "TestDrive:\Source\build.psd1")
            }
        }

        It "Calls Get-Module with a qualified path to the manifest" {
            Assert-MockCalled Get-Module -ModuleName ModuleBuilder -ParameterFilter {
                (Convert-FolderSeparator $Name) -eq (Convert-FolderSeparator "TestDrive:\Source\MyModule.psd1")
            }
        }

        It "Returns the ModuleInfo combined with an OutputDirectory and Path" {
            $Result.ModuleBase | Should -be (Convert-FolderSeparator "TestDrive:\Source\")
            $Result.Path | Should -be (Convert-FolderSeparator "TestDrive:\Source\MyModule.psd1")

            Push-Location TestDrive:\
            New-Item $Result.OutputDirectory -ItemType Directory -Force | Resolve-Path -Relative | Should -be ".\Output"
            Pop-Location
            $Result.SourceDirectories | Should -be @("Classes", "Public")
        }
    }

    Context "Invalid module manifest" {
        # In the current PowerShell 5.1 and 6.1
        # I can't make Get-Module -ListAvailable throw on a manifest
        # So I can't test the if($Problems = ... code
    }

    Context "Build with specified relative output path" {
        New-Item "TestDrive:\Source\" -Type Directory

        Mock Get-Variable -ModuleName ModuleBuilder {
            if($Name -eq "OutputDirectory" -and $ValueOnly) {
                ".\Output"
            }
        }

        Mock Get-Variable -ParameterFilter {
            $Name -eq "MyInvocation" -and $ValueOnly
        } -ModuleName ModuleBuilder {
            @{
                MyCommand = @{
                    Parameters = @{
                        Encoding = @{ParameterType = "string"}
                        Target = @{ParameterType = "string"}
                        SourcePath = @{ParameterType = "string"}
                        SourceDirectories = @{ParameterType = "string[]"}
                        OutputDirectory = @{ParameterType = "string"}
                    }
                }
            }
        }

        $Result = InModuleScope -ModuleName ModuleBuilder {
            [CmdletBinding()]
            param( $SourceDirectories = @("Enum", "Classes", "Private", "Public"), $OutputDirectory = "..\Output")

            InitializeBuild -SourcePath TestDrive:\Source\
        }

        It "Treats the output path as relative to the (parent of the) ModuleSource" {
            $Result.ModuleBase | Should -be "TestDrive:\Source\"
            $Result.Path | Should -be "TestDrive:\Source\MyModule.psd1"
            # Note that Build-Module will call ResolveOutputFolder with this, so the relative path here is ok
            Push-Location TestDrive:\
            New-Item $Result.OutputDirectory -ItemType Directory -Force | Resolve-Path -Relative | Should -be ".\Source\Output"
            Pop-Location
        }
    }




    Context "Does not fall over if you build from the drive root" {
        Mock Get-Variable -ModuleName ModuleBuilder {
            if($Name -eq "OutputDirectory" -and $ValueOnly) {
                ".\Output"
            }
        }

        Mock ResolveModuleManifest -ModuleName ModuleBuilder { "TestDrive:\MyModule.psd1" }

        Mock Get-Variable -ParameterFilter {
            $Name -eq "MyInvocation" -and $ValueOnly
        } -ModuleName ModuleBuilder {
            @{
                MyCommand = @{
                    Parameters = @{
                        Encoding = @{ParameterType = "string"}
                        Target = @{ParameterType = "string"}
                        SourcePath = @{ParameterType = "string"}
                        SourceDirectories = @{ParameterType = "string[]"}
                        OutputDirectory = @{ParameterType = "string"}
                    }
                }
            }
        }

        Mock Get-Module -ModuleName ModuleBuilder {
            [PSCustomObject]@{
                ModuleBase = "TestDrive:\"
                Author = "Test Manager"
                Version = [Version]"1.0.0"
                Name = "MyModule"
                RootModule = "MyModule.psm1"
            }
        }
        $Result = InModuleScope -ModuleName ModuleBuilder {
            [CmdletBinding()]
            param( $SourceDirectories = @("Enum", "Classes", "Private", "Public"), $OutputDirectory = "..\Output")

            InitializeBuild -SourcePath TestDrive:\
        }

        It "Treats the output path as relative to the (parent of the) ModuleSource" {
            $Result.ModuleBase | Should -be "TestDrive:\"
            $Result.Path | Should -be "TestDrive:\MyModule.psd1"
            # Note that Build-Module will call ResolveOutputFolder with this, so the relative path here is ok
            Push-Location TestDrive:\
            New-Item $Result.OutputDirectory -ItemType Directory -Force | Resolve-Path -Relative | Should -be ".\Output"
            Pop-Location
        }
    }
}
