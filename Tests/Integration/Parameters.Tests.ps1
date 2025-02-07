#requires -Module ModuleBuilder

Describe "Parameters.Set in build manifest" -Tag Integration {
    BeforeAll {
        . $PSScriptRoot/../Convert-FolderSeparator.ps1
        New-Item $PSScriptRoot/Result3/Parameters/ReadMe.md -ItemType File -Force
    }

    It "Passthru is read from the build manifest" {
        $Output = Build-Module (Convert-FolderSeparator "$PSScriptRoot/Parameters/build.psd1") -Verbose
        $Output | Should -Not -BeNullOrEmpty
        $Output.Path | Convert-FolderSeparator | Should -Be (Convert-FolderSeparator "$PSScriptRoot/Result3/Parameters/3.0.0/Parameters.psd1")
    }

    It "The Target is Build" {
        Convert-FolderSeparator "$PSScriptRoot/Result3/Parameters/3.0.0/Parameters.psm1" | Should -Exist
    }

    It "The version is set" {
        $Metadata = Import-Metadata "$PSScriptRoot/Result3/Parameters/3.0.0/Parameters.psd1"
        $Metadata.ModuleVersion | Should -Be "3.0.0"
    }

    It "The PreRelease is set" {
        $Metadata = Import-Metadata "$PSScriptRoot/Result3/Parameters/3.0.0/Parameters.psd1"
        $Metadata.PrivateData.PSData.Prerelease | Should -Be 'alpha001'
    }
}
