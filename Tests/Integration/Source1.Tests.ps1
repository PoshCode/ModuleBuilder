#requires -Module ModuleBuilder

Describe "Build-Module With Source1" {
    Write-Host "Current Modules`n$(Get-Module | Out-String)"
    Context "When we call Build-Module" {
        $Output = Build-Module $PSScriptRoot\Source1\build.psd1 -Passthru

        It "Should not put the module's DefaultCommandPrefix into the psm1 as code. Duh!" {
            [IO.Path]::ChangeExtension($Output.Path, "psm1") |
                Should -Not -FileContentMatch '^Source$'
        }
    }
}
