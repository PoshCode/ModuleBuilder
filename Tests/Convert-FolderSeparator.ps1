function global:Convert-FolderSeparator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [switch]$Relative,
        [switch]$Validate
    )

    $Path = try {
        Microsoft.PowerShell.Management\Convert-Path $Path -EA Stop
    } catch [System.Management.Automation.DriveNotFoundException] {
        if ($Validate) { throw }
        $Drive = $Path -replace ":.*"
        $Path = $Path -replace "\w*:", (Get-PSDrive -PSProvider FileSystem)[0].Root
        try {
            Microsoft.PowerShell.Management\Convert-Path $Path -EA Stop
        } catch [System.Management.Automation.ItemNotFoundException] {
            $_.TargetObject
        }
    } catch [System.Management.Automation.ItemNotFoundException] {
        if ($Validate) { throw }
        $_.TargetObject
    }

    Write-Verbose "Path: $Path"
    if ($Relative) {
        $ConvertedPath = $Path
        while ($ConvertedPath -and -not ($Result = Resolve-Path $ConvertedPath -Relative -ErrorAction SilentlyContinue)) {
            $ConvertedPath = Split-Path $ConvertedPath
            Write-Verbose "ConvertedPath: $ConvertedPath"
        }

        Write-Verbose "Result: $Result"
        $Path = $Path -replace ([regex]::escape($ConvertedPath)), $Result
    }
    if ($Drive) {
        $Path -replace "\w*:", "$($Drive):"
    } else {
        $Path
    }
}
