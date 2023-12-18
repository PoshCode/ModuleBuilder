Describe "SetModuleContent" {

    Context "Necessary Parameters" {
        $CommandInfo = InModuleScope ModuleBuilder { Get-Command SetModuleContent }

        It "has a mandatory string OutputPath parameter" {
            $OutputPath = $CommandInfo.Parameters['OutputPath']
            $OutputPath | Should -Not -BeNullOrEmpty
            $OutputPath.ParameterType | Should -Be ([String])
            $OutputPath.Attributes.Where{$_ -is [Parameter]}.Mandatory | Should -Be $True
        }

        It "has a mandatory string array SourceFile parameter" {
            $SourceFile = $CommandInfo.Parameters['SourceFile']
            $SourceFile | Should -Not -BeNullOrEmpty
            $SourceFile.ParameterType | Should -Be ([String[]])
            $SourceFile.Attributes.Where{$_ -is [Parameter]}.Mandatory | Should -Be $True
        }

        It "has an optional string WorkingDirectory parameter" {
            $WorkingDirectory = $CommandInfo.Parameters['WorkingDirectory']
            $WorkingDirectory | Should -Not -BeNullOrEmpty
            $WorkingDirectory.ParameterType | Should -Be ([String])
            $WorkingDirectory.Attributes.Where{$_ -is [Parameter]}.Mandatory | Should -Be $False
        }

        It "has an optional string Encoding parameter" {
            $Encoding = $CommandInfo.Parameters['Encoding']
            $Encoding | Should -Not -BeNullOrEmpty
            $Encoding.ParameterType | Should -Be ([String])
            $Encoding.Attributes.Where{$_ -is [Parameter]}.Mandatory | Should -Be $False
        }

        $CommandInfo.Parameters['OutputPath']
    }


    Context "Joining files into one" {
        ${global:mock get content index} = 1

        Mock Get-Content -ModuleName ModuleBuilder {
            "Script Content"
            "File $((${global:mock get content index}++))"
            "From $Path"
        }

        Mock Resolve-Path -ModuleName ModuleBuilder {
            $path -replace "TestDrive:\\", ".\"
        } -ParameterFilter { $Relative }



        InModuleScope ModuleBuilder {
            $Files = "TestDrive:\Private\First.ps1",
                     "TestDrive:\Private\Second.ps1",
                     "TestDrive:\Public\Third.ps1"
            SetModuleContent -Source $Files -Output TestDrive:\Output.psm1
        }

        It "Calls get-content on every source file" {
            Assert-MockCalled Get-Content -ModuleName ModuleBuilder -ParameterFilter { $Path -eq ".\Private\First.ps1" }
            Assert-MockCalled Get-Content -ModuleName ModuleBuilder -ParameterFilter { $Path -eq ".\Private\Second.ps1" }
            Assert-MockCalled Get-Content -ModuleName ModuleBuilder -ParameterFilter { $Path -eq ".\Public\Third.ps1" }
        }

        It "Copies all three files into the Output" {
            $Content = Get-Content TestDrive:\Output.psm1 -Raw
            $Content | Should -Match "File 1"
            $Content | Should -Match "First.ps1"

            $Content | Should -Match "File 2"
            $Content | Should -Match "Second.ps1"

            $Content | Should -Match "File 3"
            $Content | Should -Match "Third.ps1"
        }
    }

    Context "Supports adding Prefix and Suffix content" {
        ${global:mock get content index} = 1

        Mock Get-Content -ModuleName ModuleBuilder {
            "Script Content"
            "File $((${global:mock get content index}++))"
            "From $Path"
        }

        Mock Resolve-Path -ModuleName ModuleBuilder {
            if ($path -match "TestDrive:") {
                $path -replace "TestDrive:\\", ".\"
            } else {
                write-error "$path not found"
            }
        } -ParameterFilter { $Relative }


        InModuleScope ModuleBuilder {
            $Files = "using module Configuration",
                     "TestDrive:\Private\First.ps1",
                     "TestDrive:\Private\Second.ps1",
                     "TestDrive:\Public\Third.ps1",
                     "Export-ModuleMember Stuff"
            SetModuleContent -Source $Files -Output TestDrive:\Output.psm1
        }

        It "Calls get-content on every source file" {
            Assert-MockCalled Get-Content -ModuleName ModuleBuilder -ParameterFilter { $Path -eq ".\Private\First.ps1" }
            Assert-MockCalled Get-Content -ModuleName ModuleBuilder -ParameterFilter { $Path -eq ".\Private\Second.ps1" }
            Assert-MockCalled Get-Content -ModuleName ModuleBuilder -ParameterFilter { $Path -eq ".\Public\Third.ps1" }
        }

        It "Copies all three files into the Output" {
            $Content = Get-Content TestDrive:\Output.psm1 -Raw
            $Content | Should -Match "File 1"
            $Content | Should -Match "First.ps1"

            $Content | Should -Match "File 2"
            $Content | Should -Match "Second.ps1"

            $Content | Should -Match "File 3"
            $Content | Should -Match "Third.ps1"
        }

        It "Includes the prefix" {
            $Content = Get-Content TestDrive:\Output.psm1 -Raw
            $Content | Should -Match "#Region 'PREFIX' 0"
            $Content | Should -Match "using module Configuration"
        }

        It "Includes the suffix" {
            $Content = Get-Content TestDrive:\Output.psm1 -Raw
            $Content | Should -Match "#Region 'SUFFIX' 0"
            $Content | Should -Match "Export-ModuleMember Stuff"
        }
    }

    Context "Adds a newline before the content of each script file" {
        ${global:mock get content index} = 1

        Mock Get-Content -ModuleName ModuleBuilder {
            "Script Content"
            "File $((${global:mock get content index}++))"
            "From $Path"
        }

        Mock Resolve-Path -ModuleName ModuleBuilder {
            if ($path -match "TestDrive:") {
                $path -replace "TestDrive:\\", ".\"
            } else {
                write-error "$path not found"
            }
        } -ParameterFilter { $Relative }


        InModuleScope ModuleBuilder {
            $Files = "using module Configuration",
                     "TestDrive:\Private\First.ps1",
                     "TestDrive:\Private\Second.ps1",
                     "TestDrive:\Public\Third.ps1",
                     "Export-ModuleMember Stuff"
            SetModuleContent -Source $Files -Output TestDrive:\Output.psm1
        }

        It "Calls get-content on every source file" {
            Assert-MockCalled Get-Content -ModuleName ModuleBuilder -ParameterFilter { $Path -eq ".\Private\First.ps1" }
            Assert-MockCalled Get-Content -ModuleName ModuleBuilder -ParameterFilter { $Path -eq ".\Private\Second.ps1" }
            Assert-MockCalled Get-Content -ModuleName ModuleBuilder -ParameterFilter { $Path -eq ".\Public\Third.ps1" }
        }

        It "Copies all three files into the Output" {
            $Content = Get-Content TestDrive:\Output.psm1 -Raw
            $Content | Should -Match "File 1"
            $Content | Should -Match "First.ps1"

            $Content | Should -Match "File 2"
            $Content | Should -Match "Second.ps1"

            $Content | Should -Match "File 3"
            $Content | Should -Match "Third.ps1"
        }

        It "Include a new line before the content of each script file" {
            # Replacing CRLF to LF to support cross-platform testing.
            $Content = (Get-Content TestDrive:\Output.psm1 -Raw) -replace '\r?\n', "`n"

            $Content | Should -Match "\#Region\ '\.\\Private\\First\.ps1'\ -1\n{2,}"
            $Content | Should -Match "\#Region\ '\.\\Private\\Second\.ps1'\ -1\n{2,}"
            $Content | Should -Match "\#Region\ '\.\\Public\\Third\.ps1'\ -1\n{2,}"
        }
    }
}
