Describe "Convert-CodeCoverage" {
    # use the integration test code
    BeforeAll {
        Build-Module $PSScriptRoot/../Integration/Source1/build.psd1 -Passthru
        Push-Location $PSScriptRoot -StackName Convert-CodeCoverage
        ${global:\} = [io.path]::DirectorySeparatorChar
    }
    AfterAll {
        Pop-Location -StackName Convert-CodeCoverage
    }

    It 'Should extract code coverage from Pester objects and add Source conversions' {
        $ModulePath = Convert-Path "./../Integration/Result1/Source1/1.0.0/Source1.psm1"
        $ModuleSource = Convert-Path "./../Integration/Source1"

        # Note: Pester does not currently apply custom types...
        $PesterResults = [PSCustomObject]@{
            CodeCoverage = [PSCustomObject]@{
                MissedCommands = [PSCustomObject]@{
                    # these are pipeline bound
                    File = $ModulePath
                    Line = 43 # [Alias("gs","gsou")]
                }
            }
        }

        $SourceLocation = $PesterResults | Convert-CodeCoverage -SourceRoot $ModuleSource

        # Needs to match the actual module source (on line 25)
        $SourceLocation.SourceFile | Should -Be ".${\}Public${\}Get-Source.ps1"
        $SourceLocation.Line | Should -Be 5
    }
}
