. $PSScriptRoot\..\Convert-FolderSeparator.ps1

Describe "Parameters.Set in build manifest" -Tag Integration {
    BeforeAll {
        # This file should not be deleted by the build, because VersionedOutput defaults true now
        # So the actual Build output will be ../Result3/Parameters/3.0.0
        New-Item $PSScriptRoot\Result3\Parameters\ReadMe.md -ItemType File -Force

        $Output = Build-Module $PSScriptRoot\Parameters\build.psd1
        if ($Output) {
            $Module = [IO.Path]::ChangeExtension($Output.Path, "psm1")
            $Metadata = Import-Metadata $Output.Path
        }
    }

    It "Passthru can be set from build.psd1" {
        $Output | Should -Not -BeNullOrEmpty
    }

    It "The version can be set from build.psd1" {
        $Metadata.ModuleVersion | Should -Be "3.0.0"
    }

    It "Files outside the Output should not be cleaned up or overwritten" {
        "$PSScriptRoot\Result3\Parameters\ReadMe.md" | Should -Exist
    }

    It "The PreRelease is set properly even when set from build.psd1" {
        $Metadata.PrivateData.PSData.Prerelease | Should -Be 'alpha001'
    }
}
