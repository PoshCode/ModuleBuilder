Function Import-CurrentFileAsModule
{
    [cmdletbinding()]
    param(
    [validateset("InSession","NewTab","Console","ConsoleNoProfile")]
    $Startup="InSession"
    )
    
    #get module path (single file or folder)
    $Modpath = $filePath = $psise.CurrentFile.FullPath
    $folder = split-path $filePath
    if(gci $folder -include *.psd1)
    {
        $modpath = $folder
    }
    
    #save if not already saved
    if($psise.CurrentFile.IsUntitled){Write-Error "Must save file first! Sorry didn't feel like implementing the dialog box!" -ErrorAction Stop}
    if(-not $psise.CurrentFile.IsSaved){$psise.CurrentFile.Save()}
    $global:WorkingModule = $null
    
    ## did they define a post processing function?
    if(Test-Path function:\PostModuleProcess)
    {
        Write-Verbose "Processing PostModuleProcess Function"
        $PostModuleProcess = (gi function:\postmoduleprocess).ScriptBlock
    }
    else
    {
        Write-Verbose "--Create a PostModuleProcess function to excute code after import--"
    }
    #start it up!
    switch ($Startup)
    {
        "insession"  
        {
                try {Import-Module $modpath -Force -ErrorAction Stop -Verbose:$false}
                catch{ write-error "Not a module file!" -ErrorAction Stop}
                if($postmoduleprocess)
                {
                    &$Postmoduleprocess
                }
        }
        "NewTab"
        {
            $tab = $psise.PowerShellTabs.Add()
            $tab.Invoke({Import-Module $filePath})
            if($PostModuleProcess)
            {
                $tab.Invoke($postmoduleprocess)
            }
        }
        {$_ -eq "Console" -or $_ -eq "ConsoleNoProfile"}
        {
            $arguments = @("-command `"Import-Module $filePath;$postmoduleprocess`"","-noexit")
            if($startup -eq "ConsoleNoProfile"){$arguments += "-noprofile"}

            start-process powershell.exe -arg $arguments
        }
    }
}



#create hot keys in ise, script only loads if in ISE, so no need to check

$psise.CurrentPowerShellTab.AddOnsMenu.Submenus
$MBMenu = $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add('Module Builder',$null,$null)
$null=$MBMenu.Submenus.Add('Load Module',{Import-CurrentFileAsModule},"F6")
$null=$MBMenu.Submenus.Add('Load Module Console',{Import-CurrentFileAsModule -Startup Console},"Shift+F6")
