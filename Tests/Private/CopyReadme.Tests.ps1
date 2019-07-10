Describe "Copy ReadMe" {
    Import-Module ModuleBuilder -DisableNameChecking -Verbose:$False

    Context "There's no ReadMe" {
        # It should not even call Test-Path
        It "Does nothing if no ReadMe is passed" {
            Mock Test-Path -ModuleName ModuleBuilder

            InModuleScope ModuleBuilder {
                Get-Module ModuleBuilder | CopyReadme -OutputDirectory TestDrive:\
            }

            Assert-MockCalled Test-Path -Times 0 -ModuleName ModuleBuilder
        }

        # It's possible it should warn in this case?
        It "Does nothing if ReadMe doesn't exist" {
            Mock Test-Path -ModuleName ModuleBuilder
            Mock Join-Path -ModuleName ModuleBuilder

            InModuleScope ModuleBuilder {
                Get-Module ModuleBuilder | CopyReadme -Readme ReadMe.md -OutputDirectory TestDrive:\
            }

            # Test-Path is only called once -- means it didn't check for the folder
            Assert-MockCalled Test-Path -Times 1 -ModuleName ModuleBuilder
            Assert-MockCalled Join-Path -Times 0 -ModuleName ModuleBuilder
        }
    }

    Context "There is a ReadMe" {
        # Nothing is actually created when this test runs
        Mock New-Item -ModuleName ModuleBuilder
        Mock Copy-Item -ModuleName ModuleBuilder

        # Test-Path returns true only for the source document
        ${global:Test Script Path} = Join-Path $PSScriptRoot CopyReadme.Tests.ps1
        Mock Test-Path { $Path -eq ${global:Test Script Path} } -ModuleName ModuleBuilder

        Remove-Item TestDrive:\En -Recurse -Force -ErrorAction SilentlyContinue

        InModuleScope ModuleBuilder {
            CopyReadme -ReadMe ${global:Test Script Path} -Module ModuleBuilder -OutputDirectory TestDrive:\ -Culture "En"
        }

        Remove-Item TestDrive:\En -Recurse -Force -ErrorAction SilentlyContinue

        It "Creates a language path in the output" {
            Assert-MockCalled New-Item -ModuleName ModuleBuilder -ParameterFilter {
                $Path -eq "TestDrive:\En"
            }
        }

        It "Copies the readme as about_module.help.txt" {
            Assert-MockCalled Copy-Item -ModuleName ModuleBuilder -ParameterFilter {
                $Destination -eq "TestDrive:\En\about_ModuleBuilder.help.txt"
            }
        }
    }
}
