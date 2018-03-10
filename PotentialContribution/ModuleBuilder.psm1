function Optimize-Module {
    <#
        .Synopsis
            Compile a module from ps1 files to a single psm1
        .Description
            Compiles modules from source according to conventions:
            1. A single ModuleName.psd1 manifest file with metadata
            2. Source subfolders in the same directory as the manifest:
               Classes, Private, Public contain ps1 files
            3. Optionally, a build.psd1 file containing settings for this function

            The optimization process:
            1. The OutputDirectory is created
            2. All psd1/psm1/ps1xml files in the root will be copied to the output
            3. If specified, $CopyDirectories will be copied to the output
            4. The ModuleName.psm1 will be generated (overwritten completely) by concatenating all .ps1 files in subdirectories (that aren't specified in CopySubdirectories)
            5. The ModuleName.psd1 will be updated (based on existing data)
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseCmdletCorrectly", "")]
    param(
        # The path to the module folder, manifest or build.psd1
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateScript( {
                if (Test-Path $_) {
                    $true
                } else {
                    throw "Source must point to a valid module"
                }
            } )]
        [Alias("ModuleManifest")]
        [string]$Path,

        # Where to build the module.
        # Defaults to a version number folder, adjacent to the module folder
        [Alias("Destination")]
        [string]$OutputDirectory,

        [version]$ModuleVersion,

        # Folders which should be copied intact to the module output
        # Can be relative to the  module folder
        [AllowEmptyCollection()]
        [string[]]$CopyDirectories = @(),

        # A Filter (relative to the module folder) for public functions
        # If non-empty, ExportedFunctions will be set with the file BaseNames of matching files
        # Defaults to Public\*.ps1
        [AllowEmptyString()]
        [string[]]$PublicFilter = "Public\*.ps1",

        # File encoding for output RootModule (defaults to UTF8)
        [Microsoft.PowerShell.Commands.FileSystemCmdletProviderEncoding]
        $Encoding = "UTF8",

        # A line which will be added at the bottom of the psm1. The intention is to allow you to add an export like:
        # Export-ModuleMember -Alias *-QM* -Functions * -Variables QMConstant_*
        #
        # The default is nothing
        $ExportModuleMember,

        # Controls whether or not there is a build or cleanup performed
        [ValidateSet("Clean", "Build", "CleanBuild")]
        [string]$Target = "CleanBuild",

        # Output the ModuleInfo of the "built" module
        [switch]$Passthru
    )

    process {
        try {
            # If a path is $passed, use that
            if ($Path) {
                $ModuleBase = Split-Path $Path -Parent
                # Do not use GetFileNameWithoutExtension, some module names have dots in them
                $ModuleName = (Split-Path $Path -Leaf) -replace ".psd1$"

                # Support passing the path to a module folder
                if (Test-Path $Path -PathType Container) {
                    if ( (Test-Path (Join-Path $Path build.psd1)) -or
                        (Test-Path (Join-Path $Path "$ModuleName.psd1"))
                    ) {
                        $ModuleBase = $Path
                        $Path = Join-Path $Path "$ModuleName.psd1"
                        if (Test-Path $Path) {
                            $PSBoundParameters["Path"] = $Path
                        } else {
                            $null = $PSBoundParameters.Remove("Path")
                        }
                    } else {
                        throw "Module not found in $Path. Try passing the full path to the manifest file."
                    }
                }

                # Add support for passing the path to a build.psd1
                if ( (Test-Path $Path -PathType Leaf) -and ($ModuleName -eq "build") ) {
                    $null = $PSBoundParameters.Remove("Path")
                }

                Push-Location $ModuleBase -StackName Optimize-Module
                # Otherwise, look for a local build.psd1
            } elseif (Test-Path Build.psd1) {
                Push-Location -StackName Optimize-Module
            } else {
                throw "Build.psd1 not found in PWD. You must specify the -Path to the build"
            }

            # Read build.psd1 for defaults
            if (Test-Path Build.psd1) {
                $BuildInfo = Import-LocalizedData -BaseDirectory $Pwd.Path -FileName Build
            } else {
                $BuildInfo = @{}
            }

            # Overwrite with parameter values
            foreach ($property in $PSBoundParameters.Keys) {
                $BuildInfo.$property = $PSBoundParameters.$property
            }

            $BuildInfo.Path = Resolve-Path $BuildInfo.Path

            # Read Module Manifest for details
            $ModuleInfo = Get-Module $BuildInfo.Path -ListAvailable -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -ErrorVariable Problems
            if ($Problems) {
                $Problems = $Problems.Where{ $_.FullyQualifiedErrorId -notmatch "^Modules_InvalidRequiredModulesinModuleManifest"}
                if ($Problems) {
                    foreach ($problem in $Problems) {
                        Write-Error $problem
                    }
                    throw "Unresolvable problems in module manifest"
                }
            }
            foreach ($property in $BuildInfo.Keys) {
                # Note:we can't overwrite the Path from the Build.psd1
                Add-Member -Input $ModuleInfo -Type NoteProperty -Name $property -Value $BuildInfo.$property -ErrorAction SilentlyContinue
            }

            # Copy in default parameters
            if (!(Get-Member -InputObject $ModuleInfo -Name PublicFilter)) {
                Add-Member -Input $ModuleInfo -Type NoteProperty -Name PublicFilter -Value $PublicFilter
            }
            if (!(Get-Member -InputObject $ModuleInfo -Name Encoding)) {
                Add-Member -Input $ModuleInfo -Type NoteProperty -Name Encoding -Value $Encoding
            }
            # Fix the version before making the folder
            if ($ModuleVersion) {
                Add-Member -Input $ModuleInfo -Type NoteProperty -Name Version -Value $ModuleVersion -Force
            }

            # Ensure OutputDirectory
            if (!$ModuleInfo.OutputDirectory) {
                $OutputDirectory = Join-Path (Split-Path $ModuleInfo.ModuleBase -Parent) $ModuleInfo.Version
                Add-Member -Input $ModuleInfo -Type NoteProperty -Name OutputDirectory -Value $OutputDirectory -Force
            }
            $OutputDirectory = $ModuleInfo.OutputDirectory
            Write-Progress "Building $($ModuleInfo.ModuleBase)" -Status "Use -Verbose for more information"
            Write-Verbose  "Building $($ModuleInfo.ModuleBase)"
            Write-Verbose  "         Output to: $OutputDirectory"

            if ($Target -match "Clean") {
                Write-Verbose "Cleaning $OutputDirectory"
                if (Test-Path $OutputDirectory) {
                    Remove-Item $OutputDirectory -Recurse -Force
                }
                if ($Target -notmatch "Build") {
                    return # No build, just cleaning
                }
            } else {
                # If we're not cleaning, skip the build if it's up to date already
                Write-Verbose "Target $Target"
                $NewestBuild = Get-ChildItem $OutputDirectory -Recurse |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1 -ExpandProperty LastWriteTime
                $IsNew = Get-ChildItem $ModuleInfo.ModuleBase -Recurse |
                    Where-Object LastWriteTime -gt $NewestBuild |
                    Select-Object -First 1 -ExpandProperty LastWriteTime
                if ($null -eq $IsNew) {
                    return # Skip the build
                }
            }
            $null = mkdir $OutputDirectory -Force

            Write-Verbose "Copy files to $OutputDirectory"
            # Copy the files and folders which won't be processed
            Copy-Item *.psm1, *.psd1, *.ps1xml -Exclude "build.psd1" -Destination $OutputDirectory -Force
            if ($ModuleInfo.CopyDirectories) {
                Write-Verbose "Copy Entire Directories: $($ModuleInfo.CopyDirectories)"
                Copy-Item -Path $ModuleInfo.CopyDirectories -Recurse -Destination $OutputDirectory -Force
            }

            # Output psm1
            $RootModule = Join-Path $OutputDirectory "$($ModuleInfo.Name).psm1"
            $OutputManifest = Join-Path $OutputDirectory "$($ModuleInfo.Name).psd1"

            Write-Verbose "Combine scripts to $RootModule"
            # Prefer pipeline to speed for the sake of memory and file IO
            # SilentlyContinue because there don't *HAVE* to be functions at all
            $AllScripts = Get-ChildItem -Path $ModuleInfo.ModuleBase -Exclude $ModuleInfo.CopyDirectories -Directory -ErrorAction SilentlyContinue |
                Get-ChildItem -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue

            if ($AllScripts) {
                $AllScripts | ForEach-Object {
                    $SourceName = Resolve-Path $_.FullName -Relative
                    Write-Verbose "Adding $SourceName"
                    "# BEGIN $SourceName"
                    Get-Content $SourceName
                    "# END $SourceName"
                } | Set-Content -Path $RootModule -Encoding $ModuleInfo.Encoding

                if ($ModuleInfo.ExportModuleMember) {
                    Add-Content -Path $RootModule -Value $ModuleInfo.ExportModuleMember -Encoding $ModuleInfo.Encoding
                }

                # If there is a PublicFilter, update ExportedFunctions
                if ($ModuleInfo.PublicFilter) {
                    # SilentlyContinue because there don't *HAVE* to be public functions
                    if ($PublicFunctions = Get-ChildItem $ModuleInfo.PublicFilter -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName) {
                        # TODO: Remove the _Public hack
                        Update-Metadata -Path $OutputManifest -PropertyName FunctionsToExport -Value ($PublicFunctions -replace "_Public$")
                    }
                }
            }

            Write-Verbose "Update Manifest to $OutputManifest"

            Update-Metadata -Path $OutputManifest -PropertyName Copyright -Value ($ModuleInfo.Copyright -replace "20\d\d", (Get-Date).Year)

            if ($ModuleVersion) {
                Update-Metadata -Path $OutputManifest -PropertyName ModuleVersion -Value $ModuleVersion
            }

            # This is mostly for testing ...
            if ($Passthru) {
                Get-Module $OutputManifest -ListAvailable
            }
        } finally {
            Pop-Location -StackName Optimize-Module -ErrorAction SilentlyContinue
        }
    }
}
