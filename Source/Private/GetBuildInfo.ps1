function GetBuildInfo {
    [CmdletBinding()]
    param(
        # The path to the Build Manifest Build.psd1
        [Parameter(Mandatory)]
        [ValidateScript( {
                if ((Test-Path $_) -and (Split-path -Leaf $_) -eq 'build.psd1') {
                    $true
                }
                else {
                    throw "The Module Manifest must point to a valid build.psd1 Data file"
                }
            })]
        [string]$BuildManifest,

        # Pass MyInvocation from the Build-Command so we can read parameter values
        [Parameter(DontShow)]
        [AllowNull()]
        $BuildCommandInvocation
    )

    # Read the Module Manifest configuration file for default parameter values
    Write-Debug "Load Build Manifest $BuildManifest"
    $BuildInfo = Import-Metadata -Path $BuildManifest
    $CommonParameters = [System.Management.Automation.Cmdlet]::CommonParameters +
                        [System.Management.Automation.Cmdlet]::OptionalCommonParameters
    $BuildParameters = $BuildCommandInvocation.MyCommand.Parameters

    # Combine the defaults with parameter values
    $ParameterValues = @{}
    if ($BuildCommandInvocation) {
        foreach ($parameter in $BuildParameters.GetEnumerator().Where({$_.Key -notin $CommonParameters})) {
            Write-Debug "  Parameter: $($parameter.key)"
            $key = $parameter.Key
            # set if it doesn't exist, overwrite if the value is bound as a parameter
            if (!$BuildInfo.ContainsKey($key) -or ($BuildCommandInvocation.BoundParameters -and $BuildCommandInvocation.BoundParameters.ContainsKey($key))) {
                if ($null -ne ($value = Get-Variable -Name $key -ValueOnly -ErrorAction Ignore )) {
                    if ($value -ne ($null -as $parameter.Value.ParameterType)) {
                        $ParameterValues[$key] = $value
                    }
                }
            } else {
                Write-Debug "    From Manifest: $($BuildInfo.$key)"
            }
            Write-Debug "    From Parameter: $($ParameterValues.$key)"
        }
    }

    $BuildInfo = $BuildInfo | Update-Object $ParameterValues

    # Resolve Build Manifest's parent folder to find the Absolute path
    $BuildManifestParent = (Split-Path -Parent $BuildManifest)

    # Resolve Module manifest if not defined in Build.psd1
    if (-Not $BuildInfo.ModuleManifest) {
        $ModuleName = Split-Path -Leaf $BuildManifestParent

        # If we're in a "well known" source folder, look higher for a name
        if ($ModuleName -in 'Source', 'src') {
            $ModuleName = Split-Path (Split-Path -Parent $BuildManifestParent) -Leaf
        }

        # As the Module Manifest did not specify the Module manifest, we expect the Module manifest in same folder
        $ModuleManifest = Join-Path $BuildManifestParent "$ModuleName.psd1"
        Write-Debug "Updating BuildInfo path to $ModuleManifest"
        $BuildInfo = $BuildInfo | Update-Object @{ModuleManifest = $ModuleManifest }
    }

    # Make sure the Path is set and points at the actual manifest, relative to Build.psd1 or absolute
    if(!(Split-Path -IsAbsolute $BuildInfo.ModuleManifest)) {
        $BuildInfo.ModuleManifest = Join-Path $BuildManifestParent $BuildInfo.ModuleManifest
    }

    if (!(Test-Path $BuildInfo.ModuleManifest)) {
        throw "Can't find module manifest at $($BuildInfo.ModuleManifest)"
    }

    $BuildInfo
}
