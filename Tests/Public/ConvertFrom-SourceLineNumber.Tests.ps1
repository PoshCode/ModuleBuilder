Describe "ConvertFrom-SourceLineNumber" {
    # use the integration test code
    BeforeDiscovery {
        ${\} = [io.path]::DirectorySeparatorChar

        $TestCases = @(
            @{
                outputLine = 40;
                sourceFile = ".${\}Private${\}TestUnExportedAliases.ps1";
                sourceLine = 13;
                Module     = "$PSScriptRoot${\}..${\}Integration${\}Result1${\}Source1${\}1.0.0${\}Source1.psm1"
            }
            @{
                outputLine = 48;
                sourceFile = ".${\}Public${\}Get-Source.ps1";
                sourceLine = 5;
                Module     = "$PSScriptRoot${\}..${\}Integration${\}Result1${\}Source1${\}1.0.0${\}Source1.psm1"
            }
            @{
                outputLine = 56;
                sourceFile = ".${\}Public${\}Set-Source.ps1";
                sourceLine = 3;
                Module     = "$PSScriptRoot${\}..${\}Integration${\}Result1${\}Source1${\}1.0.0${\}Source1.psm1"
            }
        )
    }
    BeforeAll {
        ${\} = [io.path]::DirectorySeparatorChar
        Build-Module "$PSScriptRoot${\}..${\}Integration${\}Source1${\}build.psd1" -Passthru
        Push-Location $PSScriptRoot -StackName ConvertFrom-SourceLineNumber

        $Convert_LineNumber_ModuleContent = Get-Content "$PSScriptRoot${\}..${\}Integration${\}Result1${\}Source1${\}1.0.0${\}Source1.psm1"
        ${\} = [io.path]::DirectorySeparatorChar
    }
    AfterAll {
        Pop-Location -StackName ConvertFrom-SourceLineNumber
    }

    It "Should map line <sourceLine> in the source of <sourceFile> to line <outputLine> in the Module" -TestCases $TestCases {
        param($outputLine, $sourceFile, $sourceLine, $module)

        ${\} = [io.path]::DirectorySeparatorChar
        $sourcePath = Join-Path "$PSScriptRoot${\}..${\}Integration${\}Source1" $SourceFile | Convert-Path
        $OutputLocation = ConvertFrom-SourceLineNumber $sourcePath $sourceLine -Module $module
        # $OutputLocation.Script | Should -Be "$PSScriptRoot/../Integration/Result1/Source1/1.0.0/Source1.psm1"
        $OutputLocation.Line | Should -Be $outputLine

        $line = (Get-Content $sourcePath)[$sourceLine - 1]
        try {
            $Convert_LineNumber_ModuleContent[$OutputLocation.Line - 1] | Should -Be $line
        } catch {
            throw "Failed to match module line $outputLine to $($sourceFile) line $($sourceLine).`nExpected $($Convert_LineNumber_ModuleContent[$OutputLocation.Line - 1])`nBut got $line"
        }
    }

    It "Should warn if the SourceFile doesn't exist" {
        ${\} = [io.path]::DirectorySeparatorChar
        ConvertFrom-SourceLineNumber -SourceFile "TestDrive:${\}NoSuchFile" -SourceLineNumber 10 -Module "$PSScriptRoot${\}..${\}Integration${\}Result1${\}Source1${\}1.0.0${\}Source1.psm1" -WarningVariable Warns
        $Warns | Should -Be "'TestDrive:${\}NoSuchFile' not found in $PSScriptRoot${\}..${\}Integration${\}Result1${\}Source1${\}1.0.0${\}Source1.psm1"
    }
}
