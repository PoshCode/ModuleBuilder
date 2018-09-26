Describe "Convert-CodeCoverage"

    It 'Should extract code coverage from Pester objects and add Source conversions' {

        # Note: Pester does not currently apply custom types...
        $PesterResults = [PSCustomObject]@{
            CodeCoverage = [PSCustomObject]@{
                MissedCommands = [PSCustomObject]@{
                    # Note these don't really matter
                    Command = $ModuleSource[25]
                    Function = 'CopyReadme'
                    # these are pipeline bound
                    File = $ModulePath
                    Line = 25
                }
            }
        }

        $SourceLocation = $PesterResults | Convert-CodeCoverage

        $SourceLocation.SourceFile | Should -Be ".\Private\CopyReadme.ps1"
        $SourceLocation.SourceLineNumber | Should -Be 24
        $SourceLocation.Function | Should -Be 'CopyReadme'
    }
}