#requires -Module Configuration
<#
    .Synopsis
        A bootstrapping build, for when an existing ModuleBuilder can't be used to build ModuleBuilder
#>
[CmdletBinding()]
param(
    # A specific folder to build into
    $OutputDirectory,

    # The version of the output module
    [Alias("ModuleVersion")]
    [string]$SemVer
)
# Sanitize parameters to pass to Build-Module
$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot -StackName BuildBuildModule

if (-not $Semver) {
    if ($semver = gitversion -showvariable SemVer) {
        $null = $PSBoundParameters.Add("SemVer", $SemVer)
    }
}

try {
    # Build ModuleBuilder with ModuleBuilder:
    Write-Verbose "Compiling ModuleBuilderBootstrap module"
    $OFS = "`n`n"
    $Source = Get-ChildItem Source -File -Recurse -Filter *.ps1 |
        Sort-Object DirectoryName, Name |
        Get-Content -Encoding UTF8 -Delimiter ([char]0)
    $Source += "`nExport-ModuleMember -Function *-*"

    Get-Module ModuleBuilderBootstrap -ErrorAction Ignore | Remove-Module
    New-Module ModuleBuilderBootstrap ([ScriptBlock]::Create($Source)) |
        Import-Module -Verbose:$false -DisableNameChecking

    # Build new output
    $ParameterString = $PSBoundParameters.GetEnumerator().ForEach{ '-' + $_.Key + " '" + $_.Value + "'" } -join " "
    Write-Verbose "Build-Module build.psd1 $($ParameterString) -Target CleanBuild"
    ModuleBuilderBootstrap\Build-Module -SourcePath build.psd1 @PSBoundParameters -Target CleanBuild -Passthru -OutVariable BuildOutput | Split-Path
    Write-Verbose "Module build output in $(Split-Path $BuildOutput.Path)"

    # Clean up environment
    Remove-Module ModuleBuilderBootStrap -ErrorAction SilentlyContinue -Verbose:$false

} finally {
    Pop-Location -StackName BuildBuildModule
}
