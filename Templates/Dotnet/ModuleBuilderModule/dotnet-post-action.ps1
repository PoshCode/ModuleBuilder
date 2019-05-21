<#
  .SYNOPSIS
    Powershell script used as dotnet template post action
#>
Set-StrictMode -Version Latest

# Generate manifest
New-ModuleManifest -RootModule "{moduleName}" -Path "./Source/{moduleName}.psd1" -ModuleVersion 0.0.1

# Remove self
Remove-Item ./dotnet-post-action.ps1
