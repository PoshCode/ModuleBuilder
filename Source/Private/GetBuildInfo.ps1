function GetBuildInfo {
    [CmdletBinding()]
    param(
        # The path to the Build Manifest Build.psd1
        [Parameter()][AllowNull()]
        [string]$BuildManifest,

        # Pass MyInvocation from the Build-Command so we can read parameter values
        [Parameter(DontShow)]
        [AllowNull()]
        $BuildCommandInvocation
    )

    $BuildInfo = if ($BuildManifest -and (Test-Path $BuildManifest)) {
        if ((Split-path -Leaf $BuildManifest) -eq 'build.psd1') {
            # Read the Module Manifest configuration file for default parameter values
            Write-Debug "Load Build Manifest $BuildManifest"
            Import-Metadata -Path $BuildManifest
        } else {
            @{ SourcePath = $BuildManifest }
        }
    } else {
        @{}
    }

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

    $BuildManifestParent = if ($BuildManifest) {
        Split-Path -Parent $BuildManifest
    } else {
        Get-Location -PSProvider FileSystem
    }

    # Resolve Module manifest if not defined in Build.psd1 or there's no Build.psd1
    if (-Not $BuildInfo.SourcePath) {
        # Find a module manifest (or maybe several)
        $ModuleInfo = Get-ChildItem $BuildManifestParent -Recurse -Filter *.psd1 -ErrorAction SilentlyContinue |
            ImportModuleManifest -ErrorAction SilentlyContinue
        # If we found more than one module info, the only way we have of picking just one is if it matches a folder name
        if (@($ModuleInfo).Count -gt 1) {
            # Resolve Build Manifest's parent folder to find the Absolute path
            $ModuleName = Split-Path -Leaf $BuildManifestParent
            # If we're in a "well known" source folder, look higher for a name
            if ($ModuleName -in 'Source', 'src') {
                $ModuleName = Split-Path (Split-Path -Parent $BuildManifestParent) -Leaf
            }
            $ModuleInfo = @($ModuleInfo).Where{ $_.Name -eq $ModuleName }
        }
        if (@($ModuleInfo).Count -eq 1) {
            Write-Debug "Updating BuildInfo SourcePath to $SourcePath"
            $BuildInfo = $BuildInfo | Update-Object @{ SourcePath = $ModuleInfo.Path }
        }
        if (-Not $BuildInfo.SourcePath) {
            throw "Can't find a module manifest in $BuildManifestParent"
        }
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
