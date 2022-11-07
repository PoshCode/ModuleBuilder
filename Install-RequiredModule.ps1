Push-Location $PSScriptRoot
try {
    $Script = Install-Script Install-RequiredModule -PassThru -Force
    & (Join-Path $Script.InstalledLocation Install-RequiredModule.ps1)
} finally {
    Pop-Location
}
