Describe "ResolveBuildManifest" {
    Import-Module ModuleBuilder -DisableNameChecking -Verbose:$False

    [string]${Global:Test Root Path} = Resolve-Path $PSScriptRoot\..\..\Source

    It "Should return the Build.psd1 path when passed the Build.psd1 path" {
        $Expected = InModuleScope ModuleBuilder { ResolveBuildManifest "${Global:Test Root Path}\Build.psd1" }
        $Expected | Should -Be "${Global:Test Root Path}\Build.psd1"
    }

    It "Should return the Build.psd1 path when passed the module manifest path" {
        $Expected = InModuleScope ModuleBuilder { ResolveBuildManifest (Join-Path ${Global:Test Root Path} 'ModuleBuilder.psd1') }
        $Expected | Should -Be "${Global:Test Root Path}\build.psd1"
    }

    It "Should return the Build.psd1 path when passed the source module folder" {
        $Expected = InModuleScope ModuleBuilder { ResolveBuildManifest ${Global:Test Root Path} }
        $Expected | Should -Be "${Global:Test Root Path}\build.psd1"
    }

    It "Should return the Build.psd1 path when passed the relative path of the source folder" {
        Push-Location $PSScriptRoot -StackName TestRelativePath
        $Expected = InModuleScope ModuleBuilder { ResolveBuildManifest "..\..\Source" }
        Pop-Location -StackName TestRelativePath
        $Expected | Should -Be "${Global:Test Root Path}\build.psd1"
    }

    It "Should throw when passed a wrong absolute module manifest" {
        {InModuleScope ModuleBuilder { ResolveBuildManifest ${Global:Test Root Path}\ERROR\ModuleBuilder.psd1 }} | Should -Throw
    }

    It "Should throw when passed the wrong folder path" {
        {InModuleScope ModuleBuilder { ResolveBuildManifest "${Global:Test Root Path}\.." }} | Should -Throw
    }

    It "Should throw when passed the wrong folder relative path" {
        {InModuleScope ModuleBuilder { ResolveBuildManifest ".\.." }} | Should -Throw
    }

}