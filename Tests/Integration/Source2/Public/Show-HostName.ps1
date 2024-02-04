function Show-HostName {
    <#
        .SYNOPSIS
            Gets the hostname of the current machine
        .DESCRIPTION
            Calls [Environment]::MachineName
    #>
    [OutputType([string])]
    [CmdletBinding(DefaultParameterSetName = "SimpleFormat")]
    param()
    [Environment]::MachineName
}
