using namespace Microsoft.PowerShell.Commands
<#
.SYNOPSIS
    Installs and imports modules listed in RequiredModules if they're missing
.EXAMPLE
    .\bootstrap

    Run the bootstrap interactively, with a prompt for each module to be installed
.EXAMPLE
    .\bootstrap -Confirm:$false

    Run the bootstrap and install all the modules without prompting
#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="High")]
param(
    # Override the default scope if you wish -- now that PowerShellGet has sane defaults, we use their default
    [ValidateSet("CurrentUser", "AllUsers")]
    $Scope = "CurrentUser"
)
[ModuleSpecification[]]$RequiredModules = Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName RequiredModules

# Force Policy to Trusted so we can install without prompts and without -Force which is bad
$Policy = (Get-PSRepository PSGallery).InstallationPolicy
Set-PSRepository PSGallery -InstallationPolicy Trusted
try {
    # Check for the modules by hand so that "RequiredVersion" is treated as "MinimumVersion"
    $RequiredModules.Where{
        -not (Get-Module $_.Name -ListAvailable | Where-Object Version -ge $_.RequiredVersion)
    } |
    # Install missing modules with -AlloClobber and -SkipPublisherCheck because PowerShellGet requires both
    Install-Module -Scope $Scope -Repository PSGallery -SkipPublisherCheck -AllowClobber -Verbose -Confirm:$($ConfirmPreference -ne "None")
# Put Policy back so we don't needlessly change environments permanently
} finally {
    Set-PSRepository PSGallery -InstallationPolicy $Policy
}

# Since we're now allowing newer versions, import the newest available
$RequiredModules.ForEach{
    Get-Module $_.Name -ListAvailable | Sort-Object Version | Select-Object -Last 1
} | Import-Module