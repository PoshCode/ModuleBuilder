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

    $BuildInfo = if ($BuildManifest -and (Test-Path $BuildManifest) -and (Split-path -Leaf $BuildManifest) -eq 'build.psd1') {
        # Read the build.psd1 configuration file for default parameter values
        Write-Debug "Load Build Manifest $BuildManifest"
        Import-Metadata -Path $BuildManifest
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
            # Bound parameter values > build.psd1 values > default parameters values
            if (-not $BuildInfo.ContainsKey($key) -or $BoundParameters.ContainsKey($key)) {
                # Reading the current value of the $key variable returns either the bound parameter or the default
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
    # BuildInfo.SourcePath should point to a module manifest
    if ($BuildInfo.SourcePath -and $BuildInfo.SourcePath -ne $BuildManifest) {
        $ParameterValues["SourcePath"] = $BuildInfo.SourcePath
    }
    # If SourcePath point to build.psd1, we should clear it
    if ($ParameterValues["SourcePath"] -eq $BuildManifest) {
        $ParameterValues.Remove("SourcePath")
    }
    Write-Debug "Finished parsing Build Manifest $BuildManifest"

    $BuildManifestParent = if ($BuildManifest) {
        Split-Path -Parent $BuildManifest
    } else {
        Get-Location -PSProvider FileSystem
    }

    if ((-not $BuildInfo.SourcePath) -and $ParameterValues["SourcePath"] -notmatch '\.psd1') {
        # Find a module manifest (or maybe several)
        $ModuleInfo = Get-ChildItem -Path $ParameterValues["SourcePath"] -Filter *.psd1 -ErrorAction 'SilentlyContinue' |
            ImportModuleManifest -ErrorAction 'SilentlyContinue'

        if (-not $ModuleInfo) {
            throw "Can't find a module manifest in $BuildManifestParent"
        }

        # If we found more than one module info then something is wrong in the source folder.
        if (@($ModuleInfo).Count -gt 1) {
            throw ("Found multiple module manifest in the root of the path {0}." -f $ParameterValues["SourcePath"])
        }

        Write-Debug "Updating BuildInfo SourcePath to $($ModuleInfo.Path)"
        $ParameterValues["SourcePath"] = $ModuleInfo.Path
    }

    $BuildInfo = $BuildInfo | Update-Object $ParameterValues
    Write-Debug "Using Module Manifest $($BuildInfo.SourcePath)"

    # Make sure the SourcePath is absolute and points at an actual file
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
