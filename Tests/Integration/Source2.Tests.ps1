#requires -Module ModuleBuilder
. $PSScriptRoot\..\Convert-FolderSeparator.ps1

Describe "Using Generators" -Tag Integration {
    $Output = Build-Module $PSScriptRoot\Source2\build.psd1 -Passthru
    $Module = [IO.Path]::ChangeExtension($Output.Path, "psm1")

    $Metadata = Import-Metadata $Output.Path

    It "Still builds the right functions and updates the manifest" {
        $Metadata.FunctionsToExport | Should -Be @('Show-HistoryId', 'Show-HostName')
    }

}
