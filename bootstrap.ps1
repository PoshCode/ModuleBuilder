#requires -Modules @{ModuleName='PowerShellGet'; ModuleVersion='2.0.0'}

using namespace Microsoft.PowerShell.Commands
[CmdletBinding()]
param(
    # Override the default scope if you wish -- now that PowerShellGet has sane defaults, we use their default
    [ValidateSet("CurrentUser", "AllUsers")]
    $Scope
)
[ModuleSpecification[]]$RequiredModules = Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName RequiredModules
$Policy = (Get-PSRepository PSGallery).InstallationPolicy
Set-PSRepository PSGallery -InstallationPolicy Trusted
try {
    $RequiredModules | Install-Module @PSBoundParameters -Repository PSGallery -SkipPublisherCheck -Verbose
} finally {
    Set-PSRepository PSGallery -InstallationPolicy $Policy
}
$RequiredModules | Import-Module
