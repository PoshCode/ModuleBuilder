#requires -Module ModuleBuilder
Describe "Convert-LineNumber" {

    $ModulePath = Join-Path (Get-Module ModuleBuilder).ModuleBase ModuleBuilder.psm1
    $ModuleContent = Get-Content $ModulePath
    $ModuleSource = Resolve-Path (Join-Path $PSScriptRoot "\..\..\Source")

    for ($i=0; $i -lt 5; $i++) {

        # I don't know why I keep trying to do this using random numbers
        $lineNumber = Get-Random -min 3 -max $ModuleContent.Count
        # but I have to keep avoiding the lines that don't make sense
        while($ModuleContent[$lineNumber] -match "^\s*$|^#(END)?REGION|^\s*function\s") {
            $lineNumber += 5
        }

        It "Should map line number $lineNumber in the Module to the matching line the Source" {
            $SourceLocation = Convert-LineNumber $ModulePath $lineNumber

            $line = (Get-Content (Join-Path $ModuleSource $SourceLocation.SourceFile))[$SourceLocation.SourceLineNumber]
            try {
                $ModuleContent[$lineNumber] | Should -Be $line
            } catch {
                throw "Failed to match module line $lineNumber to $($SourceLocation.SourceFile) line $($SourceLocation.SourceLineNumber).`nExpected $Line`nBut got  $($ModuleContent[$lineNumber])"
            }
        }
    }

    It "Should throw if the SourceFile doesn't exist" {
        { Convert-LineNumber -SourceFile TestDrive:\NoSuchFile -SourceLineNumber 10 } | Should Throw "'TestDrive:\NoSuchFile' does not exist"
    }

    It 'Should work with an error PositionMessage' {
        $line = Select-String -Path $ModulePath 'function ParseLineNumber {' | % LineNumber

        $SourceLocation = "At ${ModulePath}:$line char:17" | Convert-LineNumber
        # This test is assuming you built the code on Windows. Should Convert-LineNumber convert the path?
        $SourceLocation.SourceFile | Should -Be ".\Private\ParseLineNumber.ps1"
        $SourceLocation.SourceLineNumber | Should -Be 1
    }

    It 'Should work with ScriptStackTrace messages' {

        $SourceFile = Join-Path $ModuleSource Private\CopyReadMe.ps1 | Convert-Path

        $outputLine = Select-String -Path $ModulePath 'Write-Verbose "Copy ReadMe to: \$LanguagePath"' | % LineNumber
        $sourceLine = Select-String -Path $SourceFile 'Write-Verbose "Copy ReadMe to: \$LanguagePath"' | % LineNumber

        $SourceLocation = "At CopyReadMe, ${ModulePath}: line $outputLine" | Convert-LineNumber

        # This test is assuming you built the code on Windows. Should Convert-LineNumber convert the path?
        $SourceLocation.SourceFile | Should -Be ".\Private\CopyReadMe.ps1"
        $SourceLocation.SourceLineNumber | Should -Be $sourceLine
    }

    It 'Should pass through InputObject for updating objects like CodeCoverage or ErrorRecord' {
        $PesterMiss = [PSCustomObject]@{
            # Note these don't really matter, but they're passed through
            Function = 'TotalNonsense'
            # these are pipeline bound
            File = $ModulePath
            Line = 26 # 1 offset with the Using Statement introduced in MoveUsingStatements
        }

        $SourceLocation = $PesterMiss | Convert-LineNumber -Passthru
        # This test is assuming you built the code on Windows. Should Convert-LineNumber convert the path?
        $SourceLocation.SourceFile | Should -Be ".\Private\ConvertToAst.ps1"
        $SourceLocation.SourceLineNumber | Should -Be 25
        $SourceLocation.Function | Should -Be 'TotalNonsense'
    }
}
