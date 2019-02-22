function ResolveBuildManifest {
    [CmdletBinding()]
    param(
        # The Source folder path, the Build Manifest Path, or the Module Manifest path used to resolve the Build.psd1
        [Alias("BuildManifest")]
        [string]$SourcePath = $(Get-Location -PSProvider FileSystem)
    )

    if ( (Split-Path $SourcePath -Leaf) -eq 'build.psd1') {
        $BuildManifest = $SourcePath
    }
    elseif (Test-Path $SourcePath -PathType Leaf) {
        # When you pass the ModuleManifest as parameter, you must have the Build Manifest in the same folder
        $BuildManifest = Join-Path (Split-Path -Parent $SourcePath) [Bb]uild.psd1
    }
    else {
        # It's a container, assume the Build Manifest is directly under
        $BuildManifest = Join-Path $SourcePath [Bb]uild.psd1
    }

    # Make sure we are resolving the absolute path to the manifest, and test it exists
    $ResolvedBuildManifest = (Resolve-Path $BuildManifest -ErrorAction SilentlyContinue).Path

    if ( -Not ($ResolvedBuildManifest)) {
        throw "Couldn't resolve the Build Manifest at $BuildManifest"
    }
    else {
        $ResolvedBuildManifest
    }

}
