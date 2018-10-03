[CmdletBinding()]
param(
    $OutputDirectory,

    # The version of the output module
    [Alias("ModuleVersion")]
    [version]$Version,

    $Repository = 'PSGallery',

    [ValidateSet("CurrentUser", "AllUsers", "LocalTools")]
    $InstallToolScope = "CurrentUser",

    [switch]$Test
)

# Sanitize parameters to pass to Build-Module
$null = $PSBoundParameters.Remove('Repository')
$null = $PSBoundParameters.Remove('Test')
$null = $PSBoundParameters.Remove('InstallToolScope')

$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot -StackName BuildBuildModule
try {
    Import-Module Configuration

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
    Write-Verbose "Build-Module Source\build.psd1 $($ParameterString) -Target CleanBuild"
    ModuleBuilderBootstrap\Build-Module Source\build.psd1 @PSBoundParameters -Target CleanBuild -Passthru -OutVariable BuildOutput | Split-Path
    Write-Verbose "Module build output in $(Split-Path $BuildOutput.Path)"

    # Test module
    if($Test) {
        Write-Verbose "Invoke-Pester after importing $($BuildOutput.Path)" -Verbose
        Remove-Module ModuleBuilderBootstrap, ModuleBuilder -ErrorAction SilentlyContinue -Verbose:$false
        Import-Module $BuildOutput.Path -Verbose:$false -DisableNameChecking
        Invoke-Pester -CodeCoverage (Join-Path $BuildOutput.ModuleBase $BuildOutput.RootModule) -PassThru |
            Convert-CodeCoverage -SourceRoot .\Source -Relative
    }

    # Clean up environment after tests
    Remove-Module ModuleBuilderBootStrap, ModuleBuilder -ErrorAction SilentlyContinue -Verbose:$false

} finally {
    Pop-Location -StackName BuildBuildModule
}
