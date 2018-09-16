[CmdletBinding()]
param(
    [ValidateSet("CurrentUser", "AllUsers")]
    $Scope="CurrentUser"
)

Push-Location $PSScriptRoot

# # This really does work, but using PSDepends is a lot smoother when there's more modules, or nuget packages
# Install-Module Pester        -RequiredVersion 4.4.0 -Scope CurrentUser -Repository PSGallery -SkipPublisherCheck
# Install-Module Configuration -RequiredVersion 1.3.1 -Scope CurrentUser -Repository PSGallery -SkipPublisherCheck

# Here's one example of why PowerShellGet is so awkward: their default gallery is not be trusted by default!
$Policy = (Get-PSRepository PSGallery).InstallationPolicy
Set-PSRepository PSGallery -InstallationPolicy Trusted
try {
    Install-Module PSDepend -RequiredVersion 0.2.5 -Scope:$Scope -Repository PSGallery -ErrorAction Stop
} finally {
    # Make sure we didn't change anything permanently
    Set-PSRepository PSGallery -InstallationPolicy:$Policy
}
Import-Module  PSDepend -RequiredVersion 0.2.5