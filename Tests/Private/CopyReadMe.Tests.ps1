Describe "Copy ReadMe" {
    BeforeAll {
        . $PSScriptRoot\..\Convert-FolderSeparator.ps1
        $PSDefaultParameterValues = @{
            "Mock:ModuleName"              = "ModuleBuilder"
            "Assert-MockCalled:ModuleName" = "ModuleBuilder"
        }
    }

    Context "There's no ReadMe" {
        # It should not even call Test-Path
        It "Does nothing if no ReadMe is passed" {
            Mock Test-Path

            InModuleScope ModuleBuilder {
                Get-Module ModuleBuilder | CopyReadMe -OutputDirectory TestDrive:\
            }

            Assert-MockCalled Test-Path -Times 0
        }

        # It's possible it should warn in this case?
        It "Does nothing if ReadMe doesn't exist" {
            Mock Test-Path
            Mock Join-Path

            InModuleScope ModuleBuilder {
                Get-Module ModuleBuilder | CopyReadMe -Readme ReadMe.md -OutputDirectory TestDrive:\
            }

            # Test-Path is only called once -- means it didn't check for the folder
            Assert-MockCalled Test-Path -Times 1
            Assert-MockCalled Join-Path -Times 0
        }
    }

    Context "There is a ReadMe" {
        BeforeAll {
            # Test-Path returns true only for the source document
            ${global:Test Script Path} = Join-Path $PSScriptRoot CopyReadMe.Tests.ps1

            Remove-Item "$TestDrive/en" -Recurse -Force -ErrorAction SilentlyContinue

            InModuleScope ModuleBuilder {
                CopyReadMe -ReadMe ${global:Test Script Path} -Module ModuleBuilder -OutputDirectory $TestDrive -Culture "en"
            }
        }

        It "Creates a language path in the output" {
            "$TestDrive/en" | Should -Exist
        }

        It "Copies the readme as about_module.help.txt" {
            "$TestDrive/en/about_ModuleBuilder.help.txt" | Should -Exist
        }
        AfterAll {
            Remove-Item "$TestDrive/en" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
