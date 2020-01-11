#requires -Module ModuleBuilder
Describe "InitializeBuild" {
    . $PSScriptRoot\..\Convert-FolderSeparator.ps1

    Context "It collects the initial data" {

        New-Item "TestDrive:\Source\build.psd1" -Type File -Force
        New-Item "TestDrive:\Source\MyModule.psd1" -Type File -Force

        Set-Content "TestDrive:\Source\MyModule.psd1" '@{
            RootModule = "MyModule.psm1"
            Author     = "Test Manager"
            Version    = "1.0.0"
        }'

        # Note that "Path" is an alias for "SourcePath"
        Set-Content "TestDrive:\build.psd1" '@{
            Path = ".\Source\MyModule.psd1"
            SourceDirectories = @("Classes", "Private", "Public")
        }'

        $Result = @{}

        It "Handles Build-Module parameters, and the build.psd1 configuration" {
            Push-Location TestDrive:\
            $Result.Result = InModuleScope -ModuleName ModuleBuilder {
                function Test-Build {
                    [CmdletBinding()]
                    param(
                        [Alias("ModuleManifest", "Path")]
                        $SourcePath = ".\Source",
                        $SourceDirectories = @("Enum", "Classes", "Private", "Public"),
                        $OutputDirectory = ".\Output",
                        $Suffix
                    )
                    try {
                        Write-Warning $($MyInvocation.MyCommand | Out-String)
                        InitializeBuild -SourcePath $SourcePath -Debug
                    } catch {
                        $_
                    }
                }

                Test-Build 'TestDrive:\' -Suffix "Export-ModuleMember *"
            }
            Pop-Location
            $Result.Result | Should -Not -BeOfType [System.Management.Automation.ErrorRecord]
        }
        $Result = $Result.Result
        # $Result | Format-List * -Force | Out-Host

        It "Returns the ModuleInfo combined with the BuildInfo" {
            $Result.Name | Should -Be "MyModule"
            $result.ModuleType | Should -Be "Manifest"
            (Convert-FolderSeparator $Result.ModuleBase)      | Should -Be (Convert-FolderSeparator "TestDrive:\Source")
            (Convert-FolderSeparator $Result.SourcePath)  | Should -Be (Convert-FolderSeparator "TestDrive:\Source\MyModule.psd1")
        }

        It "Returns default values from the Build Command" {
            $Result.OutputDirectory | Should -Be ".\Output"
        }

        It "Returns overriden values from the build manifest" {
            $Result.SourceDirectories | Should -Be @("Classes", "Private", "Public")
        }

        It "Returns overriden values from parameters" {
            $Result.SourcePath | Should -Be (Convert-Path 'TestDrive:\Source\MyModule.psd1')
        }
    }
}
