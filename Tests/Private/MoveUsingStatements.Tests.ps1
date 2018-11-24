Describe "MoveUsingStatements" {

    Context "Necessary Parameters" {
        $CommandInfo = InModuleScope ModuleBuilder { Get-Command MoveUsingStatements }

        It 'has a mandatory RootModule parameter' {
            $RootModule = $CommandInfo.Parameters['RootModule']
            $RootModule | Should -Not -BeNullOrEmpty
            $RootModule.Attributes.Where{$_ -is [Parameter]}.Mandatory | Should -be $true
        }

        It "has an optional string Encoding parameter" {
            $Encoding = $CommandInfo.Parameters['Encoding']
            $Encoding | Should -Not -BeNullOrEmpty
            $Encoding.ParameterType | Should -Be ([String])
            $Encoding.Attributes.Where{$_ -is [Parameter]}.Mandatory | Should -Be $False
        }
    }

    Context "Moving Using Statements to the beginning of the file" {
        $TestCases = @(
            @{
                TestCaseName = '2xUsingMustBeAtStartOfScript'
                PSM1File     = "function x {`r`n}`r`n" +
                                "Using namespace System.io`r`n`r`n" + #UsingMustBeAtStartOfScript
                                "function y {`r`n}`r`n" +
                                "Using namespace System.Drawing" #UsingMustBeAtStartOfScript
                ErrorBefore  = 2
                ErrorAfter   = 0
            },
            @{
                TestCaseName = 'NoErrors'
                PSM1File     = "Using namespace System.io`r`n`r`n" +
                                "Using namespace System.Drawing`r`n"+
                                "function x { `r`n}`r`n" +
                                "function y { `r`n}`r`n"
                ErrorBefore  = 0
                ErrorAfter   = 0
            },
            @{
                TestCaseName = 'NotValidPowerShell'
                PSM1File     = "Using namespace System.io`r`n`r`n" +
                                "function x { `r`n}`r`n" +
                                "Using namespace System.Drawing`r`n"+ # UsingMustBeAtStartOfScript
                                "function y { `r`n}`r`n}" # Extra } at the end
                ErrorBefore  = 2
                ErrorAfter   = 2
            }
        )

        It 'Should succeed <TestCaseName> from <ErrorBefore> to <ErrorAfter> parsing errors' -TestCases $TestCases {
            param($TestCaseName, $PSM1File, $ErrorBefore, $ErrorAfter)

            $testModuleFile = "$TestDrive\MyModule.psm1"
            Set-Content $testModuleFile -value $PSM1File -Encoding UTF8
            # Before
            $ErrorFound = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $testModuleFile,
                [ref]$null,
                [ref]$ErrorFound
            )
            $ErrorFound.Count | Should -be $ErrorBefore

            # After
            InModuleScope ModuleBuilder {
                $testModuleFile = "$TestDrive\MyModule.psm1"
                MoveUsingStatements -RootModule $testModuleFile
            }
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $testModuleFile,
                [ref]$null,
                [ref]$ErrorFound
            )
            $ErrorFound.Count | Should -be $ErrorAfter
        }

        It 'Should Not do anything when there are no parsing errors' {

        }

    }
}