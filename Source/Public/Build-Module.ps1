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
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Build is approved now")]
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
        [Alias("ModuleManifest", "Path")]
        [string]$SourcePath = $(Get-Location -PSProvider FileSystem),

        # Where to build the module.
        # Defaults to a version number folder, adjacent to the module folder
        [Alias("Destination")]
        [string]$OutputDirectory,

        [Alias("ModuleVersion")]
        [version]$Version,

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
        $Prefix,

        # The Suffix is either the path to a file (relative to the module folder) or text to put at the bottom of the file.
        # If the value of Suffix resolves to a file, that file will be read in, otherwise, the value will be used.
        # The default is nothing. See examples for more details.
        [Alias("ExportModuleMember","Postfix")]
        $Suffix,

        # Controls whether or not there is a build or cleanup performed
        [ValidateSet("Clean", "Build", "CleanBuild")]
        [string]$Target = "CleanBuild",

        # Your CultureInfo is, by default, the current UICulture and is used to determine the language of the ReadMe.
        [Globalization.CultureInfo]$Culture = $(Get-UICulture),

        # The Readme or About is the path to a file (relative to the module folder) to include as the about_Module.help.txt
        [Alias("AboutPath")]
        $ReadMe,

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
            # Push into the module source (it may be a subfolder)
            $ModuleInfo = InitializeBuild $SourcePath
            # Output file names
            $OutputDirectory = $ModuleInfo.OutputDirectory
            $RootModule = Join-Path $OutputDirectory "$($ModuleInfo.Name).psm1"
            $OutputManifest = Join-Path $OutputDirectory "$($ModuleInfo.Name).psd1"

            Write-Progress "Building $($ModuleInfo.Name)" -Status "Use -Verbose for more information"
            Write-Verbose  "Building $($ModuleInfo.Name)"
            Write-Verbose  "Output to: $OutputDirectory"

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
                $NewestBuild = (Get-Item $RootModule -ErrorAction SilentlyContinue).LastWriteTime
                $IsNew = Get-ChildItem $ModuleInfo.ModuleBase -Recurse |
                    Where-Object LastWriteTime -gt $NewestBuild |
                    Select-Object -First 1 -ExpandProperty LastWriteTime
                if ($null -eq $IsNew) {
                    return # Skip the build
                }
            }
            $null = mkdir $OutputDirectory -Force

            # Note that this requires that the module manifest be in the "root" of the source directories
            Set-Location $ModuleInfo.ModuleBase

            Write-Verbose "Copy files to $OutputDirectory"
            # Copy the files and folders which won't be processed
            Copy-Item *.psm1, *.psd1, *.ps1xml -Exclude "build.psd1" -Destination $OutputDirectory -Force
            if ($ModuleInfo.CopyDirectories) {
                Write-Verbose "Copy Entire Directories: $($ModuleInfo.CopyDirectories)"
                Copy-Item -Path $ModuleInfo.CopyDirectories -Recurse -Destination $OutputDirectory -Force
            }

            $ModuleInfo | CopyReadMe

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

            Write-Verbose "Update Manifest to $OutputManifest"

            if ($Version) {
                Update-Metadata -Path $OutputManifest -PropertyName ModuleVersion -Value $Version
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
