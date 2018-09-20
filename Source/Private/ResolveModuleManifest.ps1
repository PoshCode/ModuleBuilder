function ResolveModuleManifest {
    <#
        .Synopsis
            Resolve the module manifest path in the module source base.
    #>
    [OutputType([string])]
    param(
        # The path to the module folder, manifest or build.psd1
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateScript( {
                if (Test-Path $_ -PathType Container) {
                    $true
                } else {
                    throw "ModuleBase must point to the source base for a module: $_"
                }
            })]
        [Alias("ModuleManifest")]
        [string]$ModuleBase = $(Get-Location -PSProvider FileSystem),

        [Parameter(Position = 1, ValueFromPipelineByPropertyName)]
        [AllowNull()]
        [Alias("ModuleName")]
        [string]$Name
    )
    Push-Location $ModuleBase -StackName ResolveModuleManifest

    if(!$PSBoundParameters.ContainsKey("Name") -or !$Name) {
        # Do not use GetFileNameWithoutExtension, because some module names have dots in them
        $Name = (Split-Path $ModuleBase -Leaf) -replace "\.psd1$"
        # If we're in a "well known" source folder, look higher for a name
        if ($Name -in "Source", "src") {
            $Name = Split-Path (Split-Path $ModuleBase) -Leaf
        }

        # If the folder name isn't the manifest name, look in the build.psd1
        if (!(Test-Path "$Name.psd1") -and (Test-Path "build.psd1")) {
            $Name = (Import-LocalizedData -BaseDirectory $ModuleBase -FileName Build -ErrorAction SilentlyContinue).Path -replace "\.psd1$"
        }
    } else {
        $Name = (Split-Path $Name -Leaf) -replace "\.psd1$"
    }

    $Manifest = Join-Path $ModuleBase "$Name.psd1"
    if (!(Test-Path $Manifest)) {
        Pop-Location -StackName ResolveModuleManifest
        throw "Can't find module manifest $Manifest"
    }

    Pop-Location -StackName ResolveModuleManifest
    $Manifest
}