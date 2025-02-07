#requires -Module ModuleBuilder

Describe "Parameters.Set in build manifest" -Tag Integration {
    BeforeAll {
        . $PSScriptRoot/../Convert-FolderSeparator.ps1
        New-Item $PSScriptRoot/Result3/Parameters/ReadMe.md -ItemType File -Force

        $Output = Build-Module $PSScriptRoot/Parameters/build.psd1
        if ($Output) {
            $Module = [IO.Path]::ChangeExtension($Output.Path, "psm1")
            $Metadata = Import-Metadata $Output.Path
        }

    }

    It "Passthru works" {
        $Output | Should -Not -BeNullOrEmpty
    }

    It "The Target is Build" {
        "$PSScriptRoot/Result3/Parameters/ReadMe.md" | Should -Exist
    }

    It "The version is set" {
        $Metadata.ModuleVersion | Should -Be "3.0.0"
    }

    It "The PreRelease is set" {
        $Metadata.PrivateData.PSData.Prerelease | Should -Be 'alpha001'
    }
}
