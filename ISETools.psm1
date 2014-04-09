Function Import-CurrentFileAsModule
{
    [cmdletbinding()]
    param(
    [validateset("InSession","NewTab","Console","ConsoleNoProfile")]
    $Startup="InSession"
    )
    #get paths
    $filePath = $psise.CurrentFile.FullPath
    $folder = split-path $filePath
    #save if not already saved
    if($psise.CurrentFile.IsUntitled){Write-Error "Must save file first! Sorry didn't feel like implementing the dialog box!" -ErrorAction Stop}
    if(-not $psise.CurrentFile.IsSaved){$psise.CurrentFile.Save()}
    $global:WorkingModule = $null
    #import the folder or the file if its standalone
    try{ $Global:WorkingModule = Import-Module $folder -Force -ErrorAction Stop -PassThru -Verbose:$false | select -ExpandProperty name}
    catch{$folderFailed = $true}
    
    if($folderFailed)
    {
        try {Import-Module $filePath -Force -ErrorAction Stop -Verbose:$false}
        catch{ write-error "Not a module file!" -ErrorAction Stop}
    } 
    ##post processing
    if(Test-Path function:\PostModuleProcess)
    {
        Write-Verbose "Processing PostModuleProcess Function"
        PostModuleProcess
    }
    else
    {
        Write-Verbose "--Create a PostModuleProcess function to excute code after import--"
    }
    #Write-Verbose "Remove -verbose tag from last cmd in this file to stop verbose messaging"
}

Function Test-Module
{
    $filePath = $psise.CurrentFile.FullPath
    $folder = split-path $filePath
    #save if not already saved
    if($psise.CurrentFile.IsUntitled){Write-Error "Must save file first! Sorry didn't feel like implementing the dialog box!" -ErrorAction Stop}
    if(-not $psise.CurrentFile.IsSaved){$psise.CurrentFile.Save()}
    start powershell -ArgumentList "-noprofile -noexit -command `"cd d:\ps;ipmo $folder`""
}