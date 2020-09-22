#requires -Module ModuleBuilder
Describe "ResolveOutputFolder" {
    . $PSScriptRoot\..\Convert-FolderSeparator.ps1
    $CommandInTest = InModuleScope ModuleBuilder { Get-Command ResolveOutputFolder }
    filter ToTestDrive { "$_".Replace($TestDrive, "TestDrive:") }

    $TestCases = [Hashtable[]]@(
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
        @{  # The default option would be Module/Source build to Module/Output
            Source = "ModuleName/Source"
            Output = "ModuleName/Output"
            Result = "ModuleName/Output/ModuleName"
            Forced = "ModuleName/Output/ModuleName/1.2.3"
        }
        @{  # Which is the same even without the common named parent
            Source = "Source"
            Output = "Output"
            Result = "Output/ModuleName"
            Forced = "Output/ModuleName/1.2.3"
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
                Source = Convert-FolderSeparator "$TestDrive/$Source"
                Output = Convert-FolderSeparator "$TestDrive/$Output"
            }

            $Actual = &$CommandInTest @Parameters -Name ModuleName -Target Build -Version 1.2.3 | ToTestDrive
            $Actual | Should -Exist
            $Actual | Should -Be (Convert-FolderSeparator "TestDrive:/$Result")
        }

        It "From '<Source>' to '<Output>' -ForceVersion creates '<Forced>'" -TestCases $TestCases {
            param($Source, $Output, $Forced)

            $Parameters = @{
                Source = Convert-FolderSeparator "TestDrive:/$Source"
                Output = Convert-FolderSeparator "TestDrive:/$Output"
            }

            $Actual = &$CommandInTest @Parameters -Name ModuleName -Target Build -Version 1.2.3 -Force | ToTestDrive
            $Actual | Should -Exist
            $Actual | Should -Be (Convert-FolderSeparator "TestDrive:/$Forced")
        }
    }
    Context "Cleaned ModuleName" {
        It "From '<Source>' to '<Output>' deletes '<Result>'" -TestCases $TestCases {
            param($Source, $Output, $Result)

            $Parameters = @{
                Source = Convert-FolderSeparator "TestDrive:/$Source"
                Output = Convert-FolderSeparator "TestDrive:/$Output"
            }

            $null = New-Item -ItemType Directory (Convert-FolderSeparator "TestDrive:/$Result") -Force

            # There's no output when we're cleaning
            &$CommandInTest @Parameters -Name ModuleName -Version 1.2.3 -Target Clean | Should -BeNullOrEmpty
            "TestDrive:/$Result" | Should -Not -Exist
            # NOTE: This is only true because we made it above
            "TestDrive:/$Result" | Split-Path | Should -Exist
        }

        It "From '<Source>' to '<Output>' -ForceVersion deletes '<Forced>'" -TestCases $TestCases {
            param($Source, $Output, $Forced)

            $Parameters = @{
                Source = Convert-FolderSeparator "TestDrive:/$Source"
                Output = Convert-FolderSeparator "TestDrive:/$Output"
            }
            $null = New-Item -ItemType Directory "TestDrive:/$Forced" -Force

            # There's no output when we're cleaning
            &$CommandInTest @Parameters -Name ModuleName -Version 1.2.3 -Force -Target Clean | Should -BeNullOrEmpty
            "TestDrive:/$Forced" | Convert-FolderSeparator | Should -Not -Exist
            # NOTE: This is only true because we made it above
            "TestDrive:/$Forced" | Convert-FolderSeparator | Split-Path | Should -Exist
        }
    }
    Context "Error Cases" {
        It "Won't remove a file that blocks the folder path" {
            $null = New-Item -ItemType Directory TestDrive:/ModuleName/Source -force
            New-Item TestDrive:/ModuleName/1.2.3 -ItemType File -Value "Hello World"

            $Parameters = @{
                Source = Convert-FolderSeparator "TestDrive:/ModuleName/Source"
                Output = Convert-FolderSeparator "TestDrive:/ModuleName/"
            }

            { &$CommandInTest @Parameters -Name ModuleName -Target Build -Version 1.2.3 -Force } | Should -throw "There is a file in the way"
        }
    }
}
