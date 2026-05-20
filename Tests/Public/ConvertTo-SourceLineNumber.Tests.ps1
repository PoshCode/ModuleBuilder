Describe "ConvertTo-SourceLineNumber" {
    BeforeDiscovery {
        ${global:\} = [io.path]::DirectorySeparatorChar
        $TestCases = @(
            @{ outputLine = 40; sourceFile = ".${\}Private${\}TestUnExportedAliases.ps1"; sourceLine = 13 }
            @{ outputLine = 48; sourceFile = ".${\}Public${\}Get-Source.ps1"; sourceLine = 5 }
            @{ outputLine = 56; sourceFile = ".${\}Public${\}Set-Source.ps1"; sourceLine = 3 }
        )
    }
    # use the integration test code
    BeforeAll {
        Build-Module $PSScriptRoot/../Integration/Source1/build.psd1 -Passthru
        Push-Location $PSScriptRoot -StackName ConvertTo-SourceLineNumber

        $global:Convert_LineNumber_ModulePath = Convert-Path "./../Integration/Result1/Source1/1.0.0/Source1.psm1"
        $global:Convert_LineNumber_ModuleSource = Convert-Path "./../Integration/Source1"
        $global:Convert_LineNumber_ModuleContent = Get-Content $global:Convert_LineNumber_ModulePath
    }
    AfterAll {
        Pop-Location -StackName ConvertTo-SourceLineNumber
    }

    It "Should map line <outputLine> in the Module to line <sourceLine> in the source of <sourceFile>" -TestCases $TestCases {
        param($outputLine, $sourceFile, $sourceLine)

        $SourceLocation = ConvertTo-SourceLineNumber $Convert_LineNumber_ModulePath $outputLine
        $SourceLocation.SourceFile | Should -Be $SourceFile
        $SourceLocation.SourceLineNumber | Should -Be $SourceLine

        $line = (Get-Content (Join-Path $Convert_LineNumber_ModuleSource $SourceLocation.SourceFile))[$SourceLocation.SourceLineNumber - 1]
        try {
            $Convert_LineNumber_ModuleContent[$outputLine - 1] | Should -Be $line
        } catch {
            throw "Failed to match module line $outputLine to $($SourceLocation.SourceFile) line $($SourceLocation.SourceLineNumber).`nExpected $Line`nBut got  $($Convert_LineNumber_ModuleContent[$outputLine -1])"
        }
    }

    It "Should throw if the SourceFile doesn't exist" {
        { ConvertTo-SourceLineNumber -SourceFile TestDrive:${\}NoSuchFile -SourceLineNumber 10 } |
            Should -Throw "'TestDrive:${\}NoSuchFile' does not exist"
    }

    It 'Should work with an error PositionMessage' {
        $line = (Select-String -Path $Convert_LineNumber_ModulePath 'function Set-Source {').LineNumber

        $SourceLocation = "At ${Convert_LineNumber_ModulePath}:$line char:17" | ConvertTo-SourceLineNumber
        $SourceLocation.SourceFile | Should -Be ".${\}Public${\}Set-Source.ps1"
        $SourceLocation.SourceLineNumber | Should -Be 1
    }

    It 'Should work with ScriptStackTrace messages' {

        $SourceFile = Join-Path $Convert_LineNumber_ModuleSource (Join-Path Public Set-Source.ps1) | Convert-Path

        $outputLine = (Select-String -Path $Convert_LineNumber_ModulePath "sto͞o′pĭd").LineNumber
        $sourceLine = (Select-String -Path $SourceFile "sto͞o′pĭd").LineNumber

        Get-Content $Convert_LineNumber_ModulePath | Out-Host

        $sourceLine | Should -BeGreaterThan 0 -Because "the test string 'sto͞o′pĭd' is definitely found in '$SourceFile'"
        $outputLine | Should -BeGreaterThan 0 -Because "the test string 'sto͞o′pĭd' should be found in the module '$Convert_LineNumber_ModulePath'"

        $SourceLocation = "At Set-Source, ${Convert_LineNumber_ModulePath}: line $outputLine" | ConvertTo-SourceLineNumber
        $SourceLocation.SourceFile | Should -Be ".${\}Public${\}Set-Source.ps1"
        $SourceLocation.SourceLineNumber | Should -Be $sourceLine
    }

    It 'Should pass through InputObject for updating objects like CodeCoverage or ErrorRecord' {
        $PesterMiss = [PSCustomObject]@{
            # Note these don't really matter, but they're passed through
            Function = 'Get-Source'
            # these are pipeline bound
            File = $Convert_LineNumber_ModulePath
            Line = 48 # 1 offset with the Using Statement introduced in MoveUsingStatement
        }

        $SourceLocation = $PesterMiss | Convert-LineNumber -Passthru
        # This test is assuming you built the code on Windows. Should Convert-LineNumber convert the path?
        $SourceLocation.SourceFile | Should -Be ".${\}Public${\}Get-Source.ps1"
        $SourceLocation.SourceLineNumber | Should -Be 5
        $SourceLocation.Function | Should -Be 'Get-Source'
    }

    It 'Should handle type differences correctly' {
        $SourceLocation = ConvertTo-SourceLineNumber -SourceFile $Convert_LineNumber_ModulePath -SourceLineNumber ([System.UInt64]48)
        $SourceLocation.SourceFile | Should -Be ".${\}Public${\}Get-Source.ps1"
        $SourceLocation.SourceLineNumber | Should -Be 5

        $SourceLocation = ConvertTo-SourceLineNumber -SourceFile $Convert_LineNumber_ModulePath -SourceLineNumber ([System.Int32]48)
        $SourceLocation.SourceFile | Should -Be ".${\}Public${\}Get-Source.ps1"
        $SourceLocation.SourceLineNumber | Should -Be 5
    }
}
