function InitializeBuild {
    <#
        .SYNOPSIS
            Loads build.psd1 and the module manifest and combines them with the parameter values of the calling function. Pushes location to the module source location.
        .DESCRIPTION
            This function is for internal use from Build-Module only
            It does two things that make it really only work properly there:

            1. It calls Push-Location without Pop-Location to push the SourcePath into the "Build-Module" stack
            2. It reads the ParameterValues from the PARENT MyInvocation
        .NOTES
            Depends on the internal ResolveModuleSource and ResolveModuleManifest
            Depends on the Configuration module Update-Object and (the built in Import-LocalizedData and Get-Module)
    #>
    [CmdletBinding()]
    param(
        # The root folder where the module source is (including the Build.psd1 and the module Manifest.psd1)
        [string]$SourcePath,

        # Pass the invocation from the parent in, so InitializeBuild can read parameter values
        [Parameter(DontShow)]
        $Invocation = $(Get-Variable MyInvocation -Scope 1 -ValueOnly)
    )
    # NOTE: This reads the parameter values from Build-Module!
    # BUG BUG: needs to prioritize build.psd1 values over build-module *defaults*, but user-provided parameters over build.psd1 values
    Write-Debug "Initializing build variables"
    if (-not (Split-Path -Path $SourcePath -Leaf) -eq 'build.psd1') {
        $ModuleSource = ResolveModuleSource $SourcePath
        $BuildManifest = Join-Path $ModuleSource [Bb]uild.psd1
    }
    else {
        Write-Verbose "Module source points to the Building project file"
        $BuildManifest = $SourcePath
    }

    # Read a build.psd1 configuration file for default parameter values
    $BuildInfo = Import-Metadata -Path $BuildManifest
    $BuildRoot = Split-Path -parent $BuildManifest -Resolve
    Push-Location $BuildRoot -StackName Build-Module

    if ($BuildInfo.Path) {
        $ModuleSource = Split-Path -path $BuildInfo.Path -Parent -Resolve
    }
    else {
        $ModuleSource = Split-Path $BuildInfoSource -Parent
    }
    Write-Verbose "Module Source is now $ModuleSource"


    # These errors are caused by trying to parse valid module manifests without compiling the module first
    $ErrorsWeIgnore = "^" + @(
        "Modules_InvalidRequiredModulesinModuleManifest"
        "Modules_InvalidRootModuleInModuleManifest"
    ) -join "|^"

    # Combine the defaults with parameter values
    $ParameterValues = @{}
    foreach ($parameter in $Invocation.MyCommand.Parameters.GetEnumerator()) {
        $key = $parameter.Key
        # set if it doesn't exist, overwrite if the value is bound as a parameter
        if (!$BuildInfo.ContainsKey($key) -or ($Invocation.BoundParameters -and $Invocation.BoundParameters.ContainsKey($key))) {
            if ($null -ne ($value = Get-Variable -Name $key -ValueOnly -ErrorAction Ignore )) {
                if ($value -ne ($null -as $parameter.Value.ParameterType)) {
                    Write-Debug "    $key = $value"
                    $ParameterValues[$key] = $value
                }
            }
        }
    }

    $BuildInfo = $BuildInfo | Update-Object $ParameterValues

    # Make sure the Path is set and points at the actual manifest
    $BuildInfo.Path = ResolveModuleManifest $ModuleSource $BuildInfo.Path

    # Finally, add all the information in the module manifest to the return object
    $ModuleInfo = Get-Module $BuildInfo.Path -ListAvailable -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -ErrorVariable Problems

    # If there are any problems that count, fail
    if ($Problems = $Problems.Where({$_.FullyQualifiedErrorId -notmatch $ErrorsWeIgnore})) {
        foreach ($problem in $Problems) {
            Write-Error $problem
        }
        throw "Unresolvable problems in module manifest"
    }

    # Update the ModuleManifest with our build configuration
    $ModuleInfo = Update-Object -InputObject $ModuleInfo -UpdateObject $BuildInfo

    # Ensure the OutputDirectory makes sense (it's never blank anymore)
    if (![IO.Path]::IsPathRooted($ModuleInfo.OutputDirectory)) {
        # Relative paths are relative to the build.psd1 now
        $OutputDirectory = Join-Path $BuildRoot $ModuleInfo.OutputDirectory
        $ModuleInfo.OutputDirectory = $OutputDirectory
    }

    $ModuleInfo
}