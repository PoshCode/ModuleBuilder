#requires -Module ModuleBuilder

Describe "Build-Module With Source1" {
    Context "When we call Build-Module" {
        $Output = Build-Module $PSScriptRoot\Source1\build.psd1 -Passthru
        $Module = [IO.Path]::ChangeExtension($Output.Path, "psm1")

        It "Should not put the module's DefaultCommandPrefix into the psm1 as code. Duh!" {
            $Module | Should -Not -FileContentMatch '^Source$'
        }

        $Metadata = Import-Metadata $Output.Path

        It "Should update FunctionsToExport in the manifest" {
            $Metadata.FunctionsToExport | Should -Be @("Get-Source")
        }

        It "Should update AliasesToExport in the manifest" {
            $Metadata.AliasesToExport | Should -Be @("GS")
        }

        It "Should de-dupe and move using statements to the top of the file" {
            Select-String -Pattern "^using" -Path $Module | ForEach-Object LineNumber | Should -Be 1
        }

        It "Will comment out the original using statements in their original positions" {
            (Select-String -Pattern "^#\s*using" -Path $Module).Count | Should -Be 3
        }
    }

    Context "Regression test for #55: I can pass SourceDirectories" {
        $Output = Build-Module $PSScriptRoot\Source1\build.psd1 -SourceDirectories "Private" -Passthru
        $Module = [IO.Path]::ChangeExtension($Output.Path, "psm1")

        It "Should not put the module's DefaultCommandPrefix into the psm1 as code. Duh!" {
            $Module | Should -Not -FileContentMatch '^Source$'
        }

        $Metadata = Import-Metadata $Output.Path

        It "Should not have any FunctionsToExport if SourceDirectories don't match the PublicFilter" {
            $Metadata.FunctionsToExport | Should -Be @()
        }

        It "Should de-dupe and move using statements to the top of the file" {
            Select-String -Pattern "^using" -Path $Module | ForEach-Object LineNumber | Should -Be 1
        }

        It "Will comment out the original using statement in the original positions" {
            (Select-String -Pattern "^#\s*using" -Path $Module).Count | Should -Be 2
        }
    }

    Context "Regression test for #55: I can pass SourceDirectories and PublicFilter" {
        $Output = Build-Module $PSScriptRoot\Source1\build.psd1 -SourceDirectories "Private" -PublicFilter "P*\*" -Passthru
        $Module = [IO.Path]::ChangeExtension($Output.Path, "psm1")

        It "Should not put the module's DefaultCommandPrefix into the psm1 as code. Duh!" {
            $Module | Should -Not -FileContentMatch '^Source$'
        }

        $Metadata = Import-Metadata $Output.Path

        It "Should not have any FunctionsToExport if SourceDirectories don't match the PublicFilter" {
            $Metadata.FunctionsToExport | Should -Be @("GetFinale", "GetPreview")
        }

        It "Should update AliasesToExport in the manifest" {
            $Metadata.AliasesToExport | Should -Be @("GF", "GP")
        }

        It "Should de-dupe and move using statements to the top of the file" {
            Select-String -Pattern "^using" -Path $Module | ForEach-Object LineNumber | Should -Be 1
        }

        It "Will comment out the original using statement in the original positions" {
            (Select-String -Pattern "^#\s*using" -Path $Module).Count | Should -Be 2
        }
    }
}
