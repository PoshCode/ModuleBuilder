Describe "ResolveModuleManifest" {
    Import-Module ModuleBuilder -DisableNameChecking -Verbose:$False

    [string]${Global:Test Root Path} = Resolve-Path $PSScriptRoot/../../Source

    It "Should return the module manifest path when passed just a module folder" {
        $Expected = InModuleScope ModuleBuilder { ResolveModuleManifest ${Global:Test Root Path} }
        $Expected | Should -Be (Join-Path ${Global:Test Root Path} ModuleBuilder.psd1)
    }

    It "Should return the module manifest path when passed a module folder and null" {
        $Expected = InModuleScope ModuleBuilder { ResolveModuleManifest ${Global:Test Root Path} $null }
        $Expected | Should -Be (Join-Path ${Global:Test Root Path} ModuleBuilder.psd1)
    }

    It "Should return the module manifest path when passed a relative module manifest" {
        $Expected = InModuleScope ModuleBuilder { ResolveModuleManifest ${Global:Test Root Path} ModuleBuilder.psd1 }
        $Expected | Should -Be (Join-Path ${Global:Test Root Path} ModuleBuilder.psd1)
    }

    It "Should return the module manifest path when passed an absolute module manifest" {
        $Expected = InModuleScope ModuleBuilder { ResolveModuleManifest ${Global:Test Root Path} ${Global:Test Root Path}/ModuleBuilder.psd1 }
        $Expected | Should -Be (Join-Path ${Global:Test Root Path} ModuleBuilder.psd1)
    }

}
