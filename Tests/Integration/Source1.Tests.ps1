#requires -Module ModuleBuilder

Describe "Invoke-Build With Source1" {
    Write-Host "Testing with ModuleBuilder v$((Get-Module ModuleBuilder).Version)"
    Context "When we call Invoke-Build" {
        $Output = Build-Module $PSScriptRoot\Source1\build.psd1 -Passthru

        It "Should not put the module's DefaultCommandPrefix into the psm1 as code. Duh!" {
            [IO.Path]::ChangeExtension($Output.Path, "psm1") |
                Should -Not -FileContentMatch '^Source$'
        }
    }
}
