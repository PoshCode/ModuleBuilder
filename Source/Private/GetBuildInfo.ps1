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

        # Pass the invocation from the parent in, so InitializeBuild can read parameter values
        [Parameter(DontShow)]
        [AllowNull()]
        $Invocation = $(Get-Variable Invocation -Scope 1 -ValueOnly -ErrorAction SilentlyContinue)
    )

    # Read the Module Manifest configuration file for default parameter values
    $BuildInfo = Import-Metadata -Path $BuildManifest

    # Combine the defaults with parameter values
    $ParameterValues = @{}
    if ($Invocation) {
        foreach ($parameter in $Invocation.MyCommand.Parameters.GetEnumerator()) {
            $key = $parameter.Key
            # set if it doesn't exist, overwrite if the value is bound as a parameter
            if (!$BuildInfo.ContainsKey($key) -or ($Invocation.BoundParameters -and $Invocation.BoundParameters.ContainsKey($key))) {
                if ($null -ne ($value = Get-Variable -Name $key -ValueOnly -ErrorAction Ignore )) {
                    if ($value -ne ($null -as $parameter.Value.ParameterType)) {
                        Write-Debug "    $key = $value"
                        $ParameterValues[$key] = $value
                    }
                }
            }
        }
    }

    $BuildInfo = $BuildInfo | Update-Object $ParameterValues

    # Resolve Build Manifest's parent folder to find the Absolute path
    $BuildManifestParent = (Split-Path -Parent $BuildManifest)

    # Resolve Module manifest if not defined in Build.psd1
    if (-Not $BuildInfo.Path) {
        $ModuleName = Split-Path -Leaf $BuildManifestParent

        # If we're in a "well known" source folder, look higher for a name
        if ($ModuleName -in 'Source', 'src') {
            $ModuleName = Split-Path (Split-Path -Parent $BuildManifestParent) -Leaf
        }

        # As the Module Manifest did not specify the Module manifest, we expect the Module manifest in same folder
        $ModuleManifest = Join-Path $BuildManifestParent "$ModuleName.psd1"
        Write-Debug "Updating BuildInfo path to $ModuleManifest"
        $BuildInfo = $BuildInfo | Update-Object @{Path = $ModuleManifest }
    }

    # Make sure the Path is set and points at the actual manifest, relative to Build.psd1 or absolute
    Write-Verbose "Pushing the location to the Build manifest's parent folder ($BuildManifestParent)"
    Push-Location -Path $BuildManifestParent -StackName Build-Module

    # Validate the ModuleManifest file exists
    if (!(Test-Path $BuildInfo.Path)) {
        Pop-Location -StackName Build-Module -ErrorAction SilentlyContinue
        throw "Can't find module manifest at $($BuildInfo.Path)"
    }

    $BuildInfo
}