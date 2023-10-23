function GetBuildInfo {
    [CmdletBinding()]
    param(
        # The path to the Build Manifest Build.psd1
        [Parameter()]
        [AllowNull()]
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
        Write-Debug "  Updating: SourcePath"
        Write-Debug "    To: $($BuildInfo.SourcePath)"
        $ParameterValues["SourcePath"] = $BuildInfo.SourcePath
    }
    # If SourcePath point to build.psd1, we should clear it
    if ($ParameterValues["SourcePath"] -eq $BuildManifest) {
        Write-Debug "  Removing: SourcePath"
        $ParameterValues.Remove("SourcePath")
    }
    Write-Debug "Finished parsing Build Manifest $BuildManifest"

    $BuildManifestParent = if ($BuildManifest) {
        Split-Path -Parent $BuildManifest
    } else {
        Get-Location -PSProvider FileSystem
    }

    if ((-not $BuildInfo.SourcePath) -and $ParameterValues["SourcePath"] -notmatch '\.psd1') {
        Write-Debug "  Searching: SourcePath ($BuildManifestParent/**/*.psd1)"
        # Find a module manifest (or maybe several)
        $ModuleInfo = Get-ChildItem $BuildManifestParent -Recurse -Filter *.psd1 -ErrorAction SilentlyContinue |
            ImportModuleManifest -ErrorAction SilentlyContinue
        # If we found more than one module info, the only way we have of picking just one is if it matches a folder name
        if (@($ModuleInfo).Count -gt 1) {
            Write-Debug (@(@("  Found $(@($ModuleInfo).Count):") + @($ModuleInfo.Path)) -join "`n            ")
            # It can't be a module that needs building unless it has either:
            $ModuleInfo = $ModuleInfo.Where{
                $Root = Split-Path $_.Path
                @(
                    # - A build.psd1 next to it
                    Test-Path (Join-Path $Root "build.ps1") -PathType Leaf
                    # - A Public (or Private) folder with source scripts in it
                    Test-Path (Join-Path $Root "Public") -PathType Container
                    Test-Path (Join-Path $Root "Private") -PathType Container
                ) -contains $true
            }
            Write-Debug (@(@("  Filtered $(@($ModuleInfo).Count):") + @($ModuleInfo.Path)) -join "`n            ")
        }
        if (@($ModuleInfo).Count -eq 1) {
            Write-Debug "Updating BuildInfo SourcePath to $($ModuleInfo.Path)"
            $ParameterValues["SourcePath"] = $ModuleInfo.Path
        } else {
            throw "Can't determine the module manifest in $BuildManifestParent"
        }
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
