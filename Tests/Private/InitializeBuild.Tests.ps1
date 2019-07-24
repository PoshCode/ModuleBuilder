Describe "InitializeBuild" {
    . $PSScriptRoot\..\Convert-FolderSeparator.ps1
    Import-Module ModuleBuilder -DisableNameChecking -Verbose:$False

    Mock Push-Location -ModuleName ModuleBuilder {}
    Mock ResolveBuildManifest -ModuleName ModuleBuilder {
        Convert-FolderSeparator "TestDrive:\Source\build.psd1"
    }
    Mock GetBuildInfo -ModuleName ModuleBuilder {
        @{
            ModuleManifest  = Convert-FolderSeparator 'TestDrive:\Source\MyModule.psd1'
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

    # Mock Get-Module -ModuleName ModuleBuilder {
    #     [PSCustomObject]@{
    #         ModuleBase = Convert-FolderSeparator "TestDrive:\Source\"
    #         Author = "Test Manager"
    #         Version = [Version]"1.0.0"
    #         Name = "MyModule"
    #         RootModule = "MyModule.psm1"
    #     }
    # }

    Context "It collects the initial data" {

        New-Item "TestDrive:\Source\build.psd1" -Type File -Force
        New-Item "TestDrive:\Source\MyModule.psd1" -Type File -Force

        Set-Content "TestDrive:\Source\MyModule.psd1" '@{
            RootModule = "MyModule.psm1"
            Author     = "Test Manager"
            Version    = "1.0.0"
        }'


        $Result = InModuleScope -ModuleName ModuleBuilder {
            [CmdletBinding()]
            param( $SourceDirectories = @("Enum", "Classes", "Private", "Public"), $OutputDirectory = "..\Output")
            InitializeBuild -SourcePath 'TestDrive:\Source\'
        }


        It "Calls ResolveBuildManifest with the TestDrive path" {
            Assert-MockCalled ResolveBuildManifest -ModuleName ModuleBuilder -ParameterFilter {
                (Convert-FolderSeparator $SourcePath) -eq (Convert-FolderSeparator "TestDrive:\Source\")
            }
        }

        It "Calls GetBuildInfo with the resolved Path" {
            Assert-MockCalled GetBuildInfo -ModuleName ModuleBuilder -ParameterFilter {
                (Convert-FolderSeparator $BuildManifest) -eq (Convert-FolderSeparator "TestDrive:\Source\build.psd1")
            }
        }

        It "Returns the ModuleInfo combined with the BuildInfo" {
            $Result.ModuleBase | Should -Be (Convert-FolderSeparator "TestDrive:\Source")
            $Result.ModuleManifest | Should -Be (Convert-FolderSeparator "TestDrive:\Source\MyModule.psd1")
            Push-Location TestDrive:\
            New-Item $Result.OutputDirectory -ItemType Directory -Force | Resolve-Path -Relative | Should -Be ".\Output"
            Pop-Location
        }
    }
}
