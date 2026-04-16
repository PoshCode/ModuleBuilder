#requires -Module ModuleBuilder
. $PSScriptRoot\..\Convert-FolderSeparator.ps1

Describe "When we use Generators" -Tag Integration {
    BeforeAll {
        $Output = Build-Module $PSScriptRoot\Source2\build.psd1 -Passthru
        $Module = [IO.Path]::ChangeExtension($Output.Path, "psm1")
        $Metadata = Import-Metadata $Output.Path
    }

}
