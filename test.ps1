#requires -Module PowerShellGet, Pester
using namespace Microsoft.PackageManagement.Provider.Utility
param(
    [switch]$SkipCodeCoverage,
    [switch]$HideSuccess
    [switch]$IncludeVSCodeMarker
)
Push-Location $PSScriptRoot
$ModuleUnderTest = Split-Path $PSScriptRoot -Leaf

# Disable default parameters during testing, just in case
$PSDefaultParameterValues += @{}
$PSDefaultParameterValues["Disabled"] = $true

# Find a built module as a version-numbered folder:
$FullModulePath = Get-ChildItem [0-9]* -Directory | Sort-Object { $_.Name -as [SemanticVersion[]] } |
    Select-Object -Last 1 -Ov Version |
    Get-ChildItem -Filter "$($ModuleUnderTest).psd1"

    if(!$FullModulePath) {
        throw "Can't find $($ModuleUnderTest).psd1 in $($Version.FullName)"
    }

$Show = if ($HideSuccess) {
    "Fails"
} else {
    "All"
}

Remove-Module (Split-Path $ModuleUnderTest -Leaf) -ErrorAction Ignore -Force
$ModuleUnderTest = Import-Module $FullModulePath -PassThru -Force -DisableNameChecking -Verbose:$false
Write-Host "Invoke-Pester for Module $($ModuleUnderTest) version $($ModuleUnderTest.Version)"

if (-not $SkipCodeCoverage) {
    # Get code coverage for the psm1 file to a coverage.xml that we can mess with later
    Invoke-Pester (Join-Path $PSScriptRoot Tests) -CodeCoverage $ModuleUnderTest.Path -CodeCoverageOutputFile ./coverage.xml -Show $Show -PesterOption @{ IncludeVSCodeMarker = $IncludeVSCodeMarker }
} else {
    Invoke-Pester (Join-Path $PSScriptRoot Tests) -Show $Show -PesterOption @{ IncludeVSCodeMarker = $IncludeVSCodeMarker }
}

Pop-Location

# Re-enable default parameters after testing
$PSDefaultParameterValues["Disabled"] = $false
