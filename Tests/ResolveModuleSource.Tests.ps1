Describe "ResolveModuleSource" {
    Import-Module ModuleBuilder -DisableNameChecking -Verbose:$False

    [string]${Global:Test Root Path} = Resolve-Path $PSScriptRoot\..\Source

    It "Should return the folder name when passed a module folder" {
        $Expected = InModuleScope ModuleBuilder { ResolveModuleSource ${Global:Test Root Path} }
        $Expected | Should -Be ${Global:Test Root Path}
    }

    It "Should return the base folder name when passed a 'Source' folder" {
        $Expected = InModuleScope ModuleBuilder { ResolveModuleSource ${Global:Test Root Path} }
        $Expected | Should -Be ${Global:Test Root Path}
    }

    It "Should return the folder name when passed a module manifest" {
        $Expected = InModuleScope ModuleBuilder { ResolveModuleSource ${Global:Test Root Path}\ModuleBuilder.psd1 }
        $Expected | Should -Be ${Global:Test Root Path}
    }

    It "Should return the folder name when passed a build manifest" {
        $Expected = InModuleScope ModuleBuilder { ResolveModuleSource ${Global:Test Root Path}\build.psd1 }
        $Expected | Should -Be ${Global:Test Root Path}
    }

    It "Should return the PWD when called without parameters" {
        Push-Location ${Global:Test Root Path}
        $Expected = InModuleScope ModuleBuilder { ResolveModuleSource }
        $Expected | Should -Be "$Pwd"
        Pop-Location
    }
<#
    It "Should return the manifest name when passed a module manifest" {
        $Expected, $Name = ResolveModuleSource ${Global:Test Root Path}\ModuleBuilder.psd1
        $Name | Should -Be "ModuleBuilder"
    }

    It "Should return the manifest name when passed a build manifest" {
        $Expected, $Name = ResolveModuleSource ${Global:Test Root Path}\build.psd1
        $Name | Should -Be "ModuleBuilder"
    }

    It "Should return the manifest name when passed a module folder" {
        $Expected, $Name = ResolveModuleSource ${Global:Test Root Path}
        $Name | Should -Be "ModuleBuilder"
    }
#>

}