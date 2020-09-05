#requires -Module ModuleBuilder
Describe "ResolveOutputFolder" {
    $CommandInTest = InModuleScope ModuleBuilder { Get-Command ResolveOutputFolder }
    filter ToTestDrive { "$_".Replace($TestDrive, "TestDrive:") }

    $TestCases = [Hashtable[]]@(
        @{  Source = "Source"
            Output = "Output"
            Result = "Output/ModuleName"
            Forced = "Output/ModuleName/1.2.3"
        }
        @{  Output = "ModuleName/Output"
            Source = "ModuleName/Source"
            Result = "ModuleName/Output/ModuleName"
            Forced = "ModuleName/Output/ModuleName/1.2.3"
        }
        @{  # Be like Jaykul
            Source = "ModuleName/Source"
            Output = "ModuleName"
            Result = "ModuleName/1.2.3"
            Forced = "ModuleName/1.2.3"
        }
        @{  # Be like azure
            Source = "1/s"
            Output = "1/b"
            Result = "1/b/ModuleName"
            Forced = "1/b/ModuleName/1.2.3"
        }
        @{  # An edge case, build straight to a modules folder
            Source = "ModuleName/Source"
            Output = "Modules"
            Result = "Modules/ModuleName"
            Forced = "Modules/ModuleName/1.2.3"
        }
        @{  # What if they pass in the correct path ahead of time?
            Source = "1/s"
            Output = "1/b/ModuleName"
            Result = "1/b/ModuleName"
            Forced = "1/b/ModuleName/1.2.3"
        }
        @{  # What if they pass in the correct path ahead of time?
            Source = "1/s"
            Output = "1/b/ModuleName/1.2.3"
            Result = "1/b/ModuleName/1.2.3"
            Forced = "1/b/ModuleName/1.2.3"
        }
        @{  # Super edge case: what if they pass in an incorrectly versioned output path?
            Source = "1/s"
            Output = "1/b/ModuleName/4.5.6"
            Result = "1/b/ModuleName/4.5.6/ModuleName"
            Forced = "1/b/ModuleName/4.5.6/ModuleName/1.2.3"
        }
    )
    Context "Build ModuleName" {
        It "From '<Source>' to '<Output>' creates '<Result>'" -TestCases $TestCases {
            param($Source, $Output, $Result)

            $Parameters = @{
                Source = "TestDrive:/$Source"
                Output = "TestDrive:/$Output"
            }

            $Actual = &$CommandInTest @Parameters -Name ModuleName -Target Build -Version 1.2.3 | ToTestDrive
            $Actual | Should -Exist
            $Actual | Should -Be "TestDrive:/$Result"
        }

        It "From '<Source>' to '<Output>' -ForceVersion creates '<Forced>'" -TestCases $TestCases {
            param($Source, $Output, $Forced)

            $Parameters = @{
                Source = "TestDrive:/$Source"
                Output = "TestDrive:/$Output"
            }

            $Actual = &$CommandInTest @Parameters -Name ModuleName -Target Build -Version 1.2.3 -Force | ToTestDrive
            $Actual | Should -Exist
            $Actual | Should -Be "TestDrive:/$Forced"
        }
    }
    Context "Cleaned ModuleName" {
        It "From '<Source>' to '<Output>' deletes '<Result>'" -TestCases $TestCases {
            param($Source, $Output, $Result)

            $Parameters = @{
                Source = "TestDrive:/$Source"
                Output = "TestDrive:/$Output"
            }

            $null = New-Item -ItemType Directory "TestDrive:/$Result" -Force

            # There's no output when we're cleaning
            &$CommandInTest @Parameters -Name ModuleName -Version 1.2.3 -Target Clean | Should -BeNullOrEmpty
            "TestDrive:/$Result" | Should -Not -Exist
            # NOTE: This is only true because we made it above
            "TestDrive:/$Result" | Split-Path | Should -Exist
        }

        It "From '<Source>' to '<Output>' -ForceVersion deletes '<Forced>'" -TestCases $TestCases {
            param($Source, $Output, $Forced)

            $Parameters = @{
                Source = "TestDrive:/$Source"
                Output = "TestDrive:/$Output"
            }
            $null = New-Item -ItemType Directory "TestDrive:/$Forced" -Force

            # There's no output when we're cleaning
            &$CommandInTest @Parameters -Name ModuleName -Version 1.2.3 -Force -Target Clean | Should -BeNullOrEmpty
            "TestDrive:/$Forced" | Should -Not -Exist
            # NOTE: This is only true because we made it above
            "TestDrive:/$Forced" | Split-Path | Should -Exist
        }
    }
    Context "Error Cases" {
        It "Won't remove a file that blocks the folder path" {
            $null = New-Item -ItemType Directory TestDrive:/ModuleName/Source -force
            New-Item TestDrive:/ModuleName/1.2.3 -ItemType File -Value "Hello World"

            $Parameters = @{
                Source = "TestDrive:/ModuleName/Source"
                Output = "TestDrive:/ModuleName/"
            }

            { &$CommandInTest @Parameters -Name ModuleName -Target Build -Version 1.2.3 -Force } | Should -throw "There is a file in the way"
        }
    }
}
