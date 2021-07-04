#requires -Module ModuleBuilder
Describe "MoveUsingStatements" {
    Context "Necessary Parameters" {
        $CommandInfo = InModuleScope ModuleBuilder { Get-Command MoveUsingStatements }

        It 'has a mandatory AST parameter' {
            $AST = $CommandInfo.Parameters['AST']
            $AST | Should -Not -BeNullOrEmpty
            $AST.ParameterType | Should -Be ([System.Management.Automation.Language.Ast])
            $AST.Attributes.Where{ $_ -is [Parameter] }.Mandatory | Should -Be $true
        }

        It "has an optional string Encoding parameter" {
            $Encoding = $CommandInfo.Parameters['Encoding']
            $Encoding | Should -Not -BeNullOrEmpty
            $Encoding.ParameterType | Should -Be ([String])
            $Encoding.Attributes.Where{$_ -is [Parameter]}.Mandatory | Should -Be $False
        }
    }

    Context "Moving Using Statements to the beginning of the file" {

        $MoveUsingStatementsCmd = InModuleScope ModuleBuilder {
            $null = Mock Write-Warning { }
            {   param($RootModule)
                ConvertToAst $RootModule | MoveUsingStatements
            }
        }

        $TestCases = @(
            @{
                TestCaseName = 'Moves all using statements in `n terminated files to the top'
                PSM1File     = "function x {`n}`n" +
                "using namespace System.IO`n`n" + #UsingMustBeAtStartOfScript
                "function y {`n}`n" +
                "using namespace System.Drawing" #UsingMustBeAtStartOfScript
                ErrorBefore  = 2
                ErrorAfter   = 0
            },
            @{
                TestCaseName = 'Moves all using statements in`r`n terminated files to the top'
                PSM1File     = "function x {`r`n}`r`n" +
                "USING namespace System.IO`r`n`r`n" + #UsingMustBeAtStartOfScript
                "function y {`r`n}`r`n" +
                "USING namespace System.Drawing" #UsingMustBeAtStartOfScript
                ErrorBefore  = 2
                ErrorAfter   = 0
            },
            @{
                TestCaseName = 'Prevents duplicate using statements'
                PSM1File     = "using namespace System.IO`r`n" + #UsingMustBeAtStartOfScript
                "function x {`r`n}`r`n`r`n" +
                "using namespace System.IO`r`n" + #UsingMustBeAtStartOfScript
                "function y {`r`n}`r`n" +
                "USING namespace System.IO" #UsingMustBeAtStartOfScript
                ExpectedResult  = "using namespace System.IO`r`n" +
                "#using namespace System.IO`r`n" +
                "function x {`r`n}`r`n`r`n" +
                "#using namespace System.IO`r`n" +
                "function y {`r`n}`r`n" +
                "#USING namespace System.IO"
                ErrorBefore  = 2
                ErrorAfter   = 0
            },
            @{
                TestCaseName = 'Does not change the content again if there are no out-of-place using statements'
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
                "using namespace System.IO`r`n`r`n" + #UsingMustBeAtStartOfScript
                "function y {`r`n}`r`n" +
                "using namespace System.Collections.Generic" + #UsingMustBeAtStartOfScript
                "function z { [Dictionary[String,PSObject]]::new() }" #TypeNotFound
                ErrorBefore  = 3
                ErrorAfter   = 0
            },
            @{
                TestCaseName = 'Moves using statements even when there are (other) parse errors'
                PSM1File     = "using namespace System.IO`r`n`r`n" +
                "function x {`r`n}`r`n" +
                "using namespace System.Drawing`r`n" + # UsingMustBeAtStartOfScript
                "function y {`r`n}`r`n}" # Extra } at the end
                ErrorBefore  = 2
                ErrorAfter   = 1
            }
        )

        It '<TestCaseName>' -TestCases $TestCases {
            param($TestCaseName, $PSM1File, $ErrorBefore, $ErrorAfter, $ExpectedResult)

            $testModuleFile = "$TestDrive/MyModule.psm1"
            Set-Content $testModuleFile -value $PSM1File -Encoding UTF8
            # Before
            $ErrorFound = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $testModuleFile,
                [ref]$null,
                [ref]$ErrorFound
            )
            $ErrorFound.Count | Should -Be $ErrorBefore

            # After
            &$MoveUsingStatementsCmd -RootModule $testModuleFile

            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $testModuleFile,
                [ref]$null,
                [ref]$ErrorFound
            )
            $ErrorFound.Count | Should -Be $ErrorAfter
            if ($ExpectedResult) {
                $ActualResult = Get-Content $testModuleFile -Raw
                $ActualResult.Trim() | Should -Be $ExpectedResult -Because "there should be no duplicate using statements in:`n$ActualResult"
            }
        }
    }

    Context "When MoveUsingStatements should do nothing" {

        $MoveUsingStatementsCmd = InModuleScope ModuleBuilder {
            $null = Mock Write-Warning {}
            $null = Mock Set-Content {}
            $null = Mock Write-Debug {} -ParameterFilter { $Message -eq "No using statement errors found." }

            {   param($RootModule)
                ConvertToAst $RootModule | MoveUsingStatements
            }
        }

        It 'Should not do anything when there are no using statement errors' {
            $testModuleFile = "$TestDrive\MyModule.psm1"
            $PSM1File = "using namespace System.IO; function x {}"
            Set-Content $testModuleFile -value $PSM1File -Encoding UTF8

            &$MoveUsingStatementsCmd -RootModule $testModuleFile -Debug

            (Get-Content -Raw $testModuleFile).Trim() | Should -Be $PSM1File

            Assert-MockCalled -CommandName Set-Content -Times 0 -ModuleName ModuleBuilder
            Assert-MockCalled -CommandName Write-Debug -Times 1 -ModuleName ModuleBuilder
        }
    }
}
