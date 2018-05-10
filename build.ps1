[CmdletBinding()]
param(
    $OutputDirectory = "Output\ModuleBuilder",

    $ModuleVersion = "1.0.0"
)
Write-Verbose "BUILDING $(Split-Path $PSScriptRoot -Leaf) VERSION $ModuleVersion" -Verbose
$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot -StackName BuildBuildModule
try {

    # This is a bootstrap hack:
    Write-Verbose "Bootstrap hack for building ModuleBuilder with ModuleBuilder"
    $OFS = "`n`n"
    $Source = Get-ChildItem Source -Directory | Sort-Object Name |
        Get-ChildItem -File -Filter *.ps1 -Recurse |
        Get-Content

    Get-Module ModuleBuilderBootStrap | Remove-Module
    [ScriptBlock]::Create("
        New-Module ModuleBuilderBootStrap {
            $Source
            Export-ModuleMember -Function *-*
        }
    ").Invoke() | Import-Module -Verbose:$false


    # Restore dependencies
    if (-not (Get-Module PSDepend -ListAvailable)) {
        Install-Module -Name PSDepend -Scope CurrentUser -Confirm:$False -Repository PSGallery -Force
    }
    Invoke-PSDepend -Path $PSScriptRoot\build.depend.psd1 -Confirm:$false
    Import-Module Configuration

    # Clean output if necessary (always)
    Write-Verbose "Cleaning output from $OutputDirectory"
    Get-Item $OutputDirectory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force

    # Build new output
    Write-Verbose "Build-Module ModuleBuilder\Source\build.psd1 -OutputDirectory '$OutputDirectory' -ModuleVersion '$ModuleVersion'"
    ModuleBuilderBootStrap\Build-Module Source\build.psd1 -OutputDirectory $OutputDirectory -ModuleVersion $ModuleVersion

    # Test module
    $ModulePath = (Get-Item $OutputDirectory -Filter *.psd1).FullName
    Write-Verbose "Invoke-Pester after importing module from $ModulePath"
    Remove-Module ModuleBuilderBootStrap, ModuleBuilder -ErrorAction SilentlyContinue  -Verbose:$false
    Import-Module $ModulePath -Verbose:$false

    Invoke-Pester

    # Clean environment after tests
    Remove-Module ModuleBuilderBootStrap, ModuleBuilder -ErrorAction SilentlyContinue

} catch {
    Pop-Location -StackName BuildBuildModule
}
