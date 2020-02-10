#requires -Module ModuleBuilder
Describe "GetBuildInfo" {
    . $PSScriptRoot\..\Convert-FolderSeparator.ps1

    Mock Import-Metadata -ModuleName ModuleBuilder {
        @{
            #Omitting path to let it resolve [Path = "MyModule.psd1"]
            SourceDirectories = "Classes", "Public"
        }
    }

    Context "It collects the initial data" {

        # use -Force to create the subdirectories
        New-Item -Force "TestDrive:\MyModule\Source\build.psd1" -Type File -Value "@{ Path = 'MyModule.psd1' }"
        New-ModuleManifest "TestDrive:\MyModule\Source\MyModule.psd1" -Author Tester

        $Result = InModuleScope -ModuleName ModuleBuilder {

            # Used to resolve the overridden parameters in $Invocation
            $OutputDirectory = '..\ridiculoustestvalue'

            GetBuildInfo -BuildManifest TestDrive:\MyModule\Source\build.psd1 -BuildCommandInvocation @{
                MyCommand   = @{
                    Parameters = @{
                        Encoding          = @{ParameterType = "string" }
                        Target            = @{ParameterType = "string" }
                        SourcePath        = @{ParameterType = "string" }
                        SourceDirectories = @{ParameterType = "string[]" }
                        OutputDirectory   = @{ParameterType = "string" }
                    }
                }
                BoundParameters = @{
                    OutputDirectory = '..\ridiculoustestvalue'
                }
            }
        }

        It "Parses the build.psd1" {
            Assert-MockCalled Import-Metadata -ModuleName ModuleBuilder -ParameterFilter {
                (Convert-FolderSeparator $Path) -eq (Convert-FolderSeparator "TestDrive:\MyModule\Source\build.psd1")
            }
        }

        It "Reads bound parameters from the BuildCommandInvocation" {
            $Result.OutputDirectory |Should -Be "..\ridiculoustestvalue"
        }

        It "Returns the resolved Module path, SourceDirectories, and overridden OutputDirectory (via Invocation param)" {
            # if set in build.psd1 it will stay the same (i.e. relative)
            (Convert-FolderSeparator $Result.SourcePath) |
                Should -Be (Convert-FolderSeparator "TestDrive:\MyModule\Source\MyModule.psd1")

            $Result.SourceDirectories | Should -Be @("Classes", "Public")
            $Result.OutputDirectory | Should -Be '..\ridiculoustestvalue'
        }
    }

    Context 'Error when calling GetBuildInfo the wrong way' {
        It 'Should throw if the SourcePath does not exist' {
            {InModuleScope -ModuleName ModuleBuilder {
                GetBuildInfo -BuildManifest TestDrive:\NOTEXIST\Source\build.psd1
            }} | Should -Throw
        }

        It 'Should throw if the Build Manifest does not point to a build.psd1 file' {
            {InModuleScope -ModuleName ModuleBuilder {
                GetBuildInfo -BuildManifest TestDrive:\NOTEXIST\Source\ERROR.psd1
            }} | Should -Throw
        }

        It 'Should throw if the Module manifest does not exist' {
            # use -Force to create the subdirectories
            New-Item -Force TestDrive:\NoModuleManifest\Source\build.psd1 -ItemType File
            {InModuleScope -ModuleName ModuleBuilder {
                    GetBuildInfo -BuildManifest TestDrive:\NoModuleManifest\Source\build.psd1
            }} | Should -Throw
        }
    }
}
