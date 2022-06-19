#requires -Module PowerShellGet, @{ ModuleName = "Pester"; ModuleVersion = "4.10.1"; MaximumVersion = "4.999" }
using namespace Microsoft.PackageManagement.Provider.Utility
using namespace System.Management.Automation
param(
    [switch]$SkipScriptAnalyzer,
    [switch]$SkipCodeCoverage,
    [switch]$HideSuccess,
    [switch]$IncludeVSCodeMarker
)
Push-Location $PSScriptRoot
$ModuleName = "ModuleBuilder"

# Disable default parameters during testing, just in case
$PSDefaultParameterValues += @{}
$PSDefaultParameterValues["Disabled"] = $true

# Find a built module as a version-numbered folder:
$FoundModule = Get-ChildItem [0-9]* -Directory | Sort-Object { $_.Name -as [SemanticVersion[]] } |
    Select-Object -Last 1 -Ov Version |
    Get-ChildItem -Filter "$($ModuleName).psd1"

if (!$FoundModule) {
    throw "Can't find $($ModuleName).psd1 in $($Version.FullName)"
}

$Show = if ($HideSuccess) {
    "Fails"
} else {
    "All"
}

Remove-Module $ModuleName -ErrorAction Ignore -Force
$ModuleUnderTest = Import-Module $FoundModule.FullName -PassThru -Force -DisableNameChecking -Verbose:$false
Write-Host "Invoke-Pester for Module $($ModuleUnderTest) version $($ModuleUnderTest.Version)"

if (-not $SkipCodeCoverage) {
    # Get code coverage for the psm1 file to a coverage.xml that we can mess with later
    Invoke-Pester ./Tests -Show $Show -PesterOption @{
        IncludeVSCodeMarker = $IncludeVSCodeMarker
    } -CodeCoverage $ModuleUnderTest.Path -CodeCoverageOutputFile ./coverage.xml -PassThru |
        Convert-CodeCoverage -SourceRoot ./Source
} else {
    Invoke-Pester ./Tests -Show $Show -PesterOption @{ IncludeVSCodeMarker = $IncludeVSCodeMarker }
}

Write-Host
if (-not $SkipScriptAnalyzer) {
    Invoke-ScriptAnalyzer $ModuleUnderTest.Path
}
Pop-Location

# Re-enable default parameters after testing
$PSDefaultParameterValues["Disabled"] = $false
