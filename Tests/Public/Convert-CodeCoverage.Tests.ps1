Describe "Convert-CodeCoverage" {

    $ModulePath = Join-Path (Get-Module ModuleBuilder).ModuleBase ModuleBuilder.psm1
    $ModuleContent = Get-Content $ModulePath

    $ModuleSource = Resolve-Path "$PSScriptRoot\..\..\Source"

    $lineNumber = Get-Random -min 3 -max $ModuleContent.Count
    while($ModuleContent[$lineNumber] -match "^#(END)?REGION") {
        $lineNumber += 5
    }

    It 'Should extract code coverage from Pester objects and add Source conversions' {

        # Note: Pester does not currently apply custom types...
        $PesterResults = [PSCustomObject]@{
            CodeCoverage = [PSCustomObject]@{
                MissedCommands = [PSCustomObject]@{
                    # these are pipeline bound
                    File = $ModulePath
                    Line = 26 # 1 offset with the Using Statement introduced in MoveUsingStatements
                }
            }
        }

        $SourceLocation = $PesterResults | Convert-CodeCoverage -SourceRoot $ModuleSource

        # Needs to match the actual module source (on line 25)
        $SourceLocation.SourceFile | Should -Be ".\Private\ConvertToAst.ps1"
        $SourceLocation.Line | Should -Be 25
    }
}
