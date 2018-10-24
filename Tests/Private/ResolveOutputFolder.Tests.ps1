Describe "ResolveOutputFolder" {
    Import-Module ModuleBuilder -DisableNameChecking -Verbose:$False

    Context "Given an OutputDirectory only" {

        $Result = InModuleScope -ModuleName ModuleBuilder {
            ResolveOutputFolder -OutputDirectory TestDrive:\Output
        }

        It "Creates the Output directory" {
            $Result | Should -Be "TestDrive:\Output"
            $Result | Should -Exist
        }
    }

    Context "Given an OutputDirectory and ModuleVersion but no switch" {

        $Result = InModuleScope -ModuleName ModuleBuilder {
            ResolveOutputFolder -OutputDirectory TestDrive:\Output -ModuleVersion "1.0.0"
        }

        It "Creates the Output directory" {
            "TestDrive:\Output" | Should -Exist
        }

        It "Returns the Output directory" {
            $Result | Should -Be "TestDrive:\Output"
        }

        It "Does not creates children in Output" {
            Get-ChildItem $Result | Should -BeNullOrEmpty
        }
    }

    Context "Given an OutputDirectory, ModuleVersion and switch" {

        $Result = InModuleScope -ModuleName ModuleBuilder {
            ResolveOutputFolder -OutputDirectory TestDrive:\Output -ModuleVersion "1.0.0" -VersionedOutput
        }

        It "Creates the Output directory" {
            "TestDrive:\Output" | Should -Exist
        }

        It "Creates the version directory" {
            "TestDrive:\Output\1.0.0" | Should -Exist
        }

        It "Returns the Output directory" {
            $Result | Should -Be "TestDrive:\Output\1.0.0"
        }
    }
}
