function GetBuildInfo {
    [CmdletBinding()]
    param(
        # The root folder where the module source is (including the Build.psd1 and the module Manifest.psd1)
        [Alias("BuildManifest")]
        [string]$SourcePath = $(Get-Location -PSProvider FileSystem),

        # Pass the invocation from the parent in, so InitializeBuild can read parameter values
        [Parameter(DontShow)]
        $Invocation = $(Get-Variable Invocation -Scope 1 -ValueOnly -ErrorAction SilentlyContinue)
    )

    if ( (Split-Path $SourcePath -Leaf) -eq 'build.psd1') {
        $BuildManifest = $SourcePath
    }
    elseif (Test-Path $SourcePath -PathType Leaf) {
        # $ModuleManifest = $SourcePath
        # When you pass the ModuleManifest as parameter, you must have the Build Manifest in the same folder
        $BuildManifest = Join-Path (Split-Path -Parent $SourcePath) [Bb]uild.psd1
    }
    else {
        # It's a container, assume the Build Manifest is directly under
        $BuildManifest = Join-Path $SourcePath [Bb]uild.psd1
    }

    if ( -Not (Test-Path $BuildManifest) ) {
        throw "Couldn't find the Build Manifest at $BuildManifest"
    }

    # Read the build.psd1 configuration file for default parameter values
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

    # Resolve Module manifest if not defined in Build.psd1
    if (-Not $BuildInfo.Path) {
        # Resolve Build Manifest's parent folder to find the Absolute path, and validate the ModuleManifest file exists
        $BuildManifestParent = (Resolve-Path (Split-Path -Parent $BuildManifest)).Path
        $ModuleName = Split-Path -Leaf $BuildManifestParent

        # If we're in a "well known" source folder, look higher for a name
        if ($ModuleName -in 'Source', 'src') {
            $ModuleName = Split-Path (Split-Path -Parent $BuildManifestParent) -Leaf
        }

        # As the Module Manifest did not specify the Module manifest, we expect the Module manifest in same folder
        $ModuleManifest = Join-Path . "$ModuleName.psd1"
        $BuildInfo = $BuildInfo | Update-Object @{Path = $ModuleManifest }
    }

    # Make sure the Path is set and points at the actual manifest, relative to Build.psd1 or absolute
    Write-Verbose "Pushing the location to the Build.psd1 parent folder"
    Push-Location -Path (Split-Path -Parent $BuildManifest) -StackName Build-Module

    if (!(Test-Path $BuildInfo.Path)) {
        Pop-Location -StackName Build-Module
        throw "Can't find module manifest at $($BuildInfo.Path)"
    }

    $BuildInfo
}