#requires -Module ModuleBuilder
Describe "Copy ReadMe" {
    BeforeAll {
        . $PSScriptRoot\..\Convert-FolderSeparator.ps1
    }

    Context "There's no ReadMe" {
        # It should not even call Test-Path
        It "Does nothing if no ReadMe is passed" {
            Mock Test-Path -ModuleName ModuleBuilder

            InModuleScope ModuleBuilder {
                Get-Module ModuleBuilder | CopyReadMe -OutputDirectory TestDrive:\
            }

            Assert-MockCalled Test-Path -Times 0 -ModuleName ModuleBuilder
        }

        # It's possible it should warn in this case?
        It "Does nothing if ReadMe doesn't exist" {
            Mock Test-Path -ModuleName ModuleBuilder
            Mock Join-Path -ModuleName ModuleBuilder

            InModuleScope ModuleBuilder {
                Get-Module ModuleBuilder | CopyReadMe -Readme ReadMe.md -OutputDirectory TestDrive:\
            }

            # Test-Path is only called once -- means it didn't check for the folder
            Assert-MockCalled Test-Path -Times 1 -ModuleName ModuleBuilder
            Assert-MockCalled Join-Path -Times 0 -ModuleName ModuleBuilder
        }
    }

    Context "There is a ReadMe" {
        BeforeAll {
            # Nothing is actually created when this test runs
            Mock New-Item -ModuleName ModuleBuilder
            Mock Copy-Item -ModuleName ModuleBuilder

            # Test-Path returns true only for the source document
            ${global:Test Script Path} = Join-Path $PSScriptRoot CopyReadMe.Tests.ps1
            Mock Test-Path { $Path -eq ${global:Test Script Path} } -ModuleName ModuleBuilder

            Remove-Item TestDrive:\En -Recurse -Force -ErrorAction SilentlyContinue

            InModuleScope ModuleBuilder {
                CopyReadMe -ReadMe ${global:Test Script Path} -Module ModuleBuilder -OutputDirectory TestDrive:\ -Culture "En"
            }
        }

        It "Creates a language path in the output" {
            Assert-MockCalled New-Item -ModuleName ModuleBuilder -ParameterFilter {
                (Convert-FolderSeparator "$Path") -eq (Convert-FolderSeparator "TestDrive:\En")
            } -Scope Context
        }

        It "Copies the readme as about_module.help.txt" {
            Assert-MockCalled Copy-Item -ModuleName ModuleBuilder -ParameterFilter {
                (Convert-FolderSeparator $Destination) -eq (Convert-FolderSeparator "TestDrive:\En\about_ModuleBuilder.help.txt")
            } -Scope Context
        }

        AfterAll {
            Remove-Item TestDrive:\En -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
