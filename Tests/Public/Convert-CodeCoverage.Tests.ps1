Describe "Convert-CodeCoverage" {

    $ModulePath = Join-Path (Get-Module ModuleBuilder).ModuleBase ModuleBuilder.psm1
    $ModuleRoot = Resolve-Path "$PSScriptRoot\..\..\Source"

    $ModuleFiles = Get-ChildItem $ModuleRoot -File -Recurse -Filter *.ps1
    $ModuleSource = Get-Content $ModulePath

    $lineNumber = Get-Random -min 2 -max $ModuleSource.Count
    while($ModuleSource[$lineNumber] -match "^#(END)?REGION") {
        $lineNumber += 5
    }

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

        $SourceLocation = $PesterResults | Convert-CodeCoverage -SourceRoot $ModuleRoot

        $SourceLocation.SourceFile | Should -Be ".\Private\CopyReadme.ps1"
        $SourceLocation.Line | Should -Be 24
    }
}