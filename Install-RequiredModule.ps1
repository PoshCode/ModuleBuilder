Push-Location $PSScriptRoot
try {
    Install-Script Install-RequiredModule
    Install-RequiredModule
} finally {
    Pop-Location
}
