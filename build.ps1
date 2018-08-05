[CmdletBinding()]
param(
    $OutputDirectory = "Output\ModuleBuilder",

    $ModuleVersion = "1.0.0",

    [switch]
    $UseLocalTools,

    $GalleryToBootstrapFrom = 'PSGallery'
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
        Write-Verbose "PSDepend not available, bootstrapping from Gallery '$GalleryToBootstrapFrom'"
        if (-not $UseLocalTools) {
            Install-Module -Name PSDepend -Scope CurrentUser -Confirm:$False -Repository $GalleryToBootstrapFrom -Force
        } else {
            $ToolsPath = Join-Path $PSScriptRoot 'Tools'
            Write-Debug "    Saving the PSDepend Module in '$ToolsPath"
            $null = New-Item -Name Tools -ItemType Directory -ErrorAction SilentlyContinue
            Save-Module -Name PSDepend -Repository $GalleryToBootstrapFrom -Confirm:$false -Path $ToolsPath -ErrorAction Stop
            Write-Debug "    Adding $ToolsPath to `$Env:PSModulePath"
            if ($env:PSModulePath -split ';' -notcontains $ToolsPath) {
                $env:PSModulePath = $ToolsPath + ';' + $env:PSModulePath
            }
        }
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
