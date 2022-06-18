function Build-Module {
    <#
        .Synopsis
            Compile a module from ps1 files to a single psm1

        .Description
            Compiles modules from source according to conventions:
            1. A single ModuleName.psd1 manifest file with metadata
            2. Source subfolders in the same directory as the Module manifest:
               Enum, Classes, Private, Public contain ps1 files
            3. Optionally, a build.psd1 file containing settings for this function

            The optimization process:
            1. The OutputDirectory is created
            2. All psd1/psm1/ps1xml files (except build.psd1) in the Source will be copied to the output
            3. If specified, $CopyPaths (relative to the Source) will be copied to the output
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification="Parameter handling is in InitializeBuild")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidDefaultValueSwitchParameter", "", Justification = "VersionedOutputDirectory is Deprecated")]
    [CmdletBinding(DefaultParameterSetName="SemanticVersion")]
    [Alias("build")]
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

        # Where to build the module. Defaults to "..\Output" adjacent to the "SourcePath" folder.
        # The ACTUAL output may be in a subfolder of this path ending with the module name and version
        # The default value is ..\Output which results in the build going to ..\Output\ModuleName\1.2.3
        [Alias("Destination")]
        [string]$OutputDirectory = "..\Output",

        # DEPRECATED. Now defaults true, producing a OutputDirectory with a version number as the last folder
        [switch]$VersionedOutputDirectory = $true,

        # Overrides the VersionedOutputDirectory, producing an OutputDirectory without a version number as the last folder
        [switch]$UnversionedOutputDirectory,

        # Semantic version, like 1.0.3-beta01+sha.22c35ffff166f34addc49a3b80e622b543199cc5
        # If the SemVer has metadata (after a +), then the full Semver will be added to the ReleaseNotes
        [Parameter(ParameterSetName="SemanticVersion")]
        [string]$SemVer,

        # The module version (must be a valid System.Version such as PowerShell supports for modules)
        [Alias("ModuleVersion")]
        [Parameter(ParameterSetName="ModuleVersion", Mandatory)]
        [version]$Version = $(if(($V = $SemVer.Split("+")[0].Split("-",2)[0])){$V}),

        # Setting pre-release forces the release to be a pre-release.
        # Must be valid pre-release tag like PowerShellGet supports
        [Parameter(ParameterSetName="ModuleVersion")]
        [string]$Prerelease = $($SemVer.Split("+")[0].Split("-",2)[1]),

        # Build metadata (like the commit sha or the date).
        # If a value is provided here, then the full Semantic version will be inserted to the release notes:
        # Like: ModuleName v(Version(-Prerelease?)+BuildMetadata)
        [Parameter(ParameterSetName="ModuleVersion")]
        [string]$BuildMetadata = $($SemVer.Split("+",2)[1]),

        # Folders which should be copied intact to the module output
        # Can be relative to the  module folder
        [AllowEmptyCollection()]
        [Alias("CopyDirectories")]
        [string[]]$CopyPaths = @(),

        # Folders which contain source .ps1 scripts to be concatenated into the module
        # Defaults to Enum, Classes, Private, Public
        [string[]]$SourceDirectories = @(
            "Enum", "Classes", "Private", "Public"
        ),

        # A Filter (relative to the module folder) for public functions
        # If non-empty, FunctionsToExport will be set with the file BaseNames of matching files
        # Defaults to Public\*.ps1
        [AllowEmptyString()]
        [string[]]$PublicFilter = "Public\*.ps1",

        # A switch that allows you to disable the update of the AliasesToExport
        # By default, (if PublicFilter is not empty, and this is not set)
        # Build-Module updates the module manifest FunctionsToExport and AliasesToExport
        # with the combination of all the values in [Alias()] attributes on public functions
        # and aliases created with `New-ALias` or `Set-Alias` at script level in the module
        [Alias("IgnoreAliasAttribute")]
        [switch]$IgnoreAlias,

        # File encoding for output RootModule (defaults to UTF8)
        # Converted to System.Text.Encoding for PowerShell 6 (and something else for PowerShell 5)
        [ValidateSet("UTF8", "UTF8Bom", "UTF8NoBom", "UTF7", "ASCII", "Unicode", "UTF32")]
        [string]$Encoding = $(if($IsCoreCLR) { "UTF8Bom" } else { "UTF8" }),

        # The prefix is either the path to a file (relative to the module folder) or text to put at the top of the file.
        # If the value of prefix resolves to a file, that file will be read in, otherwise, the value will be used.
        # The default is nothing. See examples for more details.
        [string]$Prefix,

        # The Suffix is either the path to a file (relative to the module folder) or text to put at the bottom of the file.
        # If the value of Suffix resolves to a file, that file will be read in, otherwise, the value will be used.
        # The default is nothing. See examples for more details.
        [Alias("ExportModuleMember","Postfix")]
        [string]$Suffix,

        # Controls whether we delete the output folder and whether we build the output
        # There are three options:
        #   - Clean deletes the build output folder
        #   - Build builds the module output
        #   - CleanBuild first deletes the build output folder and then builds the module back into it
        # Note that the folder to be deleted is the actual calculated output folder, with the version number
        # So for the default OutputDirectory with version 1.2.3, the path to clean is: ..\Output\ModuleName\1.2.3
        [ValidateSet("Clean", "Build", "CleanBuild")]
        [string]$Target = "CleanBuild",

        # Output the ModuleInfo of the "built" module
        [switch]$Passthru
    )

    begin {
        if ($Encoding -notmatch "UTF8") {
            Write-Warning "For maximum portability, we strongly recommend you build your script modules with UTF8 encoding (with a BOM, for backwards compatibility to PowerShell 5)."
        }
    }
    process {
        try {
            # BEFORE we InitializeBuild we need to "fix" the version
            if($PSCmdlet.ParameterSetName -ne "SemanticVersion") {
                Write-Verbose "Calculate the Semantic Version from the $Version - $Prerelease + $BuildMetadata"
                $SemVer = "$Version"
                if($Prerelease) {
                    $SemVer = "$Version-$Prerelease"
                }
                if($BuildMetadata) {
                    $SemVer = "$SemVer+$BuildMetadata"
                }
            }

            # Push into the module source (it may be a subfolder)
            $ModuleInfo = InitializeBuild $SourcePath
            Write-Progress "Building $($ModuleInfo.Name)" -Status "Use -Verbose for more information"
            Write-Verbose  "Building $($ModuleInfo.Name)"

            # Ensure the OutputDirectory (exists for build, or is cleaned otherwise)
            $OutputDirectory = $ModuleInfo | ResolveOutputFolder
            if ($Target -notmatch "Build") {
                return
            }
            $RootModule = Join-Path $OutputDirectory "$($ModuleInfo.Name).psm1"
            $OutputManifest = Join-Path $OutputDirectory "$($ModuleInfo.Name).psd1"
            Write-Verbose  "Output to: $OutputDirectory"

            # Skip the build if it's up to date already
            Write-Verbose "Target $Target"
            $NewestBuild = (Get-Item $RootModule -ErrorAction SilentlyContinue).LastWriteTime
            $IsNew = Get-ChildItem $ModuleInfo.ModuleBase -Recurse |
                Where-Object LastWriteTime -gt $NewestBuild |
                Select-Object -First 1 -ExpandProperty LastWriteTime

            if ($null -eq $IsNew) {
                # This is mostly for testing ...
                if ($Passthru) {
                    Get-Module $OutputManifest -ListAvailable
                }
                return # Skip the build
            }

            # Note that the module manifest parent folder is the "root" of the source directories
            Push-Location $ModuleInfo.ModuleBase -StackName Build-Module

            Write-Verbose "Copy files to $OutputDirectory"
            # Copy the files and folders which won't be processed
            Copy-Item *.psm1, *.psd1, *.ps1xml -Exclude "build.psd1" -Destination $OutputDirectory -Force
            if ($ModuleInfo.CopyPaths) {
                Write-Verbose "Copy Entire Directories: $($ModuleInfo.CopyPaths)"
                Copy-Item -Path $ModuleInfo.CopyPaths -Recurse -Destination $OutputDirectory -Force
            }

            Write-Verbose "Combine scripts to $RootModule"

            # SilentlyContinue because there don't *HAVE* to be functions at all
            $AllScripts = Get-ChildItem -Path @($ModuleInfo.SourceDirectories).ForEach{ Join-Path $ModuleInfo.ModuleBase $_ } -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue

            # We have to force the Encoding to string because PowerShell Core made up encodings
            SetModuleContent -Source (@($ModuleInfo.Prefix) + $AllScripts.FullName + @($ModuleInfo.Suffix)).Where{$_} -Output $RootModule -Encoding "$($ModuleInfo.Encoding)"

            $ParseResult = ConvertToAst $RootModule
            $ParseResult | MoveUsingStatements -Encoding "$($ModuleInfo.Encoding)"

            if (-not $ModuleInfo.IgnoreAlias) {
                $AliasesToExport = $ParseResult | GetCommandAlias
            }

            # If there is a PublicFilter, update ExportedFunctions
            if ($ModuleInfo.PublicFilter) {
                # SilentlyContinue because there don't *HAVE* to be public functions
                if (($PublicFunctions = Get-ChildItem $ModuleInfo.PublicFilter -Recurse -ErrorAction SilentlyContinue | Where-Object BaseName -in $AllScripts.BaseName | Select-Object -ExpandProperty BaseName)) {
                    Update-Metadata -Path $OutputManifest -PropertyName FunctionsToExport -Value ($PublicFunctions | Where-Object {$_ -notin $AliasesToExport.Values})
                }
            }

            if ($PublicFunctions -and -not $ModuleInfo.IgnoreAlias) {
                if (($AliasesToExport = $AliasesToExport[$PublicFunctions] | ForEach-Object { $_ } | Select-Object -Unique)) {
                    Update-Metadata -Path $OutputManifest -PropertyName AliasesToExport -Value $AliasesToExport
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

            if ($null -ne (Get-Metadata -Path $OutputManifest -PropertyName PrivateData.PSData.Prerelease -ErrorAction SilentlyContinue)) {
                if ($Prerelease) {
                    Write-Verbose "Update Manifest at $OutputManifest with Prerelease: $Prerelease"
                    Update-Metadata -Path $OutputManifest -PropertyName PrivateData.PSData.Prerelease -Value $Prerelease
                } elseif ($PSCmdlet.ParameterSetName -eq "SemanticVersion" -or $PSBoundParameters.ContainsKey("Prerelease")) {
                    Update-Metadata -Path $OutputManifest -PropertyName PrivateData.PSData.Prerelease -Value ""
                }
            } elseif($Prerelease) {
                Write-Warning ("Cannot set Prerelease in module manifest. Add an empty Prerelease to your module manifest, like:`n" +
                               '         PrivateData = @{ PSData = @{ Prerelease = "" } }')
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
        Write-Progress "Building $($ModuleInfo.Name)" -Completed
    }
}
