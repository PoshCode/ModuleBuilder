#requires -Module ModuleBuilder

Describe "Parameters" -Tag Integration {
    BeforeAll {
        . $PSScriptRoot/../Convert-FolderSeparator.ps1
        # Make sure the Result3 folder is really clean ;)
        if (Test-Path $PSScriptRoot/Result3) {
            Remove-Item $PSScriptRoot/Result3 -Recurse -Force
        }
        # Throw in an extra file that would get cleaned up normally ...
        New-Item $PSScriptRoot/Result3/Parameters/3.0.0/DeleteMe.md -ItemType File -Force

        Write-Host "Module Under Test:"
        Get-Command Build-Module
        | Get-Module -Name { $_.Source }
        | Get-Item
        | Out-Host
    }

    It "Passthru is read from the build manifest" {
        Build-Module (Convert-FolderSeparator "$PSScriptRoot/Parameters/build.psd1") -Verbose -OutVariable Output
        | Out-Host

        $Output | Should -Not -BeNullOrEmpty
        $Output.Path | Convert-FolderSeparator | Should -Be (Convert-FolderSeparator "$PSScriptRoot/Result3/Parameters/3.0.0/Parameters.psd1")
    }

    It "The target is 'Build' (not CleanBuild) so pre-created extra files get left behind" {
        Convert-FolderSeparator "$PSScriptRoot/Result3/Parameters/3.0.0/DeleteMe.md" | Should -Exist
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
