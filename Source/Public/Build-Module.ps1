if (!(Get-Verb Build) -and $MyInvocation.Line -notmatch "DisableNameChecking") {
    Write-Warning "The verb 'Build' was approved recently, but PowerShell $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) doesn't know. You will be warned about Build-Module."
}

function Build-Module {
    <#
        .Synopsis
            Compile a module from ps1 files to a single psm1
        .Description
            Compiles modules from source according to conventions:
            1. A single ModuleName.psd1 manifest file with metadata
            2. Source subfolders in the same directory as the manifest:
               Enum, Classes, Private, Public contain ps1 files
            3. Optionally, a build.psd1 file containing settings for this function

            The optimization process:
            1. The OutputDirectory is created
            2. All psd1/psm1/ps1xml files (except build.psd1) in the root will be copied to the output
            3. If specified, $CopyDirectories will be copied to the output
            4. The ModuleName.psm1 will be generated (overwritten completely) by concatenating all .ps1 files in the $SourceDirectories subdirectories
            5. The ModuleVersion and ExportedFunctions in the ModuleName.psd1 may be updated (depending on parameters)

        .Example
            Build-Module -Suffix "Export-ModuleMember -Function *-* -Variable PreferenceVariable"

            This example shows how to build a simple module from it's manifest, adding an Export-ModuleMember as a Suffix

        .Example
            Build-Module -Prefix "using namespace System.Management.Automation"

            This example shows how to build a simple module from it's manifest, adding a using statement at the top as a prefix

        .Example
            $gitVersion = gitversion | ConvertFrom-Json | Select -Expand InformationalVersion
            Build-Module -SemVer $gitVersion

            This example shows how to use a semantic version from gitversion to version your build.
            Note, this is how we version ModuleBuilder, so if you want to see it in action, check out our azure-pipelines.yml
            https://github.com/PoshCode/ModuleBuilder/blob/master/azure-pipelines.yml
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Build is approved now")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseCmdletCorrectly", "")]
    [CmdletBinding(DefaultParameterSetName="SemanticVersion")]
    param(
        # The path to the module folder, manifest or build.psd1
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateScript({
            if (Test-Path $_) {
                $true
            } else {
                throw "Source must point to a valid module"
            }
        })]
        [Alias("ModuleManifest", "Path")]
        [string]$SourcePath = $(Get-Location -PSProvider FileSystem),

        # Where to build the module.
        # Defaults to an ..\output folder (adjacent to the "SourcePath" folder)
        [Alias("Destination")]
        [string]$OutputDirectory = "..\Output",

        # If set (true) adds a folder named after the version number to the OutputDirectory
        [switch]$VersionedOutputDirectory,

        # Semantic version, like 1.0.3-beta01+sha.22c35ffff166f34addc49a3b80e622b543199cc5
        # If the SemVer has metadata (after a +), then the full Semver will be added to the ReleaseNotes
        [Parameter(ParameterSetName="SemanticVersion")]
        [string]$SemVer,

        # The module version (must be a valid System.Version such as PowerShell supports for modules)
        [Alias("ModuleVersion")]
        [Parameter(ParameterSetName="ModuleVersion", Mandatory)]
        [version]$Version = $(if($V = $SemVer.Split("+")[0].Split("-")[0]){$V}),

        # Setting pre-release forces the release to be a pre-release.
        # Must be valid pre-release tag like PowerShellGet supports
        [Parameter(ParameterSetName="ModuleVersion")]
        [string]$Prerelease = $($SemVer.Split("+")[0].Split("-")[1]),

        # Build metadata (like the commit sha or the date).
        # If a value is provided here, then the full Semantic version will be inserted to the release notes:
        # Like: ModuleName v(Version(-Prerelease?)+BuildMetadata)
        [Parameter(ParameterSetName="ModuleVersion")]
        [string]$BuildMetadata = $($SemVer.Split("+")[1]),

        # Folders which should be copied intact to the module output
        # Can be relative to the  module folder
        [AllowEmptyCollection()]
        [string[]]$CopyDirectories = @(),

        # Folders which contain source .ps1 scripts to be concatenated into the module
        # Defaults to Enum, Classes, Private, Public
        [string[]]$SourceDirectories = @(
            "Enum", "Classes", "Private", "Public"
        ),

        # A Filter (relative to the module folder) for public functions
        # If non-empty, ExportedFunctions will be set with the file BaseNames of matching files
        # Defaults to Public\*.ps1
        [AllowEmptyString()]
        [string[]]$PublicFilter = "Public\*.ps1",

        # File encoding for output RootModule (defaults to UTF8)
        # Converted to System.Text.Encoding for PowerShell 6 (and something else for PowerShell 5)
        [ValidateSet("UTF8","UTF7","ASCII","Unicode","UTF32")]
        [string]$Encoding = "UTF8",

        # The prefix is either the path to a file (relative to the module folder) or text to put at the top of the file.
        # If the value of prefix resolves to a file, that file will be read in, otherwise, the value will be used.
        # The default is nothing. See examples for more details.
        [string]$Prefix,

        # The Suffix is either the path to a file (relative to the module folder) or text to put at the bottom of the file.
        # If the value of Suffix resolves to a file, that file will be read in, otherwise, the value will be used.
        # The default is nothing. See examples for more details.
        [Alias("ExportModuleMember","Postfix")]
        [string]$Suffix,

        # Controls whether or not there is a build or cleanup performed
        [ValidateSet("Clean", "Build", "CleanBuild")]
        [string]$Target = "CleanBuild",

        # Output the ModuleInfo of the "built" module
        [switch]$Passthru
    )

    begin {
        if ($Encoding -ne "UTF8") {
            Write-Warning "We strongly recommend you build your script modules with UTF8 encoding for maximum cross-platform compatibility."
        }
    }
    process {
        try {
            # BEFORE we InitializeBuild we need to "fix" the version
            if($PSCmdlet.ParameterSetName -ne "SemanticVersion") {
                Write-Verbose "Calculate the Semantic Version from the $Version - $Prerelease + $BuildMetadata"
                $SemVer = $Version
                if($Prerelease) {
                    $SemVer = $Version + '-' + $Prerelease
                }
                if($BuildMetadata) {
                    $SemVer = $SemVer + '+' + $BuildMetadata
                }
            }

            # Push into the module source (it may be a subfolder)
            $ModuleInfo = InitializeBuild $SourcePath
            Write-Progress "Building $($ModuleInfo.Name)" -Status "Use -Verbose for more information"
            Write-Verbose  "Building $($ModuleInfo.Name)"

            # Output file names
            $OutputDirectory = $ModuleInfo | ResolveOutputFolder
            $RootModule = Join-Path $OutputDirectory "$($ModuleInfo.Name).psm1"
            $OutputManifest = Join-Path $OutputDirectory "$($ModuleInfo.Name).psd1"
            Write-Verbose  "Output to: $OutputDirectory"

            if ($Target -match "Clean") {
                Write-Verbose "Cleaning $OutputDirectory"
                if (Test-Path $OutputDirectory -PathType Leaf) {
                    throw "Unable to build. There is a file in the way at $OutputDirectory"
                }
                if (Test-Path $OutputDirectory -PathType Container) {
                    if (Get-ChildItem $OutputDirectory\*) {
                        Remove-Item $OutputDirectory\* -Recurse -Force
                    }
                }
                if ($Target -notmatch "Build") {
                    return # No build, just cleaning
                }
            } else {
                # If we're not cleaning, skip the build if it's up to date already
                Write-Verbose "Target $Target"
                $NewestBuild = (Get-Item $RootModule -ErrorAction SilentlyContinue).LastWriteTime
                $IsNew = Get-ChildItem $ModuleInfo.ModuleBase -Recurse |
                    Where-Object LastWriteTime -gt $NewestBuild |
                    Select-Object -First 1 -ExpandProperty LastWriteTime
                if ($null -eq $IsNew) {
                    return # Skip the build
                }
            }
            $null = New-Item -ItemType Directory -Path $OutputDirectory -Force

            # Note that this requires that the module manifest be in the "root" of the source directories
            Set-Location $ModuleInfo.ModuleBase

            Write-Verbose "Copy files to $OutputDirectory"
            # Copy the files and folders which won't be processed
            Copy-Item *.psm1, *.psd1, *.ps1xml -Exclude "build.psd1" -Destination $OutputDirectory -Force
            if ($ModuleInfo.CopyDirectories) {
                Write-Verbose "Copy Entire Directories: $($ModuleInfo.CopyDirectories)"
                Copy-Item -Path $ModuleInfo.CopyDirectories -Recurse -Destination $OutputDirectory -Force
            }

            Write-Verbose "Combine scripts to $RootModule"

            # SilentlyContinue because there don't *HAVE* to be functions at all
            $AllScripts = Get-ChildItem -Path $SourceDirectories.ForEach{ Join-Path $ModuleInfo.ModuleBase $_ } -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue

            SetModuleContent -Source (@($ModuleInfo.Prefix) + $AllScripts.FullName + @($ModuleInfo.Suffix)).Where{$_} -Output $RootModule -Encoding "$($ModuleInfo.Encoding)"

            # If there is a PublicFilter, update ExportedFunctions
            if ($ModuleInfo.PublicFilter) {
                # SilentlyContinue because there don't *HAVE* to be public functions
                if ($PublicFunctions = Get-ChildItem $ModuleInfo.PublicFilter -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName) {
                    Update-Metadata -Path $OutputManifest -PropertyName FunctionsToExport -Value $PublicFunctions
                }
            }

            try {
                if ($Version) {
                    Write-Verbose "Update Manifest at $OutputManifest with version: $Version"
                    Update-Metadata -Path $OutputManifest -PropertyName ModuleVersion -Value $Version
                }
            } catch {
                Write-Warning "Failed to update version to $Version. $_"
            }

            if ($Prerelease) {
                Write-Verbose "Update Manifest at $OutputManifest with Prerelease: $Prerelease"
                Update-Metadata -Path $OutputManifest -PropertyName PrivateData.PSData.Prerelease -Value $Prerelease
            } else {
                Update-Metadata -Path $OutputManifest -PropertyName PrivateData.PSData.Prerelease -Value ""
            }

            if ($BuildMetadata) {
                Write-Verbose "Update Manifest at $OutputManifest with metadata: $BuildMetadata from $SemVer"
                $RelNote = Get-Metadata -Path $OutputManifest -PropertyName PrivateData.PSData.ReleaseNotes -ErrorAction SilentlyContinue
                if ($null -ne $RelNote) {
                    $Line = "$($ModuleInfo.Name) v$($SemVer)"
                    if ([string]::IsNullOrWhiteSpace($RelNote)) {
                        Write-Verbose "New ReleaseNotes:`n$Line"
                        Update-Metadata -Path $OutputManifest -PropertyName PrivateData.PSData.ReleaseNotes -Value $Line
                    } elseif ($RelNote -match "^\s*\n") {
                        # Leading whitespace includes newlines
                        Write-Verbose "Existing ReleaseNotes:$RelNote"
                        $RelNote = $RelNote -replace "^(?s)(\s*)\S.*$|^$","`${1}$($Line)`$_"
                        Write-Verbose "New ReleaseNotes:$RelNote"
                        Update-Metadata -Path $OutputManifest -PropertyName PrivateData.PSData.ReleaseNotes -Value $RelNote
                    } else {
                        Write-Verbose "Existing ReleaseNotes:`n$RelNote"
                        $RelNote = $RelNote -replace "^(?s)(\s*)\S.*$|^$","`${1}$($Line)`n`$_"
                        Write-Verbose "New ReleaseNotes:`n$RelNote"
                        Update-Metadata -Path $OutputManifest -PropertyName PrivateData.PSData.ReleaseNotes -Value $RelNote
                    }
                }
            }

            # This is mostly for testing ...
            if ($Passthru) {
                Get-Module $OutputManifest -ListAvailable
            }
        } finally {
            Pop-Location -StackName Build-Module -ErrorAction SilentlyContinue
        }
    }
}
