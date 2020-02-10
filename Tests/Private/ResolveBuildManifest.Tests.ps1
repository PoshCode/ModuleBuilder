#requires -Module ModuleBuilder
Describe "ResolveBuildManifest" {

    [string]${Global:Test Root Path} = Resolve-Path $PSScriptRoot\..\..\Source

    It "Should return the build.psd1 path when passed the build.psd1 path" {
        $Expected = InModuleScope ModuleBuilder { ResolveBuildManifest (Join-Path ${Global:Test Root Path} "build.psd1") }
        $Expected | Should -Be (Join-Path ${Global:Test Root Path} "build.psd1")
    }

    It "Should return the build.psd1 path when passed the module manifest path" {
        $Expected = InModuleScope ModuleBuilder { ResolveBuildManifest (Join-Path ${Global:Test Root Path} 'ModuleBuilder.psd1') }
        $Expected | Should -Be (Join-Path ${Global:Test Root Path} "build.psd1")
    }

    It "Should return the build.psd1 path when passed the source module folder" {
        $Expected = InModuleScope ModuleBuilder { ResolveBuildManifest ${Global:Test Root Path} }
        $Expected | Should -Be (Join-Path ${Global:Test Root Path} "build.psd1")
    }

    It "Should return the build.psd1 path when passed the relative path of the source folder" {
        Push-Location $PSScriptRoot -StackName TestRelativePath
        $Expected = InModuleScope ModuleBuilder { ResolveBuildManifest "..\..\Source" }
        Pop-Location -StackName TestRelativePath
        $Expected | Should -Be (Join-Path ${Global:Test Root Path} "build.psd1")
    }

    It "Returns nothing when passed a wrong absolute module manifest" {
        InModuleScope ModuleBuilder {
            ResolveBuildManifest (Join-Path (Join-Path ${Global:Test Root Path} ERROR) ModuleBuilder.psd1) | Should -BeNullOrEmpty
        }
    }

    It "Returns nothing when passed the wrong folder path" {
        InModuleScope ModuleBuilder {
            ResolveBuildManifest (Join-Path ${Global:Test Root Path} "..") | Should -BeNullOrEmpty
        }
    }

    It "Returns nothing when passed the wrong folder relative path" {
        InModuleScope ModuleBuilder {
            ResolveBuildManifest (Join-Path . ..) | Should -BeNullOrEmpty
        }
    }

}
