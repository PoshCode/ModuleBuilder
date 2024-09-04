Describe "ImportBase64Module" {
    BeforeAll {
        $PSDefaultParameterValues = @{
            "Mock:ModuleName"              = "ModuleBuilder"
            "Assert-MockCalled:ModuleName" = "ModuleBuilder"
        }

        $Source = Convert-Path (Join-Path $PSScriptRoot ../Integration/Source1/Public/Set-Source.ps1)

        $CommandUnderTest, $Base64 = InModuleScope ModuleBuilder {
            Get-Command ImportBase64Module
            CompressToBase64 (Join-Path $PSScriptRoot ../Integration/Source1/Public/Set-Source.ps1) -Debug
        }

        $Plain = Get-Content $Source -Raw

    }

    It "Calls New-Module with the decompressed script" {
        Mock New-Module
        & $CommandUnderTest $Base64

        Assert-MockCalled New-Module -ParameterFilter {
            "$ScriptBlock" -eq $Plain
        }
    }

    It "Calls Import-Module with the new module" {
        Mock Import-Module
        & $CommandUnderTest $Base64
        Assert-MockCalled Import-Module -ParameterFilter {
            $ModuleInfo[0].Definition -eq $Plain
        }
    }

    # TODO: Test assemblies
}
