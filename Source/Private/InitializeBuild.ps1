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
        [string]$SourcePath
    )
    # Read the caller's parameter values
    $ParameterValues = @{}
    foreach($parameter in (Get-Variable MyInvocation -Scope 1 -ValueOnly).MyCommand.Parameters.GetEnumerator()) {
        $key = $parameter.Key
        if($null -ne ($value = Get-Variable -Name $key -ValueOnly -ErrorAction Ignore )) {
            if($value -ne ($null -as $parameter.Value.ParameterType)) {
                $ParameterValues[$key] = $value
            }
        }
    }

    $ModuleSource = ResolveModuleSource $SourcePath
    Push-Location $ModuleSource -StackName Build-Module

    # These errors are caused by trying to parse valid module manifests without compiling the module first
    $ErrorsWeIgnore = "^" + @(
        "Modules_InvalidRequiredModulesinModuleManifest"
        "Modules_InvalidRootModuleInModuleManifest"
    ) -join "|^"

    # Read a build.psd1 configuration file for default parameter values
    $BuildInfo = Import-Metadata -Path (Join-Path $ModuleSource [Bb]uild.psd1)
    # Combine the defaults with parameter values
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

    # Ensure OutputDirectory
    if (!$ModuleInfo.OutputDirectory) {
        $OutputRoot = if($OutputRoot = Split-Path $ModuleSource) { $OutputRoot } else { $ModuleSource}
        $OutputDirectory = Join-Path $OutputRoot "$($ModuleInfo.Version)"
        Add-Member -Input $ModuleInfo -Type NoteProperty -Name OutputDirectory -Value $OutputDirectory -Force
    } elseif (![IO.Path]::IsPathRooted($ModuleInfo.OutputDirectory)) {
        $OutputRoot = if($OutputRoot = Split-Path $ModuleSource) { $OutputRoot } else { $ModuleSource}
        $OutputDirectory = Join-Path $OutputRoot $ModuleInfo.OutputDirectory
        Add-Member -Input $ModuleInfo -Type NoteProperty -Name OutputDirectory -Value $OutputDirectory -Force
    }

    $ModuleInfo
}