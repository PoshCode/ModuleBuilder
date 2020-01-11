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
    # Make we can always look things up in BoundParameters
    $BoundParameters = if ($BuildCommandInvocation.BoundParameters) {
        $BuildCommandInvocation.BoundParameters
    } else {
        @{}
    }

    # Combine the defaults with parameter values
    $ParameterValues = @{}
    if ($BuildCommandInvocation) {
        foreach ($parameter in $BuildParameters.GetEnumerator().Where({$_.Key -notin $CommonParameters})) {
            Write-Debug "  Parameter: $($parameter.key)"
            $key = $parameter.Key

            # We want to map the parameter aliases to the parameter name:
            foreach ($k in @($parameter.Value.Aliases)) {
                if ($null -ne $k -and $BuildInfo.ContainsKey($k)) {
                    Write-Debug "    ... Update BuildInfo[$key] from $k"
                    $BuildInfo[$key] = $BuildInfo[$k]
                    $null = $BuildInfo.Remove($k)
                }
            }
            # !$BuildInfo.ContainsKey($key) -or $BoundParameters.ContainsKey($key)

            # The SourcePath is special: we overwrite the parameter value with the Build.psd1 value
            # Otherwise, we overwrite build.psd1 values with bound parameters values
            if (($key -ne "SourcePath" -or -not $BuildInfo.SourcePath) -and (-not $BuildInfo.ContainsKey($key) -or $BoundParameters.ContainsKey($key))) {
                if ($null -ne ($value = Get-Variable -Name $key -ValueOnly -ErrorAction Ignore )) {
                    if ($value -ne ($null -as $parameter.Value.ParameterType)) {
                        $ParameterValues[$key] = $value
                    }
                }
                if ($BoundParameters.ContainsKey($key)) {
                    Write-Debug "    From Parameter: $($ParameterValues[$key] -join ', ')"
                } elseif ($ParameterValues[$key]) {
                    Write-Debug "    From Default: $($ParameterValues[$key] -join ', ')"
                }
            } elseif ($BuildInfo[$key]) {
                Write-Debug "    From Manifest: $($BuildInfo[$key] -join ', ')"
            }
        }
    }
    Write-Debug "Finished parsing Build Manifest $BuildManifest"

    $BuildInfo = $BuildInfo | Update-Object $ParameterValues

    # Resolve Build Manifest's parent folder to find the Absolute path
    $BuildManifestParent = (Split-Path -Parent $BuildManifest)

    # Resolve Module manifest if not defined in Build.psd1
    if (-Not $BuildInfo.SourcePath -and $BuildManifestParent) {
        # Resolve Build Manifest's parent folder to find the Absolute path
        $ModuleName = Split-Path -Leaf $BuildManifestParent

        # If we're in a "well known" source folder, look higher for a name
        if ($ModuleName -in 'Source', 'src') {
            $ModuleName = Split-Path (Split-Path -Parent $BuildManifestParent) -Leaf
        }

        # As the Module Manifest did not specify the Module manifest, we expect the Module manifest in same folder
        $SourcePath = Join-Path $BuildManifestParent "$ModuleName.psd1"
        Write-Debug "Updating BuildInfo SourcePath to $SourcePath"
        $BuildInfo = $BuildInfo | Update-Object @{ SourcePath = $SourcePath }
    }

    # Make sure the Path is set and points at the actual manifest, relative to Build.psd1 or absolute
    if (!(Split-Path -IsAbsolute $BuildInfo.SourcePath) -and $BuildManifestParent) {
        $BuildInfo.SourcePath = Join-Path $BuildManifestParent $BuildInfo.SourcePath | Convert-Path
    } else {
        $BuildInfo.SourcePath = Convert-Path $BuildInfo.SourcePath
    }

    if (!(Test-Path $BuildInfo.SourcePath)) {
        throw "Can't find module manifest at the specified SourcePath: $($BuildInfo.SourcePath)"
    }

    $BuildInfo
}
