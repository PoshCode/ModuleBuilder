#requires -Module ModuleBuilder

Describe "When we call Build-Module" -Tag Integration {
    $Output = Build-Module $PSScriptRoot\Source1\build.psd1 -Passthru
    $Module = [IO.Path]::ChangeExtension($Output.Path, "psm1")

    It "Should not put the module's DefaultCommandPrefix into the psm1 as code. Duh!" {
        $Module | Should -Not -FileContentMatch '^Source$'
    }

    $Metadata = Import-Metadata $Output.Path

    It "Should update FunctionsToExport in the manifest" {
        $Metadata.FunctionsToExport | Should -Be @("Get-Source", "Set-Source")
    }

    It "Should update AliasesToExport in the manifest" {
        $Metadata.AliasesToExport -match "GS" | Should -Not -BeNullOrEmpty
    }

    It "Should de-dupe and move using statements to the top of the file" {
        Select-String -Pattern "^using" -Path $Module | ForEach-Object LineNumber | Should -Be 1
    }

    It "Will comment out the original using statements in their original positions" {
        (Select-String -Pattern "^#\s*using" -Path $Module).Count | Should -Be 3
    }
}

Describe "Regression test for #55: I can pass SourceDirectories" -Tag Integration, Regression {
    $Output = Build-Module $PSScriptRoot\Source1\build.psd1 -SourceDirectories "Private" -Passthru
    $Module = [IO.Path]::ChangeExtension($Output.Path, "psm1")

    It "Should not put the module's DefaultCommandPrefix into the psm1 as code. Duh!" {
        $Module | Should -Not -FileContentMatch '^Source$'
    }

    $Metadata = Import-Metadata $Output.Path

    It "Should not have any FunctionsToExport if SourceDirectories don't match the PublicFilter" {
        $Metadata.FunctionsToExport | Should -Be @()
    }

    It "Should de-dupe and move using statements to the top of the file" {
        Select-String -Pattern "^using" -Path $Module | ForEach-Object LineNumber | Should -Be 1
    }

    It "Will comment out the original using statement in the original positions" {
        (Select-String -Pattern "^#\s*using" -Path $Module).Count | Should -Be 2
    }
}

Describe "Regression test for #55: I can pass SourceDirectories and PublicFilter" -Tag Integration, Regression {
    $Output = Build-Module $PSScriptRoot\Source1\build.psd1 -SourceDirectories "Private" -PublicFilter "P*\*" -Passthru
    $Module = [IO.Path]::ChangeExtension($Output.Path, "psm1")

    It "Should not put the module's DefaultCommandPrefix into the psm1 as code. Duh!" {
        $Module | Should -Not -FileContentMatch '^Source$'
    }

    $Metadata = Import-Metadata $Output.Path

    It "Should not have any FunctionsToExport if SourceDirectories don't match the PublicFilter" {
        $Metadata.FunctionsToExport | Should -Be @("GetFinale", "GetPreview")
    }

    It "Should update AliasesToExport in the manifest" {
        $Metadata.AliasesToExport | Should -Be @("GF", "GP")
    }

    It "Should de-dupe and move using statements to the top of the file" {
        Select-String -Pattern "^using" -Path $Module | ForEach-Object LineNumber | Should -Be 1
    }

    It "Will comment out the original using statement in the original positions" {
        (Select-String -Pattern "^#\s*using" -Path $Module).Count | Should -Be 2
    }
}

Describe "Regression test for #84: Multiple Aliases per command will Export" -Tag Integration, Regression {
    $Output = Build-Module $PSScriptRoot\Source1\build.psd1 -Passthru

    $Metadata = Import-Metadata $Output.Path

    It "Should update AliasesToExport in the manifest" {
        $Metadata.AliasesToExport | Should -Be @("GS","GSou", "SS", "SSou")
    }
}

Describe "Supports building without a build.psd1" -Tag Integration {
    Copy-Item $PSScriptRoot\Source1 TestDrive:\Source1 -Recurse
    # This is the old build, with a build.psd1
    $Output = Build-Module TestDrive:\Source1\build.psd1 -Passthru
    $ManifestContent = Get-Content $Output.Path
    $ModuleContent = Get-Content ([IO.Path]::ChangeExtension($Output.Path, ".psm1"))
    Remove-Item (Split-Path $Output.Path) -Recurse

    # Then remove the build.psd1 and rebuild it
    Remove-Item TestDrive:\Source1\build.psd1

    $Build = @{ }

    It "No longer fails if there's no build.psd1" {
        $BuildParameters = @{
            SourcePath               = "TestDrive:\Source1\Source1.psd1"
            OutputDirectory          = "TestDrive:\Result1"
            VersionedOutputDirectory = $true
        }

        $Build.Output = Build-Module @BuildParameters -Passthru
    }

    It "Creates the same module as with a build.psd1" {
        $Build.Metadata = Import-Metadata $Build.Output.Path
        Get-Content $Build.Output.Path | Should -Be $ManifestContent
        Get-Content ([IO.Path]::ChangeExtension($Build.Output.Path, ".psm1")) | Should -Be $ModuleContent
    }

    It "Should update AliasesToExport in the manifest" {
        $Build.Metadata.AliasesToExport | Should -Be @("GS", "GSou", "SS", "SSou")
    }

    It "Should update FunctionsToExport in the manifest" {
        $Build.Metadata.FunctionsToExport | Should -Be @("Get-Source", "Set-Source")
    }
}

Describe "Supports building without a build.psd1 that has parent folder with a name different than module name" -Tag Integration {
    Copy-Item $PSScriptRoot\Source1 TestDrive:\s -Recurse
    # This is the old build, with a build.psd1
    $Output = Build-Module TestDrive:\s\build.psd1 -Passthru
    $ManifestContent = Get-Content $Output.Path
    $ModuleContent = Get-Content ([IO.Path]::ChangeExtension($Output.Path, ".psm1"))
    Remove-Item (Split-Path $Output.Path) -Recurse

    # Then remove the build.psd1 and rebuild it
    Remove-Item TestDrive:\s\build.psd1

    $Build = @{ }

    It "No longer fails if there's no build.psd1" {
        $BuildParameters = @{
            SourcePath               = "TestDrive:\s\Source1.psd1"
            OutputDirectory          = "TestDrive:\Result1"
            VersionedOutputDirectory = $true
        }

        $Build.Output = Build-Module @BuildParameters -Passthru
    }

    It "Creates the same module as with a build.psd1" {
        $Build.Metadata = Import-Metadata $Build.Output.Path
        Get-Content $Build.Output.Path | Should -Be $ManifestContent
        Get-Content ([IO.Path]::ChangeExtension($Build.Output.Path, ".psm1")) | Should -Be $ModuleContent
    }

    It "Should update AliasesToExport in the manifest" {
        $Build.Metadata.AliasesToExport | Should -Be @("GS", "GSou", "SS", "SSou")
    }

    It "Should update FunctionsToExport in the manifest" {
        $Build.Metadata.FunctionsToExport | Should -Be @("Get-Source", "Set-Source")
    }
}

Describe "Supports building discovering the module without a build.psd1" -Tag Integration {
    Copy-Item $PSScriptRoot\Source1 TestDrive:\source -Recurse

    # This is the old build, with a build.psd1
    $Output = Build-Module TestDrive:\source\build.psd1 -Passthru
    $ManifestContent = Get-Content $Output.Path
    $ModuleContent = Get-Content ([IO.Path]::ChangeExtension($Output.Path, ".psm1"))
    Remove-Item (Split-Path $Output.Path) -Recurse

    # Then remove the build.psd1 and rebuild it
    Remove-Item TestDrive:\source\build.psd1

    Push-Location -StackName 'IntegrationTest' -Path TestDrive:\

    $Build = @{ }

    It "No longer fails if there's no build.psd1" {
        $Build.Output = Build-Module -Passthru
    }

    It "Creates the same module as with a build.psd1" {
        $Build.Metadata = Import-Metadata $Build.Output.Path
        Get-Content $Build.Output.Path | Should -Be $ManifestContent
        Get-Content ([IO.Path]::ChangeExtension($Build.Output.Path, ".psm1")) | Should -Be $ModuleContent
    }

    It "Should update AliasesToExport in the manifest" {
        $Build.Metadata.AliasesToExport | Should -Be @("GS", "GSou", "SS", "SSou")
    }

    It "Should update FunctionsToExport in the manifest" {
        $Build.Metadata.FunctionsToExport | Should -Be @("Get-Source", "Set-Source")
    }

    Pop-Location -StackName 'IntegrationTest'
}

Describe "Regression test for #88 not copying prefix files" -Tag Integration, Regression {
    $Output = Build-Module $PSScriptRoot\build.psd1 -Passthru

    $Metadata = Import-Metadata $Output.Path

    It "Should update AliasesToExport in the manifest" {
        $Module = [IO.Path]::ChangeExtension($Output.Path, "psm1")
        $ModuleInfo = Get-Content $Module
        $ModuleInfo[0] | Should -be "using module Configuration"
    }
}
