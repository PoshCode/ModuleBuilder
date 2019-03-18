Describe "ResolveOutputFolder" {
    Import-Module ModuleBuilder -DisableNameChecking -Verbose:$False

    Context "Given an OutputDirectory and ModuleBase" {

        $Result = InModuleScope -ModuleName ModuleBuilder {
            ResolveOutputFolder -OutputDirectory TestDrive:\Output -ModuleBase TestDrive:\Source
        }

        It "Creates the Output directory" {
            $Result | Should -Be (Convert-Path "TestDrive:\Output")
            $Result | Should -Exist
        }
    }

    Context "Given an OutputDirectory, ModuleBase and ModuleVersion but no switch" {

        $Result = InModuleScope -ModuleName ModuleBuilder {
            ResolveOutputFolder -OutputDirectory TestDrive:\Output -ModuleVersion "1.0.0" -ModuleBase TestDrive:\Source
        }

        It "Creates the Output directory" {
            "TestDrive:\Output" | Should -Exist
        }

        It "Returns the Output directory" {
            $Result | Should -Be (Convert-Path "TestDrive:\Output")
        }

        It "Does not creates children in Output" {
            Get-ChildItem $Result | Should -BeNullOrEmpty
        }
    }

    Context "Given an OutputDirectory, ModuleBase, ModuleVersion and switch" {

        $Result = InModuleScope -ModuleName ModuleBuilder {
            ResolveOutputFolder -OutputDirectory TestDrive:\Output -ModuleVersion "1.0.0" -VersionedOutput -ModuleBase TestDrive:\Source
        }

        It "Creates the Output directory" {
            "TestDrive:\Output" | Should -Exist
        }

        It "Creates the version directory" {
            "TestDrive:\Output\1.0.0" | Should -Exist
        }

        It "Returns the Output directory" {
            $Result | Should -Be (Convert-Path "TestDrive:\Output\1.0.0")
        }
    }

    Context "Given a relative OutputDirectory, the Folder is created relative to ModuleBase" {


        $Result = InModuleScope -ModuleName ModuleBuilder {
            ResolveOutputFolder -OutputDirectory '..\Output' -ModuleBase TestDrive:\Source
        }

        It "Returns an absolute FileSystem path" {
            { [io.path]::IsPathRooted($Result) } | Should -Not -Throw
        }

        It "has created the Folder" {
            (Test-Path $Result) | Should -be $True
        }

    }
}
