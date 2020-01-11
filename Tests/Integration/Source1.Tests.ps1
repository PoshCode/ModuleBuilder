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
            $Metadata.FunctionsToExport | Should -Be @("Get-Source", "Set-Source")
        }

        It "Should update AliasesToExport in the manifest" {
            $Metadata.AliasesToExport -match "GS" | Should -Not -BeNullOrEmpty
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

    Context "Regression test for #84: Multiple Aliases per command will Export" {
        $Output = Build-Module $PSScriptRoot\Source1\build.psd1 -Passthru

        $Metadata = Import-Metadata $Output.Path

        It "Should update AliasesToExport in the manifest" {
            $Metadata.AliasesToExport | Should -Be @("GS","GSou", "SS", "SSou")
        }
    }

    Context "Supports building without a build.psd1" {
        Copy-Item  $PSScriptRoot\Source1 $PSScriptRoot\Copy1 -Recurse
        Remove-Item $PSScriptRoot\Copy1\build.psd1
        Rename-Item $PSScriptRoot\Copy1\Source1.psd1 Copy1.psd1

        $Build = @{ }

        It "No longer fails if there's no build.psd1" {
            $BuildParameters = @{
                SourcePath               = "$PSScriptRoot\Copy1\Copy1.psd1"
                OutputDirectory          = "..\Result1"
                VersionedOutputDirectory = $true
            }

            $Build.Output = Build-Module @BuildParameters -Passthru
        }

        Remove-Item -Recurse $PSScriptRoot\Copy1


        It "Creates the same module as with a build.psd1" {
            $Build.Metadata = Import-Metadata $Build.Output.Path
        }

        It "Should update AliasesToExport in the manifest" {
            $Build.Metadata.AliasesToExport | Should -Be @("GS", "GSou", "SS", "SSou")
        }

        It "Should update FunctionsToExport in the manifest" {
            $Build.Metadata.FunctionsToExport | Should -Be @("Get-Source", "Set-Source")
        }

    }
}
