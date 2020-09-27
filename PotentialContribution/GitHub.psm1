function Publish-GitHub {
    <#
        .Synopsis
            Publish a release to a github project
    #>
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Path = '.',
        $Certificate,
        $Credential,
        $title,
        $Description,
        $Remote="origin",
        [switch]$draft,
        [switch]$Prerelease,
        [switch]$IncrementVersion
    )
    ## make sure its committed and all is ok
    $path = gi $path
    Write-Debug "Path: $path"
    Push-Location
    Set-Location $Path

    #not safe!
    #populate what info we can from the path
    $username, $repo = ((git remote -v | ?{$_ -like "*(push)"}).replace('.git','') -split '\s+')[1].split("/") | select -last 2
    $branch = git branch | ? {$_ -match "^\*\s+(.+)"} | %{$matches[1]}
    $moduleName = Split-Path $Path -Leaf

    Write-Debug "ModuleName: $moduleName"
    Write-Debug "Username: $username"
    Write-Debug "Repository: $repo"
    Write-Debug "Branch: $branch"

    $status = git status --short|?{$_ -match '(.)(.)\s+(.+)'} | %{[pscustomobject]@{X=$matches[1];Y=$matches[2];File=$matches[3]}}
    if($status)
    {
        if($status | ?{$_.x -ne '?'})
        {
            Write-Error "Work not commited!"
            break
        }
    }
    Write-Verbose "Status: Committed and up to date"

    ## update version and commit?
    ## this will be replaced, just a test for commit purposes
    $psd1 = gi ((gi $path).name + ".psd1")
    Write-Debug "PSD1: $psd1"


    $psd1data = (gc $psd1) | %{
    if($_ -match 'moduleversion\s*=(.+)')
    {
        $version = [version]($Matches[1].trim() -replace '''|"',"")
        Write-Verbose "Current Version: $version"
        if($IncrementVersion){Write-Verbose "Incrementing the version";$minor = $version.Minor+1}else{$version.Minor}
        $versionshort = "$($version.Major).$($minor)"
        $versionfull = "$versionshort.$(Get-Date -Format "yyyyMMdd.HHmm")"
        "ModuleVersion='$versionfull'"
        Write-Verbose "New Versioin: $versionfull"

    }
    else{$_}
    }
    if($IncrementVersion)
    {
        $psd1data | Out-File $psd1
    }

    #only needed if version is updated
    Write-Verbose "Commiting version data"
    git commit -a -m "Release Commit - Version Tag $versionfull" | Out-Null
    git push origin $branch

    Write-Verbose "Creating tag"
    $tag = "V$versionshort"
    git tag -a $tag -m "Auto Release version $versionfull"
    git push --tags

    Write-Verbose "Getting Github auth token"
    $token = Get-GitToken -Credential $Credential

    Write-Verbose "Creating the release"
    $GHRelease = New-GitHubRelease -username $username -repo $repo -token $token -tag $tag -branch $branch -Title $title -Description $Description -draft:$draft.IsPresent -Prerelease:$Prerelease.IsPresent

    ## create a release folder, maybe clear it first?

    $releaseFolder = join-path $path Release
    Write-Verbose "Creating release folder"
    New-Item -ItemType Directory $releaseFolder -ea 0 | out-null

    #create a folder for module files
    Write-Verbose "Creating copy of module"
    $modtemp = join-path $releaseFolder $moduleName
    Write-Debug "creating temp folder: $modtemp"
    New-Item -ItemType Directory $modtemp -ea 0 | Out-Null
    #get all files
    $filenames = git ls-tree -r $branch --name-only | ? {$_ -notlike ".*"}
    $files = $filenames | %{join-path . $_} | gi
    #copy files to module temp/release location
    copy $files $modtemp

    Write-Verbose "Signing moved files"
    if($Certificate)
    {
        gci $modtemp | Set-AuthenticodeSignature -Certificate $Certificate | Out-Null
    }


    ## create packages
    #poshcode/nuget/chocolatey
    ipmo $modtemp -Global
    sleep 1
    Write-Verbose "Creating nuget package"
    $nugetfiles = Compress-Module -Module $moduleName -OutputPath $releaseFolder -Force

    #exclude xml
    #todo: move packageinfo/nuspec to repo add/overwite etc
    #todo: rename nuget file to remove extend version info

    if($Certificate -and $nugetfiles)
    {
        Write-Verbose "Signing nuget"
        Set-AuthenticodeSignature -FilePath $nugetfiles -Certificate $Certificate
    }
    if($nugetfiles)
    {
        Write-Verbose "uploading nuget stuff"
        $results = $nugetfiles | %{Add-GitHubReleaseAsset -token $token -id $GHRelease.id -username $username -repo $repo -file $_}
    }

    ## zip
    Write-Verbose "Creating zip package"
    [Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
    $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
    $zipfile = Join-Path $releaseFolder "$moduleName.zip"
    [System.IO.Compression.ZipFile]::CreateFromDirectory($modtemp,$zipfile,$compressionLevel,$true)
    <#
    if($Certificate -and (Test-Path $zipfile))
    {
        Write-Verbose "Signing zip"
        Set-AuthenticodeSignature -FilePath $zipfile -Certificate $Certificate
    }
    #>
    if(Test-Path $zipfile)
    {
        Write-Verbose "Uploading zip"
        $results = Add-GitHubReleaseAsset -token $token -id $GHRelease.id -username $username -repo $repo -file $zipfile
    }
    Pop-Location
}

function New-GitHubRelease {
    param(
        $username,
        $repo,
        $token,
        $tag,
        $branch='master',
        $Title,
        $Description,
        [switch]$draft,
        [switch]$Prerelease
    )
    $url = "https://api.github.com/repos/$username/$repo/releases?access_token=$token"

    $details = ConvertTo-Json @{
          tag_name = $tag
          target_commitish=$branch
          name=$title
          body= $Description
          draft= $draft.IsPresent
          prerelease= $Prerelease.IsPresent
    }
    Write-Debug "Details:`n$details"
    Invoke-RestMethod -Uri $url -body $details -Method Post -ContentType 'application/json'
}

function New-GitHubRepo {
    #.Synopsis
    #   Create a new github Repository
    [CmdletBinding(DefaultParameterSetName="User")]
    param(
        # The name of the Repository to create
        [Parameter(Mandatory=$true)]
        [String]$Name,
        # A short description of the repository
        [String]$Description,
        # A URL with more information about the repository
        [String]$Homepage,
        # If set, initialize the repository with a readme...
        [switch]$Initialize,
        # The name of the LICENSE template to apply
        [String]$License,
        # The Organization to create the repository under (must have rights)
        [Parameter(ParameterSetName="Organization")]
        [String]$Organization,
        # UserName to create the repository under
        [Parameter(ParameterSetName="User")]
        [String]$username = $Script:UserName,

        $token = $Script:AuthToken
    )
    if($Organization) {
        $url = "https://api.github.com/orgs/$Organization/repos?access_token=$token"
    } else {
        $url = "https://api.github.com/user/repos?access_token=$token"
    }

    $params = @{
        name = $Name
    }
    if($Description) { $params.description = $Description }
    if($Homepage) { $params.homepage = $Homepage }
    if($Initialize) { $params.auto_init = "true" }

    $body = ConvertTo-Json $params -ErrorAction Stop
    Write-Debug "Request: $url`n$body"
    Invoke-RestMethod -Uri $url -body $body -Method Post -ContentType 'application/json' | % {
        $_.PSTypeNames.Insert(0, "PoshCode.ModuleBuilder.Github.Repository")
        $_
    }
}

Update-TypeData -TypeName "PoshCode.ModuleBuilder.Github.Repository" -DefaultDisplayPropertySet name, html_url, ssh_url -ErrorAction SilentlyContinue

#part of $rtn
function Add-GitHubReleaseAsset {
    param(
        $token,
        $id,
        $username,
        $repo,
        $file
    )

    $file = gi $file
    $uploadURL = "https://uploads.github.com/repos/$username/$repo/releases/$id/assets?name=$($file.name)&access_token=$token"
    irm -Uri $uploadURL -ContentType 'application/zip' -Body ([IO.File]::ReadAllBytes($file)) -Method Post
}

function Initialize-Git {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.Credential()]
        [System.Management.Automation.PSCredential]$Credential
    )

    $Script:UserName = $Credential.UserName
    $Script:AuthToken = Get-GitToken $Credential
}

function Get-GitToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.Credential()]
        [System.Management.Automation.PSCredential]$Credential
    )
    $params = @{
          Uri = 'https://api.github.com/authorizations';
          Headers = @{
            Authorization = 'Basic ' + [Convert]::ToBase64String(
              [Text.Encoding]::ASCII.GetBytes("$($Credential.UserName):$($Credential.GetNetworkCredential().Password)"));
          }

        }
    $rtn = Invoke-RestMethod @params

    #is looking for repo scope good enough? think so
    # could have multiple access tokens, grab the first one that has repo access i guess
    if($auth = $rtn | ? scopes -Contains "repo" | select -first 1)
    {
        $auth.token
    }
    else #create token
    {
        $data = @{
            scopes = @('repo')
            Note = "Created by ModuleBuilder"
            }
        $params.Add("ContentType",'application/json')
        $params.add("Body",(ConvertFrom-Json $data))
        try
        {
            (Invoke-RestMethod @params).token
        }
        catch
        {
            Write-Error "An unexpected error occurred (bad user/password?) $($Error[0])"
        }
    }
}
