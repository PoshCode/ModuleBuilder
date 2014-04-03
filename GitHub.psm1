<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Publish-Git
{
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Path = '.'

        


    )
    ## make sure its committed and all is ok
        
    $branch = git branch | ? {$_ -match "^\*\s+(.+)"} | %{$matches[1]}
    Write-Verbose "Current Branch: $branch"
    
    $status = git status $path --short|?{$_ -match '(.)(.)\s+(.+)'} | %{[pscustomobject]@{X=$matches[1];Y=$matches[2];File=$matches[3]}}
    if($status)
    {
        Write-Error "Work not commited!"
        break
    }
    Write-Verbose "Status: Committed and up to date"
    
    ## update version and commit?

    ## sign files
    ## add to package (zip/nuget)
    ## sign packages?
    ## roll back changes
    ## add tag
    ## create release
    
}


if($Increment) { 
  if($Version.Revision -ge 0) { 
    $Version = New-Object Version $Version.Major, $Version.Minor, $Version.Build, ($Version.Revision + 1) 
  } elseif($Version.Build -ge 0) { 
    $Version = New-Object Version $Version.Major, $Version.Minor, ($Version.Build + 1) 
  } elseif($Version.Minor -ge 0) { 
    $Version = New-Object Version $Version.Major, ($Version.Minor + 1) 
  } 
}