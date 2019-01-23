Describe "Convert-LineNumber" {
    Import-Module ModuleBuilder -DisableNameChecking -Verbose:$False

    $ModulePath = Join-Path (Get-Module ModuleBuilder).ModuleBase ModuleBuilder.psm1
    $ModuleRoot = Resolve-Path "$PSScriptRoot\..\..\Source"

    $ModuleFiles = Get-ChildItem $ModuleRoot -File -Recurse -Filter *.ps1
    $ModuleSource = Get-Content $ModulePath

    for($i=0; $i -lt 5; $i++) {

        # I don't know why I keep trying to do this using random numbers
        $lineNumber = Get-Random -min 3 -max $ModuleSource.Count
        # but I have to keep avoiding the lines that don't make sense
        while($ModuleSource[$lineNumber] -match "^\s*$|^#(END)?REGION|^\s*function\s") {
            $lineNumber += 5
        }

        It "Should map line number $lineNumber in the Module to the matching line the Source" {
            $SourceLocation = Convert-LineNumber $ModulePath $lineNumber

            $line = (Get-Content (Join-Path $ModuleRoot $SourceLocation.SourceFile))[$SourceLocation.SourceLineNumber]
            try {
                $ModuleSource[$lineNumber] | Should -Be $line
            } catch {
                throw "Failed to match module line $lineNumber to $($SourceLocation.SourceFile) line $($SourceLocation.SourceLineNumber).`nExpected $Line`nBut got  $($ModuleSource[$lineNumber])"
            }
        }
    }

    It 'Should work with an error PositionMessage' {
        $line = Select-String -Path $ModulePath 'function ParseLineNumber {' | % LineNumber

        $SourceLocation = "At ${ModulePath}:$line char:17" | Convert-LineNumber
        $SourceLocation.SourceFile | Should -Be ".\Private\ParseLineNumber.ps1"
        $SourceLocation.SourceLineNumber | Should -Be 1
    }

    It 'Should work with ScriptStackTrace messages' {
        $outputLine = Select-String -Path $ModulePath 'Write-Verbose "Copy ReadMe to: \$LanguagePath"' | % LineNumber
        $sourceLine = Select-String -Path (Join-Path $ModuleRoot Private\CopyReadMe.ps1) 'Write-Verbose "Copy ReadMe to: \$LanguagePath"' | % LineNumber

        $SourceLocation = "At CopyReadme, ${ModulePath}: line $outputLine" | Convert-LineNumber

        $SourceLocation.SourceFile | Should -Be ".\Private\CopyReadme.ps1"
        $SourceLocation.SourceLineNumber | Should -Be $sourceLine
    }

    It 'Should pass through InputObject for updating objects like CodeCoverage or ErrorRecord' {
        $PesterMiss = [PSCustomObject]@{
            # Note these don't really matter
            Command = $ModuleSource[25]
            Function = 'CopyReadme'
            # these are pipeline bound
            File = $ModulePath
            Line = 26 # 1 offset with the Using Statement introduced in MoveUsingStatements
        }

        $SourceLocation = $PesterMiss | Convert-LineNumber -Passthru
        $SourceLocation.SourceFile | Should -Be ".\Private\CopyReadme.ps1"
        $SourceLocation.SourceLineNumber | Should -Be 25
        $SourceLocation.Function | Should -Be 'CopyReadme'
    }
}