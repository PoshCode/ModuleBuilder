<#
  .SYNOPSIS
    Powershell script used as dotnet template post action
#>
Set-StrictMode -Version Latest

# generate manifest
$manifestPath = "./Source/{moduleName}.psd1"
New-ModuleManifest -RootModule "{moduleName}" -Path $manifestPath -ModuleVersion 0.0.1

# convert manifest to UTF-8 without BOM
$content = Get-Content $manifestPath
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllLines($manifestPath, $content, $Utf8NoBomEncoding)

# delete self
Remove-Item ./dotnet-post-action.ps1
