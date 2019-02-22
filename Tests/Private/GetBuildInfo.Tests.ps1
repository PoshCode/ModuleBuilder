Describe "GetModuleInfo" {
    Import-Module ModuleBuilder
    Mock Push-Location -ModuleName ModuleBuilder {}
    Mock Import-Metadata -ModuleName ModuleBuilder {
        @{
            #Omitting path to let it resolve [Path = "MyModule.psd1"]
            SourceDirectories = "Classes", "Public"
        }
    }
    Mock Get-Variable -ParameterFilter {
        $Name -eq "Invocation"
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
            BoundParameters = @{
                OutputDirectory = '..\output'
            }
        }
    }

    Context "It collects the initial data" {


        New-Item "TestDrive:\MyModule\Source\Build.psd1" -Type File -Force
        New-Item "TestDrive:\MyModule\Source\MyModule.psd1" -Type File -Force

        push-location -stackname test TestDrive:\MyModule\Source
        $Result = InModuleScope -ModuleName ModuleBuilder {

            # Used to resolve the overridden parameters in $Invocation
            $OutputDirectory = '..\output'

            GetBuildInfo -BuildManifest TestDrive:\MyModule\Source\Build.psd1
        }
        Pop-location -stackname test

        It "Pushes the module source path" {
            Assert-MockCalled Push-Location -ModuleName ModuleBuilder -ParameterFilter {
                $StackName -eq "Build-Module" -and $Path -eq "TestDrive:\MyModule\Source"
            }
        }

        It "Parses the build.psd1" {
            Assert-MockCalled Import-Metadata -ModuleName ModuleBuilder -ParameterFilter {
                $Path -eq "TestDrive:\MyModule\Source\build.psd1"
            }
        }

        It "Attempts to load the `$Invocation object from calling scope" {
            Assert-MockCalled -CommandName Get-Variable -ParameterFilter { $Name -eq "Invocation" } -ModuleName ModuleBuilder
        }

        It "Returns the resolved Module path, SourceDirectories, and overridden OutputDirectory (via Invocation param)" {
            $Result.Path | Should -be "TestDrive:\MyModule\Source\MyModule.psd1" # if set in build.psd1 it will stay the same (i.e. relative)
            $Result.SourceDirectories | Should -be @("Classes", "Public")
            $Result.OutputDirectory | Should -be '..\Output'
        }
    }

    Context 'Error when calling GetBuildInfo the wrong way' {
        It 'Should throw if the ModuleManifestPath does not exist' {
            {InModuleScope -ModuleName ModuleBuilder {
                GetBuildInfo -BuildManifest TestDrive:\NOTEXIST\Source\Build.psd1
            }} | Should -Throw
        }

        It 'Should throw if the Build Manifest does not point to a build.psd1 file' {
            {InModuleScope -ModuleName ModuleBuilder {
                GetBuildInfo -BuildManifest TestDrive:\NOTEXIST\Source\ERROR.psd1
            }} | Should -Throw
        }

        It 'Should throw if the Module manifest does not exists' {
            New-Item -Force TestDrive:\NoModuleManifest\Source\Build.psd1 -ItemType File
            {InModuleScope -ModuleName ModuleBuilder {
                    GetBuildInfo -BuildManifest TestDrive:\NoModuleManifest\Source\Build.psd1
                }} | Should -Throw
        }
    }

    Context "Invalid module manifest" {
        # In the current PowerShell 5.1 and 6.1
        # I can't make Get-Module -ListAvailable throw on a manifest
        # So I can't test the if($Problems = ... code
    }

}