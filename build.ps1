[CmdletBinding()]
param(
    $OutputDirectory,

    $ModuleVersion,

    $Repository = 'PSGallery',

    [switch]$UseLocalTools,

    [switch]$Test
)
# Sanitize parameters to pass to Build-Module
$null = $PSBoundParameters.Remove('Repository')
$null = $PSBoundParameters.Remove('Test')
$null = $PSBoundParameters.Remove('UseLocalTools')
$ParameterString = $PSBoundParameters.GetEnumerator().ForEach{ '-' + $_.Key + " '" + $_.Value + "'" } -join " "

Write-Verbose "BUILDING $(Split-Path $PSScriptRoot -Leaf) VERSION $ModuleVersion" -Verbose
$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot -StackName BuildBuildModule
try {
    # Restore dependencies
    if (-not (Get-Module PSDepend -ListAvailable)) {
        Write-Verbose "PSDepend not available, bootstrapping from Repository '$Repository'"
        if (-not $UseLocalTools) {
            Install-Module -Name PSDepend -Scope CurrentUser -Confirm:$False -Repository $Repository -Force
        } else {
            $ToolsPath = Join-Path $PSScriptRoot 'Tools'
            Write-Debug "    Saving the PSDepend Module in '$ToolsPath"
            $null = New-Item -Name Tools -ItemType Directory -ErrorAction SilentlyContinue
            Save-Module -Name PSDepend -Repository $Repository -Confirm:$false -Path $ToolsPath -ErrorAction Stop
            Write-Debug "    Adding $ToolsPath to `$Env:PSModulePath"
            if ($env:PSModulePath -split ';' -notcontains $ToolsPath) {
                $env:PSModulePath = $ToolsPath + ';' + $env:PSModulePath
            }
        }
    }
    # PSDepend has a bug where it outputs empty strings for no obvious reason. This is to suppress that:
    Invoke-PSDepend -Path $PSScriptRoot\build.depend.psd1 -Confirm:$false | Where-Object { $_ }
    Import-Module Configuration

    # This is a bootstrapping hack: how do you build ModuleBuilder with ModuleBuilder?
    Write-Verbose "Generating ModuleBuilderBootstrap Module"
    $OFS = "`n`n"
    $Source = Get-ChildItem Source -File -Recurse -Filter *.ps1 |
        Sort-Object DirectoryName, Name |
        Get-Content -Encoding UTF8 -Delimiter ([char]0)
    $Source += "`nExport-ModuleMember -Function *-*"

    Get-Module ModuleBuilderBootstrap -ErrorAction Ignore | Remove-Module
    New-Module ModuleBuilderBootstrap ([ScriptBlock]::Create($Source)) |
        Import-Module -Verbose:$false -DisableNameChecking

    # Build new output
    Write-Verbose "Build-Module Source\build.psd1 $($ParameterString) -Target CleanBuild"
    ModuleBuilderBootstrap\Build-Module Source\build.psd1 @PSBoundParameters -Target CleanBuild -Passthru -OutVariable BuildOutput | Split-Path
    Write-Verbose "Module build output in $(Split-Path $BuildOutput.Path)"

    # Test module
    if($Test) {
        Write-Verbose "Invoke-Pester after importing $($BuildOutput.Path)" -Verbose
        Remove-Module ModuleBuilderBootstrap, ModuleBuilder -ErrorAction SilentlyContinue -Verbose:$false
        $BuildOutput | Import-Module -Verbose:$false -DisableNameChecking
        Invoke-Pester
    }

    # Clean up environment after tests
    Remove-Module ModuleBuilderBootStrap, ModuleBuilder -ErrorAction SilentlyContinue -Verbose:$false

} finally {
    Pop-Location -StackName BuildBuildModule
}
