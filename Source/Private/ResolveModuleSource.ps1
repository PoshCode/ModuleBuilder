function ResolveModuleSource {
    <#
        .Synopsis
            Resolve the module base path to the root of the module source code.
    #>
    [OutputType([string])]
    param(
        # The path to the module folder, manifest or build.psd1
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateScript( {
                if (Test-Path $_) {
                    $true
                } else {
                    throw "Path must point to an existing file or folder: $_"
                }
            })]
        [Alias("ModuleManifest")]
        [string]$Path = $(Get-Location -PSProvider FileSystem)
    )

    $ModuleBase = Split-Path $Path -Parent
    # Do not use GetFileNameWithoutExtension, because some module names have dots in them
    $ModuleName = (Split-Path $Path -Leaf) -replace "\.psd1$"

    # If $Path points to a build file, switch to the manifest
    if (Test-Path $Path -PathType Leaf) {
        if ($ModuleName -eq "Build") {
            $Path = $ModuleBase
        }
    }

    # If $Path is a folder, check for a matching module manifest or build.psd1
    if (Test-Path $Path -PathType Container) {
        # If we're in a "well known" source folder, look higher for a name
        if ($ModuleName -in "Source", "src") {
            $ModuleName = Split-Path $ModuleBase -Leaf
        }
        if ( (Test-Path (Join-Path $Path build.psd1)) -or (Test-Path (Join-Path $Path "$ModuleName.psd1")) ) {
            $ModuleBase = $Path
        } else {
            throw "No module found in $Path. Try passing the full path to the module manifest file."
        }
    }

    Convert-Path $ModuleBase
}