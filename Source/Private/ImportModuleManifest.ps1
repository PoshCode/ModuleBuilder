function ImportModuleManifest {
    [CmdletBinding()]
    param(
        [Alias("PSPath")]
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Path
    )
    process {
        # Get all the information in the module manifest
        $ModuleInfo = Get-Module $Path -ListAvailable -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -ErrorVariable Problems

        # Some versions fails silently. If the GUID is empty, we didn't get anything at all
        if ($ModuleInfo.Guid -eq [Guid]::Empty) {
            Write-Error "Cannot parse '$Path' as a module manifest, try Test-ModuleManifest for details"
            return
        }

        # Some versions show errors are when the psm1 doesn't exist (yet), but we don't care
        $ErrorsWeIgnore = "^" + (@(
            "Modules_InvalidRequiredModulesinModuleManifest"
            "Modules_InvalidRootModuleInModuleManifest"
        ) -join "|^")

        # If there are any OTHER problems we'll fail
        if ($Problems = $Problems.Where({ $_.FullyQualifiedErrorId -notmatch $ErrorsWeIgnore })) {
            foreach ($problem in $Problems) {
                Write-Error $problem
            }
            # Short circuit - don't output the ModuleInfo if there were errors
            return
        }

        # Workaround the fact that Get-Module returns the DefaultCommandPrefix as Prefix
        Update-Object -InputObject $ModuleInfo -UpdateObject @{ DefaultCommandPrefix = $ModuleInfo.Prefix; Prefix = "" }
    }
}
