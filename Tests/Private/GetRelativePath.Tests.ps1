#requires -Module ModuleBuilder
Describe "GetRelativePath" {
    . $PSScriptRoot\..\Convert-FolderSeparator.ps1
    $CommandInfo = InModuleScope ModuleBuilder { Get-Command GetRelativePath }

    Context "All Parameters are mandatory" {

        It "has a mandatory string RelativeTo parameter" {
            $RelativeTo = $CommandInfo.Parameters['RelativeTo']
            $RelativeTo | Should -Not -BeNullOrEmpty
            $RelativeTo.ParameterType | Should -Be ([String])
            $RelativeTo.Attributes.Where{ $_ -is [Parameter] }.Mandatory | Should -Be $True
        }

        It "has a mandatory string Path parameter" {
            $Path = $CommandInfo.Parameters['Path']
            $Path | Should -Not -BeNullOrEmpty
            $Path.ParameterType | Should -Be ([string])
            $Path.Attributes.Where{ $_ -is [Parameter] }.Mandatory | Should -Be $True
        }
    }

    # I'm not going to bother writing tests for this other than "it's the same as .NET's"
    if ([System.IO.Path]::GetRelativePath) {
        Context "The output always matches [System.IO.Path]::GetRelativePath" {
            $TestCases = @(
                @{ RelativeTo = "G:\Module"; Path = "G:\Module\Source" }
                @{ RelativeTo = "G:\Module"; Path = "G:\Module\Source\Public" }
                @{ RelativeTo = "G:\Module\Source"; Path = "G:\Module\Output" }
                @{ RelativeTo = "G:\Module\Source"; Path = "G:\Module\Output\" }
                @{ RelativeTo = "G:\Module\Source\"; Path = "G:\Module\Output\" }
                @{ RelativeTo = "G:\Module\Source\"; Path = "G:\Module\Output" }
                @{ RelativeTo = "G:\Projects\Modules\MyModule\Source\Public"; Path = "G:\Modules\MyModule" }
                @{ RelativeTo = "G:\Projects\Modules\MyModule\Source\Public"; Path = "G:\Projects\Modules\MyModule" }
                # These ones are backwards, but they still work
                @{ RelativeTo = "G:\Module\Source" ; Path = "G:\Module" }
                @{ RelativeTo = "G:\Module\Source\Public"; Path = "G:\Module" }
                # These are linux-like:
                @{ RelativeTo = "/mnt/c/Users/Jaykul/Projects/Modules/ModuleBuilder"; Path = "/mnt/c/Users/Jaykul/Projects/Modules/ModuleBuilder/Source"; }
                @{ RelativeTo = "/mnt/c/Users/Jaykul/Projects/Modules/ModuleBuilder"; Path = "/mnt/c/Users/Jaykul/Projects/Output"; }
                @{ RelativeTo = "/mnt/c/Users/Jaykul/Projects/Modules/ModuleBuilder"; Path = "/mnt/c/Users/Jaykul/Projects/"; }
                # Weird PowerShell Paths
                @{ RelativeTo = "TestDrive:/Projects/Modules/ModuleBuilder"; Path = "TestDrive:\Projects" }
                @{ RelativeTo = "TestDrive:/Projects/Modules/ModuleBuilder"; Path = "TestDrive:/Projects" }
                @{ RelativeTo = "TestDrive:/Projects"; Path = "TestDrive:/Projects/Modules/ModuleBuilder" }
            )

            # On Windows, there's a shortcut when the path points to totally different drive letters:
            if ($PSVersionTable.Platform -eq "Win32NT") {
                $TestCases += @(
                    @{ RelativeTo = "G:\Projects\Modules\MyModule\Source\Public"; Path = "C:\Modules\MyModule" }
                    @{ RelativeTo = "G:\Projects\Modules\MyModule\Source\Public"; Path = "F:\Projects\Modules\MyModule" }
                )
            }

            It "Returns the same result as Path.GetRelativePath for <Path>" -TestCases $TestCases {
                param($RelativeTo, $Path)
                $RelativeTo = Convert-FolderSeparator $RelativeTo
                $Path = Convert-FolderSeparator $Path
                # Write-Verbose $Path -Verbose
                $Expected = [System.IO.Path]::GetRelativePath($RelativeTo, $Path)
                & $CommandInfo $RelativeTo $Path | Should -Be $Expected
            }
        }
    }
}
