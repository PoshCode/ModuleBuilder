Describe "InitializeBuild" {
    Context "It collects the initial data" {
        Mock ResolveModuleSource -ModuleName ModuleBuilder { $SourcePath }
        Mock ResolveModuleManifest -ModuleName ModuleBuilder { "TestDrive:\Source\MyModule.psd1" }
        Mock Push-Location -ModuleName ModuleBuilder {}
        Mock Import-Metadata -ModuleName ModuleBuilder { @{Path = "MyModule.psd1"} }
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
        New-Item "TestDrive:\Source\" -Type Directory

        $Result = InModuleScope -ModuleName ModuleBuilder {
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
            $Result.OutputDirectory | Should -be "TestDrive:\1.0.0"
        }
    }
}