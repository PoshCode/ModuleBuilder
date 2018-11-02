Describe "InitializeBuild" {
    Mock ResolveModuleSource -ModuleName ModuleBuilder { $SourcePath }
    Mock ResolveModuleManifest -ModuleName ModuleBuilder { "TestDrive:\Source\MyModule.psd1" }
    Mock Push-Location -ModuleName ModuleBuilder {}
    Mock Import-Metadata -ModuleName ModuleBuilder {
        @{
            Path = "MyModule.psd1"
            SourceDirectories = "Classes", "Public"
        }
    }
    #Mock Update-Object -ModuleName ModuleBuilder { $InputObject }
    Mock Get-Variable -ParameterFilter {
        $Name -eq "MyInvocation"
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
            ModuleBase = "TestDrive:\Source\"
            Author = "Test Manager"
            Version = [Version]"1.0.0"
            Name = "MyModule"
            RootModule = "MyModule.psm1"
        }
    }

    Context "It collects the initial data" {

        New-Item "TestDrive:\Source\" -Type Directory

        $Result = InModuleScope -ModuleName ModuleBuilder {
            [CmdletBinding()]
            param( $SourceDirectories = @("Enum", "Classes", "Private", "Public"), $OutputDirectory = "..\Output")
            InitializeBuild -SourcePath TestDrive:\Source\
        }

        It "Resolves the module source path" {
            Assert-MockCalled ResolveModuleSource -ModuleName ModuleBuilder -ParameterFilter {
                $SourcePath -eq "TestDrive:\Source\"
            }
        }

        It "Pushes the module source path" {
            Assert-MockCalled Push-Location -ModuleName ModuleBuilder -ParameterFilter {
                $StackName -eq "Build-Module" -and $Path -eq "TestDrive:\Source\"
            }
        }

        It "Parses the build.psd1" {
            Assert-MockCalled Import-Metadata -ModuleName ModuleBuilder -ParameterFilter {
                $Path -eq "TestDrive:\Source\[Bb]uild.psd1"
            }
        }

        It "Calls Get-Module with a fully-qualified path to the manifest" {
            Assert-MockCalled Get-Module -ModuleName ModuleBuilder -ParameterFilter {
                $Name -eq "TestDrive:\Source\MyModule.psd1"
            }
        }

        It "Returns the ModuleInfo combined with an OutputDirectory and Path" {
            $Result.ModuleBase | Should -be "TestDrive:\Source\"
            $Result.Path | Should -be "TestDrive:\Source\MyModule.psd1"

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