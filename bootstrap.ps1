[CmdletBinding()]
param(
    #
    [ValidateSet("CurrentUser", "AllUsers", "LocalTools")]
    $Scope = "CurrentUser"
)

Push-Location $PSScriptRoot -StackName bootstrap-stack

# # This would probably work, if the default gallery was trusted ...
# Install-Module Pester        -RequiredVersion 4.4.0 -Scope CurrentUser -Repository PSGallery -SkipPublisherCheck
# Install-Module Configuration -RequiredVersion 1.3.1 -Scope CurrentUser -Repository PSGallery -SkipPublisherCheck
if (!(Get-Module PSDepend -ListAvailable)) {
    $Policy = (Get-PSRepository PSGallery).InstallationPolicy
    try {
        Set-PSRepository PSGallery -InstallationPolicy Trusted

        if ($Scope -eq "LocalTools") {
            $Target = Join-Path $PSScriptRoot "Tools"
            New-Item -Path $Target -ItemType Directory -Force

            $Env:PSModulePath += ';' + $Target
            $PSDefaultParameterValues["Invoke-PSDepend:Target"] = $Target
            Save-Module PSDepend -Repository PSGallery -ErrorAction Stop -Path $Target
        } else {
            $PSDefaultParameterValues["Invoke-PSDepend:Target"] = $Scope
            Install-Module PSDepend -Repository PSGallery -ErrorAction Stop -Scope:$Scope
        }
    } finally {
        # Make sure we didn't change anything permanently
        Set-PSRepository PSGallery -InstallationPolicy:$Policy
        Pop-Location -StackName bootstrap-stack
    }
}

try {
    Write-Verbose "Updating dependencies"
    Import-Module PSDepend -ErrorAction Stop
    Invoke-PSDepend -Import -Force -ErrorAction Stop -Verbose
} catch {
    Write-Warning "Unable to restore dependencies. Please review errors:"
    throw
}
