function ResolveOutputFolder {
    [CmdletBinding()]
    param(
        # Where to build the module.
        # Defaults to an \output folder, adjacent to the "SourcePath" folder
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$OutputDirectory,

        # If set (true) adds a folder named after the version number to the OutputDirectory
        [Parameter(ValueFromPipelineByPropertyName)]
        [switch]$VersionedOutputDirectory,

        # specifies the module version for use in the output path if -VersionedOutputDirectory is true
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("ModuleVersion")]
        [string]$Version,

        # Where to resolve the $OutputDirectory from when relative
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$ModuleBase
    )
    process {
        Write-Verbose "Resolve OutputDirectory path: $OutputDirectory"

        # Ensure the OutputDirectory makes sense (it's never blank anymore)
        if (!(Split-Path -IsAbsolute $OutputDirectory)) {
            # Relative paths are relative to the ModuleBase
            $OutputDirectory = Join-Path $ModuleBase $OutputDirectory
        }

        # Make sure the OutputDirectory exists (relative to ModuleBase or absolute)
        $OutputDirectory = New-Item $OutputDirectory -ItemType Directory -Force | Convert-Path
        if ($VersionedOutputDirectory -and $OutputDirectory.TrimEnd("/\") -notmatch "\d+\.\d+\.\d+$") {
            $OutputDirectory = New-Item (Join-Path $OutputDirectory $Version) -ItemType Directory -Force | Convert-Path
            Write-Verbose "Added ModuleVersion to OutputDirectory path: $OutputDirectory"
        }
        $OutputDirectory
    }
}