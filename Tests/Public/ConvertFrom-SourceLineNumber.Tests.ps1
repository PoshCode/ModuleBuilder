#requires -Module ModuleBuilder
Describe "ConvertFrom-SourceLineNumber" {
    # use the integration test code
    BeforeAll {
        Build-Module $PSScriptRoot/../Integration/Source1/build.psd1 -Passthru
        Push-Location $PSScriptRoot -StackName ConvertFrom-SourceLineNumber

        $global:Convert_LineNumber_ModulePath = Convert-Path "$PSScriptRoot/../Integration/Result1/Source1/1.0.0/Source1.psm1"
        $global:Convert_LineNumber_ModuleSource = Convert-Path "$PSScriptRoot/../Integration/Source1"
        $global:Convert_LineNumber_ModuleContent = Get-Content $global:Convert_LineNumber_ModulePath
        ${global:\} = [io.path]::DirectorySeparatorChar

        $global:TestCases = @(
            @{ outputLine = 40; sourceFile = ".${\}Private${\}TestUnExportedAliases.ps1"; sourceLine = 13; Module = $Convert_LineNumber_ModulePath }
            @{ outputLine = 48; sourceFile = ".${\}Public${\}Get-Source.ps1"; sourceLine = 5; Module = $Convert_LineNumber_ModulePath }
            @{ outputLine = 56; sourceFile = ".${\}Public${\}Set-Source.ps1"; sourceLine = 3; Module = $Convert_LineNumber_ModulePath }
        )
    }
    AfterAll {
        Pop-Location -StackName ConvertFrom-SourceLineNumber
    }

    It "Should map line <sourceLine> in the source of <sourceFile> to line <outputLine> in the Module" -TestCases $TestCases {
        param($outputLine, $sourceFile, $sourceLine, $module)

        $sourcePath = Join-Path $Convert_LineNumber_ModuleSource $SourceFile | Convert-Path
        $OutputLocation = ConvertFrom-SourceLineNumber $sourcePath $sourceLine -Module $module
        # $OutputLocation.Script | Should -Be $Convert_LineNumber_ModulePath
        $OutputLocation.Line | Should -Be $outputLine

        $line = (Get-Content $sourcePath)[$sourceLine - 1]
        try {
            $Convert_LineNumber_ModuleContent[$OutputLocation.Line - 1] | Should -Be $line
        } catch {
            throw "Failed to match module line $outputLine to $($sourceFile) line $($sourceLine).`nExpected $($Convert_LineNumber_ModuleContent[$OutputLocation.Line - 1])`nBut got $line"
        }
    }

    It "Should warn if the SourceFile doesn't exist" {
        ConvertFrom-SourceLineNumber -SourceFile TestDrive:/NoSuchFile -SourceLineNumber 10 -Module $Convert_LineNumber_ModulePath -WarningVariable Warns
        $Warns | Should -Be "'TestDrive:/NoSuchFile' not found in $Convert_LineNumber_ModulePath"
    }
}
