#requires -Module ModuleBuilder
Describe "Move-UsingStatement" {
    Context "Moving Using Statements to the beginning of the file" {
        BeforeDiscovery {
            $TestCases = @(
                @{
                    TestCaseName = 'Moves all using statements in `n terminated files to the top'
                    PSM1File     = "function x {`n}`n" +
                    "using namespace System.IO`n`n" +
                    "function y {`n}`n" +
                    "using namespace System.Drawing"
                    ErrorBefore  = 2
                    ErrorAfter   = 0
                },
                @{
                    TestCaseName = 'Moves all using statements in `r`n terminated files to the top'
                    PSM1File     = "function x {`r`n}`r`n" +
                    "USING namespace System.IO`r`n`r`n" +
                    "function y {`r`n}`r`n" +
                    "USING namespace System.Drawing"
                    ErrorBefore  = 2
                    ErrorAfter   = 0
                },
                @{
                    TestCaseName   = 'Prevents duplicate using statements'
                    PSM1File       = "using namespace System.IO`r`n" +
                    "function x {`r`n}`r`n`r`n" +
                    "using namespace System.IO`r`n" +
                    "function y {`r`n}`r`n" +
                    "USING namespace System.IO"
                    ExpectedResult = "using namespace System.IO`r`n" +
                    "# using namespace System.IO`r`n" +
                    "function x {`r`n}`r`n`r`n" +
                    "# using namespace System.IO`r`n" +
                    "function y {`r`n}`r`n" +
                    "# USING namespace System.IO"
                    ErrorBefore    = 2
                    ErrorAfter     = 0
                },
                @{
                    TestCaseName = 'Does not change the content when there are no out-of-place using statements'
                    PSM1File     = "using namespace System.IO`r`n`r`n" +
                    "using namespace System.Drawing`r`n" +
                    "function x {`r`n}`r`n" +
                    "function y {`r`n}`r`n"
                    ErrorBefore  = 0
                    ErrorAfter   = 0
                },
                @{
                    TestCaseName = 'Moves using statements even if types are used'
                    PSM1File     = "function x {`r`n}`r`n" +
                    "using namespace System.IO`r`n`r`n" +
                    "function y {`r`n}`r`n" +
                    "using namespace System.Collections.Generic`r`n" +
                    "function z { [Dictionary[String,PSObject]]::new() }"
                    ErrorBefore  = 2
                    ErrorAfter   = 0
                },
                @{
                    TestCaseName = 'Moves using statements even when there are (other) parse errors'
                    PSM1File     = "using namespace System.IO`r`n`r`n" +
                    "function x {`r`n}`r`n" +
                    "using namespace System.Drawing`r`n" +
                    "function y {`r`n}`r`n}"
                    ErrorBefore  = 2
                    ErrorAfter   = 1
                }
            )
        }

        It '<TestCaseName>' -TestCases $TestCases {
            param($TestCaseName, $PSM1File, $ErrorBefore, $ErrorAfter, $ExpectedResult)

            $testModuleFile = Join-Path $TestDrive "MyModule.psm1"
            Set-Content $testModuleFile -Value $PSM1File -Encoding UTF8 -NoNewline

            # Verify parse errors exist before applying the generator
            $ErrorFound = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $testModuleFile,
                [ref]$null,
                [ref]$ErrorFound
            )
            $ErrorFound.Count | Should -Be $ErrorBefore

            # Apply the generator and get the resulting text
            $result = Invoke-ScriptGenerator -Path $testModuleFile -Generator Move-UsingStatement -Parameters @{}

            # Verify parse errors after applying the generator
            $ErrorFound = $null
            $null = [System.Management.Automation.Language.Parser]::ParseInput(
                $result,
                'testfile',
                [ref]$null,
                [ref]$ErrorFound
            )
            $ErrorFound.Count | Should -Be $ErrorAfter

            if ($ExpectedResult) {
                $result.Trim() -split "[\r\n]+" -match "^\s*using" | Should -Be ($ExpectedResult.Trim() -split "[\r\n]+" -match "^\s*using")
            }
        }
    }

    Context "When Move-UsingStatement should do nothing" {
        It 'Should not change the output when there are no using statement errors' {
            $PSM1File = "using namespace System.IO; function x {}"
            $testModuleFile = "$TestDrive\MyModule.psm1"
            Set-Content $testModuleFile -Value $PSM1File -Encoding UTF8 -NoNewline

            $result = Invoke-ScriptGenerator -Path $testModuleFile -Generator Move-UsingStatement -Parameters @{}

            $result.Trim() | Should -Be $PSM1File.Trim()
        }
    }
}
