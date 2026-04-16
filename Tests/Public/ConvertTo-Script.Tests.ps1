Describe "ConvertTo-Script" {
    Context "Example 1. Extracting a function from a module" {
        BeforeAll {
            $ModuleBuilder = Get-Module ModuleBuilder | Select-Object -First 1
            $ModuleBuilder.Path | Should -Exist

            $BuildModuleCommand = Get-Command Build-Module
            $BuildModuleCommand | Should -Not -BeNullOrEmpty

            $ScriptFile = $ModuleBuilder.Path | Split-Path | Join-Path -ChildPath "Build-Module.ps1"
            $ScriptFile | Should -Not -Exist
        }
        AfterAll {
            Remove-Item $ScriptFile
        }

        It "Generates a script for the specified function" {
            $global:DebugPreference = "Continue"
            $null = Invoke-ScriptGenerator -Path $ModuleBuilder.Path -Generator "ConvertTo-Script" -Parameters @{ FunctionName = "Build-Module" }

            $global:DebugPreference = "SilentlyContinue"
            $ScriptFile | Should -Exist
            $ScriptFileCommand = Get-Command $ScriptFile
            $ScriptFileCommand.Parameters.Keys | Sort-Object | Should -Be ($BuildModuleCommand.Parameters.Keys | Sort-Object)
        }
    }
}
