#requires -Module ModuleBuilder
Describe "ImportModuleManifest" {

    Context "Mandatory Parameter" {
        $CommandInfo = InModuleScope ModuleBuilder { Get-Command ImportModuleManifest }

        It 'has a mandatory Path parameter for the PSPath by pipeline' {
            $Path = $CommandInfo.Parameters['Path']
            $Path | Should -Not -BeNullOrEmpty
            $Path.ParameterType | Should -Be ([string])
            $Path.Aliases | Should -Be ("PSPath")
            $Path.Attributes.Where{ $_ -is [Parameter] }.Mandatory | Should -Be $true
            $Path.Attributes.Where{ $_ -is [Parameter] }.ValueFromPipelineByPropertyName | Should -Be $true
        }

    }

    Context "Parsing Manifests" {
        It "Does not cause errors for non-existent root modules" {
            New-ModuleManifest -Path TestDrive:\BadRoot.psd1 -Author TestName -RootModule NoSuchFile

            InModuleScope ModuleBuilder {
                ImportModuleManifest -Path TestDrive:\BadRoot.psd1 -ErrorAction Stop
            }
        }

        It "Returns the ModuleInfo with DefaultCommandPrefix instead of Prefix" {
            New-ModuleManifest -Path TestDrive:\TestPrefix.psd1 -Author TestName -DefaultCommandPrefix PrePre

            $Prefix = InModuleScope ModuleBuilder {
                $DebugPreference = "Continue"
                Get-ChildItem TestDrive:\TestPrefix.psd1 | ImportModuleManifest
                $DebugPreference = "SilentlyContinue"
            }

            $Prefix.Prefix | Should -BeNullOrEmpty
            $Prefix.DefaultCommandPrefix | Should -Be "PrePre"
        }

        It "Does cause errors for manifests that are invalid" {
            New-ModuleManifest -Path TestDrive:\Invalid.psd1 -Author TestName -ModuleVersion "1.0.0"
            Set-Content TestDrive:\Invalid.psd1 (
                (Get-Content -Path TestDrive:\Invalid.psd1 -Raw) -replace "1.0.0"
            )

            {
                InModuleScope ModuleBuilder {
                    ImportModuleManifest -Path TestDrive:\Invalid.psd1 -ErrorAction Stop -WarningAction Stop
                }
            } | Should -Throw
        }
    }

    Context "Invalid module manifest" {
        # In the current PowerShell 5.1 and 6.1
        # We can't make Get-Module -ListAvailable throw on a manifest
        # So I can't test the if($Problems = ... code
    }
}
