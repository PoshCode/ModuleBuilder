Describe "Build-Module" {

    Context "Parameter Binding" {

        $Parameters = (Get-Command Build-Module).Parameters

        It "has an optional string parameter for the SourcePath" {
            $parameters.ContainsKey("SourcePath") | Should -Be $true
            $parameters["SourcePath"].ParameterType | Should -Be ([string])
            $parameters["SourcePath"].Attributes.Where{$_ -is [Parameter]}.Mandatory | Should -Be $false
        }

        It "has an optional string parameter for the OutputDirectory" {
            $parameters.ContainsKey("OutputDirectory") | Should -Be $true
            $parameters["OutputDirectory"].ParameterType | Should -Be ([string])
            $parameters["OutputDirectory"].Attributes.Where{$_ -is [Parameter]}.Mandatory | Should -Be $false
        }

        It "has an optional parameter for setting the Version"{
            $parameters.ContainsKey("Version") | Should -Be $true
            $parameters["Version"].ParameterType | Should -Be ([version])
            $parameters["Version"].Attributes.Where{$_ -is [Parameter]}.Mandatory | Should -Be $false
        }

        It "has an optional parameter for setting the Encoding"{
            $parameters.ContainsKey("Encoding") | Should -Be $true
            # Note that in PS Core, we can't use encoding types for parameters
            $parameters["Encoding"].ParameterType | Should -Be ([string])
            $parameters["Encoding"].Attributes.Where{$_ -is [Parameter]}.Mandatory | Should -Be $false
        }

        It "has an optional string parameter for a Prefix"{
            $parameters.ContainsKey("Prefix") | Should -Be $true
            $parameters["Prefix"].ParameterType | Should -Be ([string])
            $parameters["Prefix"].Attributes.Where{$_ -is [Parameter]}.Mandatory | Should -Be $false
        }

        It "has an optional string parameter for a Suffix" {
            $parameters.ContainsKey("Suffix") | Should -Be $true
            $parameters["Suffix"].ParameterType | Should -Be ([string])
            $parameters["Suffix"].Attributes.Where{$_ -is [Parameter]}.Mandatory | Should -Be $false
        }

        It "supports setting the Target to Clean, Build or both" {
            $parameters.ContainsKey("Target") | Should -Be $true

            # Techincally we could implement this a few other ways ...
            $parameters["Target"].ParameterType | Should -Be ([string])
            $parameters["Target"].Attributes.Where{$_ -is [ValidateSet]}.ValidValues | Should -Be "Clean", "Build", "CleanBuild"
        }

        It "has an Passthru switch parameter" {
            $parameters.ContainsKey("Passthru") | Should -Be $true
            $parameters["Passthru"].ParameterType | Should -Be ([switch])
        }
    }

    Context "When run without parameters" {
        Push-Location TestDrive:\ -StackName BuildModuleTest
        New-Item -ItemType Directory -Path TestDrive:\MyModule\ -Force
        New-Item -ItemType Directory -Path TestDrive:\1.0.0\ -Force

        Mock SetModuleContent -ModuleName ModuleBuilder {}
        Mock Update-Metadata -ModuleName ModuleBuilder {}
        Mock InitializeBuild -ModuleName ModuleBuilder {
            # These are actually all the values that we need
            @{
                OutputDirectory = "TestDrive:\1.0.0"
                Name = "MyModule"
                ModuleBase = "TestDrive:\MyModule\"
                CopyDirectories = @()
                Encoding = "UTF8"
                PublicFilter = "Public\*.ps1"
            }
        }

        Mock Test-Path {$True} -Parameter {$Path -eq "TestDrive:\1.0.0"} -ModuleName ModuleBuilder
        Mock Remove-Item {} -Parameter {$Path -eq "TestDrive:\1.0.0"} -ModuleName ModuleBuilder
        Mock Set-Location {} -ModuleName ModuleBuilder
        Mock Copy-Item {} -ModuleName ModuleBuilder

        Mock Get-ChildItem {
            [IO.FileInfo]$(Join-Path $(Convert-Path "TestDrive:\") "MyModule\Public\Get-MyInfo.ps1")
        } -ModuleName ModuleBuilder

        Mock New-Item {} -Parameter {
            $Path -eq "TestDrive:\1.0.0" -and
            $ItemType -eq "Directory" -and
            $Force -eq $true
        } -ModuleName ModuleBuilder

        try {
            Build-Module
        } finally {
            Pop-Location -StackName BuildModuleTest
        }

        # NOTE: We're not just clearing output, but the whole folder
        It "Should remove the output folder if it exists" {
            Assert-MockCalled Remove-Item -ModuleName ModuleBuilder
        }

        It "Should always (re)create the OutputDirectory" {
            Assert-MockCalled New-Item -ModuleName ModuleBuilder
        }

        It "Should run in the module source folder" {
            Assert-MockCalled Set-Location -ModuleName ModuleBuilder -Parameter {
                $Path -eq "TestDrive:\MyModule\"
            }
        }

        It "Should call SetModuleContent to combine the source files" {
            Assert-MockCalled SetModuleContent -ModuleName ModuleBuilder
        }

        It "Should call Update-Metadata to set the FunctionsToExport" {
            Assert-MockCalled Update-Metadata -ModuleName ModuleBuilder -Parameter {
                $PropertyName -eq "FunctionsToExport"
            }
        }
    }

    Context "When run without 'Clean' in the target" {
        Push-Location TestDrive:\ -StackName BuildModuleTest
        New-Item -ItemType Directory -Path TestDrive:\MyModule\Public -Force
        New-Item -ItemType File -Path TestDrive:\MyModule\Public\Get-MyInfo.ps1 -Force
        Start-Sleep -Milliseconds 200 # to ensure the output is after the input
        New-Item -ItemType Directory -Path TestDrive:\1.0.0\ -Force
        New-Item -ItemType File -Path TestDrive:\1.0.0\MyModule.psm1 -Force

        Mock SetModuleContent -ModuleName ModuleBuilder {}
        Mock Update-Metadata -ModuleName ModuleBuilder {}
        Mock InitializeBuild -ModuleName ModuleBuilder {
            # These are actually all the values that we need
            @{
                OutputDirectory = "TestDrive:\1.0.0"
                Name = "MyModule"
                ModuleBase = "TestDrive:\MyModule\"
                CopyDirectories = @()
                Encoding = "UTF8"
                PublicFilter = "Public\*.ps1"
            }
        }

        Mock Test-Path {$True} -Parameter {$Path -eq "TestDrive:\1.0.0"} -ModuleName ModuleBuilder
        Mock Remove-Item {} -Parameter {$Path -eq "TestDrive:\1.0.0"} -ModuleName ModuleBuilder
        Mock Set-Location {} -ModuleName ModuleBuilder
        Mock Copy-Item {} -ModuleName ModuleBuilder

        Mock Get-ChildItem {
            [IO.FileInfo]$(Join-Path $(Convert-Path "TestDrive:\") "MyModule\Public\Get-MyInfo.ps1")
        } -ModuleName ModuleBuilder

        Mock Get-Item {
            [PSCustomObject]@{ LastWriteTime = Get-Date }
        } -ModuleName ModuleBuilder

        Mock New-Item {} -Parameter {
            $Path -eq "TestDrive:\1.0.0" -and
            $ItemType -eq "Directory" -and
            $Force -eq $true
        } -ModuleName ModuleBuilder

        try {
            Build-Module -Target Build
        } finally {
            Pop-Location -StackName BuildModuleTest
        }

        # NOTE: We're not just clearing output, but the whole folder
        It "Should NOT remove the output folder" {
            Assert-MockCalled Remove-Item -ModuleName ModuleBuilder -Times 0
        }

        It "Should check the dates on the output" {
            Assert-MockCalled Get-Item -ModuleName ModuleBuilder -Times 1
        }

        It "Should not (re)create the OutputDirectory" {
            Assert-MockCalled New-Item -ModuleName ModuleBuilder -Times 0
        }

        It "Should not rebuild the source files" {
            Assert-MockCalled SetModuleContent -ModuleName ModuleBuilder -Times 0
        }
    }
}