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
$Policy = Get-PSRepository PSGallery -Verbose:$false | Select-Object -ExpandProperty InstallationPolicy
if ($Policy -notlike 'Trusted') {
    Write-Verbose "Temporarily setting 'PSGallery' repository installation policty to 'Trusted'"
    Set-PSRepository PSGallery -InstallationPolicy Trusted
}

try {
    # Check for the modules by hand so that "RequiredVersion" is treated as "MinimumVersion"
    $RequiredModules | ForEach-Object {
        Write-Verbose "Testing system for module '$($_.Name)' (Required Version: '$($_.RequiredVersion)')"
        If (-not (Get-Module $_.Name -ListAvailable -Verbose:$false | Where-Object Version -ge $_.RequiredVersion)) {
            # Install missing modules with -AlloClobber and -SkipPublisherCheck because PowerShellGet requires both
            Install-Module -Name $_.Name -RequiredVersion $_.RequiredVersion `
                -Scope $Scope -Repository PSGallery -SkipPublisherCheck `
                -AllowClobber -Confirm:$($ConfirmPreference -ne "None")
        }
        else {
            Write-Verbose "Found installed module '$($_.Name)' meeting version requirements"
        }
    } 
} 
finally {
    # Restore InstallationPolicy original setting so we don't needlessly change environments permanently
    if ($Policy -notlike 'Trusted') {
        Write-Verbose "Restoring original 'PSGallery' installation policy setting: '$Policy'"
        Set-PSRepository PSGallery -InstallationPolicy $Policy
    }
}

# Since we're now allowing newer versions, import the newest available
$RequiredModules | ForEach-Object {
    $selectedMod = Get-Module -Name $_.Name -ListAvailable -Verbose:$False | 
        Sort-Object Version | Select-Object -Last 1
    if (-NOT $selectedMod) {
        Write-Warning "No module available matching name: '$($_.Name)'"
    }
    else {
        Write-Host "Importing module '$($selectedMod.Name)' version '$($SelectedMod.Version)'"
        Write-Debug "Importing from path: '$($SelectedMod.Path)'"
        Import-Module -Name $selectedMod.Name `
            -RequiredVersion $selectedMod.Version `
            -Force -DisableNameChecking -Verbose:$False
    }
}