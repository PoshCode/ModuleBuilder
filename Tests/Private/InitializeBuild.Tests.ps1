Describe "InitializeBuild" {
    . $PSScriptRoot\..\Convert-FolderSeparator.ps1

    Mock ResolveModuleSource -ModuleName ModuleBuilder { $SourcePath }
    Mock ResolveModuleManifest -ModuleName ModuleBuilder {
        Convert-FolderSeparator "TestDrive:\Source\MyModule.psd1"
    }
    Mock Push-Location -ModuleName ModuleBuilder {}
    Mock Import-Metadata -ModuleName ModuleBuilder {
    Mock ResolveBuildManifest -ModuleName ModuleBuilder {
        Convert-FolderSeparator"TestDrive:\Source\build.psd1"
    }
    Mock GetBuildInfo -ModuleName ModuleBuilder {
        @{
            ModuleManifest  = Convert-FolderSeparator 'TestDrive:\MyModule\Source\MyModule.psd1'
            OutputDirectory = '../output'
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


        $Result = InModuleScope -ModuleName ModuleBuilder {
            [CmdletBinding()]
            param( $SourceDirectories = @("Enum", "Classes", "Private", "Public"), $OutputDirectory = "..\Output")
            InitializeBuild -SourcePath 'TestDrive:\MyModule\Source\'
        }


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

        It "Returns the ModuleInfo combined with an OutputDirectory and ModuleManifest Path" {
            $Result.ModuleBase | Should -be (Convert-FolderSeparator "TestDrive:\Source\")
            $Result.ModuleManifest | Should -be (Convert-FolderSeparator "TestDrive:\Source\MyModule.psd1")
            Push-Location TestDrive:\
            New-Item $Result.OutputDirectory -ItemType Directory -Force | Resolve-Path -Relative | Should -be ".\Output"
            Pop-Location
            $Result.SourceDirectories | Should -be @("Classes", "Public")
        }
    }

}
