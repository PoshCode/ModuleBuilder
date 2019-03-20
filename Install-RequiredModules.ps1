<#PSScriptInfo

.VERSION 1.0.0

.GUID 6083ddaa-3951-4482-a9f7-fe115ddf8021

.AUTHOR Joel 'Jaykul' Bennett

.COMPANYNAME PoshCode

.COPYRIGHT Copyright 2019, Joel Bennett

.TAGS Install Modules Development ModuleBuilder

.LICENSEURI https://github.com/PoshCode/ModuleBuilder/blob/master/LICENSE

.PROJECTURI https://github.com/PoshCode/ModuleBuilder/

.ICONURI https://github.com/PoshCode/ModuleBuilder/blobl/resources/images/install.png

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
This is the first public release - it probably doesn't work right

.PRIVATEDATA

#>

<#
.SYNOPSIS
    Installs (and imports) modules listed in RequiredModules.psd1
.DESCRIPTION
    Parses a RequiredModules.psd1 listing modules and attempts to import those modules.
    If it can't find the module in the PSModulePath, attempts to install it from PowerShellGet.

    The RequiredModules list looks like this (uses nuget version range syntax):
    @{
        "PowerShellGet" = "2.0.4"
        "Configuration" = "[1.3.1,2.0)"
        "Pester"        = "[4.4.2,4.7.0]"
    }

    https://docs.microsoft.com/en-us/nuget/reference/package-versioning#version-ranges-and-wildcards

.EXAMPLE
    Install-RequiredModules

    Runs the install interactively:
    - reads the default 'RequiredModules.psd1' from the current folder
    - prompts for each module that needs to be installed
.EXAMPLE
    Save-Script Install-RequiredModules -Path .
    .\Install-RequiredModules.ps1 -Path .\RequiredModules.psd1 -Confirm:$false

    This example shows how to use this in a build where you're downloading the script
    and then running it in automation (without "confirm" prompting)
#>
using namespace Microsoft.PackageManagement.Provider.Utility
using namespace Microsoft.PowerShell.Commands
#Requires -Module PowerShellGet

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="High")]
param(
    # The path to a metadata file listing required modules. Defaults to "RequiredModules.psd1" (in the current working directory).
    [Parameter(ParameterSetName="FromFile", Position = 0)]
    [Alias("Path")]
    [string]$RequirementsFile = "RequiredModules.psd1",

    # The scope in which to install the modules (defaults to "CurrentUser")
    [ValidateSet("CurrentUser", "AllUsers")]
    $Scope = "CurrentUser"
)

begin {
    Write-Progress "Installing Required Modules from $RequirementsFile" -Id 0
    # we use this little hack to ensure NuGet types are available
    if (-not ("DependencyVersion" -as [Type])) {
        &(Get-Module PowerShellGet) {
            [CmdletBinding()]param()
            Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -BootstrapNuGetExe
            $null = [Reflection.Assembly]::LoadFile( $NuGetExePath )
        }
    }

    filter GetModuleVersion {
        # PowerShell does the wrong thing with MaximumVersion so we get all versions and check them
        [CmdletBinding()]param(
            [Parameter(ValueFromPipelineByPropertyName)][string]$Name,
            [Parameter(ValueFromPipelineByPropertyName)][DependencyVersion]$Version
        )
        Write-Progress "Searching PSModulePath for '$Name' module with version '$Version'" -Id 1 -ParentId 0

        if (!($Found = Get-Module $Name -ListAvailable | Where-Object {
            $ModuleVersion = [SemanticVersion]$_.Version
            ($null -eq $Version.MinVersion -or ($ModuleVersion -ge $Version.MinVersion -and ($Version.IsMinInclusive -or $ModuleVersion -gt $Version.MinVersion))) -and
            ($null -eq $Version.MaxVersion -or ($ModuleVersion -le $Version.MaxVersion -and ($Version.IsMaxInclusive -or $ModuleVersion -lt $Version.MaxVersion)))
        } |
        # Get returns modules in PSModulePath and then Version order, you're not necessarily getting the highest valid version
        Select-Object -First 1))  {
            Write-Warning "Unable to find module '$Name' installed with version '$Version'"
        } else {
            Write-Verbose "Found '$Name' installed already with version '$($Found.Version)'"
            $Found
        }
    }

    filter FindModuleVersion {
        # PowerShellGet also does the wrong thing with MaximumVersion so we get all versions and check them
        [CmdletBinding()]param(
            [Parameter(ValueFromPipelineByPropertyName)][string]$Name,
            [Parameter(ValueFromPipelineByPropertyName)][DependencyVersion]$Version
        )
        Write-Progress "Searching PSRepository for '$Name' module with version '$Version'" -Id 1 -ParentId 0

        if (!($Found = Find-Module -Name $Name -AllVersions | Where-Object {
            $ModuleVersion = [SemanticVersion]$_.Version
            ($null -eq $Version.MinVersion -or ($ModuleVersion -ge $Version.MinVersion -and ($Version.IsMinInclusive -or $ModuleVersion -gt $Version.MinVersion))) -and
            ($null -eq $Version.MaxVersion -or ($ModuleVersion -le $Version.MaxVersion -and ($Version.IsMaxInclusive -or $ModuleVersion -lt $Version.MaxVersion)))
        } |
        # Find returns modules in version order, so this is the highest valid version
        Select-Object -First 1)) {
            Write-Warning "Unable to resolve dependency '$Name' with version '$Version'"
        } else {
            Write-Verbose "Found '$Name' to install with version '$($Found.Version)'"
            $Found
        }
    }

    function Import-Requirements {
        # Load a requirements file
        [CmdletBinding()]param(
            $RequirementsFile=$RequirementsFile
        )

        $RequirementsFile = Convert-Path $RequirementsFile
        Write-Progress "Loading Required Module list from '$RequirementsFile'" -Id 1 -ParentId 0
        $LocalizedData = @{
            BaseDirectory = [IO.Path]::GetDirectoryName($RequirementsFile)
            FileName = [IO.Path]::GetFileNameWithoutExtension($RequirementsFile)
        }
        (Import-LocalizedData @LocalizedData).GetEnumerator().ForEach({
            [PSCustomObject]@{
                Name = $_.Key
                Version = [DependencyVersion]::ParseDependencyVersion($_.Value)
            }
        })
    }

    Write-Progress "Verifying PSRepository trust" -Id 1 -ParentId 0

    # Force Policy to Trusted so we can install without prompts and without -Force which is bad
    # TODO: Add support for all registered PSRepositories
    if ('Trusted' -ne ($Policy = (Get-PSRepository PSGallery).InstallationPolicy)) {
        Set-PSRepository PSGallery -InstallationPolicy Trusted
    }
}
end {
    $Preferences = @{
        Verbose = $VerbosePreference -eq "Continue"
        Confirm = $ConfirmPreference -ne "None"
    }

    try {
        foreach ($module in Import-Requirements -OV Modules | Where-Object { -not ($_ | GetModuleVersion -WarningAction SilentlyContinue) } | FindModuleVersion) {
            Write-Progress "Installing module '$($module.Name)' with version '$($module.Version)' from the PSGallery"
            # Install missing modules with -AllowClobber and -SkipPublisherCheck because PowerShellGet requires both
            $module | Install-Module -Scope $Scope -Repository PSGallery -SkipPublisherCheck -AllowClobber @Preferences
        }
    # Put Policy back so we don't needlessly change environments permanently
    } finally {
        if ('Trusted' -ne $Policy) {
            Set-PSRepository PSGallery -InstallationPolicy $Policy
        }
    }
    Write-Progress "Importing Modules" -Id 1 -ParentId 0

    $Modules | GetModuleVersion | Import-Module

    Write-Progress "Done" -Id 0 -Completed
}