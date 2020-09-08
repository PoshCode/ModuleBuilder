function ResolveOutputFolder {
    [CmdletBinding()]
    param(
        # The name of the module to build
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias("Name")]
        [string]$ModuleName,

        # Where to resolve the $OutputDirectory from when relative
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias("ModuleBase")]
        [string]$Source,

        # Where to build the module.
        # Defaults to an \output folder, adjacent to the "SourcePath" folder
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$OutputDirectory,

        # specifies the module version for use in the output path if -VersionedOutputDirectory is true
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias("ModuleVersion")]
        [string]$Version,

        # If set (true) adds a folder named after the version number to the OutputDirectory
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("Force")]
        [switch]$VersionedOutputDirectory,

        # Controls whether or not there is a build or cleanup performed
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateSet("Clean", "Build", "CleanBuild")]
        [string]$Target = "CleanBuild"
    )
    process {
        Write-Verbose "Resolve OutputDirectory path: $OutputDirectory"

        # Ensure the OutputDirectory makes sense (it's never blank anymore)
        if (!(Split-Path -IsAbsolute $OutputDirectory)) {
            # Relative paths are relative to the ModuleBase
            $OutputDirectory = Join-Path $Source $OutputDirectory
        }
        # If they passed in a path with ModuleName\Version on the end...
        if ((Split-Path $OutputDirectory -Leaf).EndsWith($Version) -and (Split-Path (Split-Path $OutputDirectory) -Leaf) -eq $ModuleName) {
            # strip the version (so we can add it back)
            $VersionedOutputDirectory = $true
            $OutputDirectory = Split-Path $OutputDirectory
        }
        # Ensure the OutputDirectory is named "ModuleName"
        if ((Split-Path $OutputDirectory -Leaf) -ne $ModuleName) {
            # If it wasn't, add a "ModuleName"
            $OutputDirectory = Join-Path $OutputDirectory $ModuleName
        }
        # Ensure the OutputDirectory is not a parent of the SourceDirectory
        if (-not [io.path]::GetRelativePath($OutputDirectory, $Source).StartsWith("..")) {
            Write-Verbose "Added Version to OutputDirectory path: $OutputDirectory"
            $OutputDirectory = Join-Path $OutputDirectory $Version
        }
        # Ensure the version number is on the OutputDirectory if it's supposed to be
        if ($VersionedOutputDirectory -and -not (Split-Path $OutputDirectory -Leaf).EndsWith($Version)) {
            Write-Verbose "Added Version to OutputDirectory path: $OutputDirectory"
            $OutputDirectory = Join-Path $OutputDirectory $Version
        }

        if (Test-Path $OutputDirectory -PathType Leaf) {
            throw "Unable to build. There is a file in the way at $OutputDirectory"
        }

        if ($Target -match "Clean") {
            Write-Verbose "Cleaning $OutputDirectory"
            if (Test-Path $OutputDirectory -PathType Container) {
                Remove-Item $OutputDirectory -Recurse -Force
            }
        }
        if ($Target -match "Build") {
            # Make sure the OutputDirectory exists (relative to ModuleBase or absolute)
            New-Item $OutputDirectory -ItemType Directory -Force | Convert-Path
        }
    }
}
