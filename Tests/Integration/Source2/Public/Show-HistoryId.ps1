function Show-HistoryId {
    <#
        .SYNOPSIS
            Shows the ID of the command you're about to type (this WILL BE the History ID of the command you run)
    #>
    [CmdletBinding()]
    param()
    $MyInvocation.HistoryId
}
