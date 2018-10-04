using namespace Microsoft.PowerShell.Commands
[CmdletBinding()]
param(
    #
    [ValidateSet("CurrentUser", "AllUsers")]
    $Scope = "CurrentUser"
)
[ModuleSpecification[]]$RequiredModules = Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName RequiredModules
$Policy = (Get-PSRepository PSGallery).InstallationPolicy
Set-PSRepository PSGallery -InstallationPolicy Trusted

$RequiredModules | Install-Module -Scope $Scope -Repository PSGallery -SkipPublisherCheck -Verbose
$RequiredModules | Import-Module
