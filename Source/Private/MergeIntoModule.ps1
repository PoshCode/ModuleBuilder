function MergeIntoModule {
    [CmdletBinding()]
    param(
        # The ModuleInfo object of the source Module Manifest to Merge into one PSM1,
        # potentially extended with a Suffix or Prefix as per Build-Module
        [Parameter(ValueFromPipelineByPropertyName)]
        $ModuleInfo,

        # File to write the merged PSM1 to
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        $RootModule,

        # Source Directories too include in the merge based on the $ModuleInfo.ModuleBase
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$SourceDirectories = @(
            "Enum", "Classes", "Private", "Public"
        ),

        # Script files to merge into the PSM1
        [Parameter(ValueFromPipelineByPropertyName, ValueFromPipeline)]
        $AllScripts = (Get-ChildItem -Path $SourceDirectories.ForEach{ Join-Path $ModuleInfo.ModuleBase $_ } -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue)    
    )

    begin {
        $usingList = New-Object System.Collections.Generic.List[String]
        $merge = New-Object System.Text.StringBuilder
        $Separator = "`n"

        if ($ModuleInfo.Prefix) {
            Write-Verbose "Adding Prefix"
            $prefix = if (Test-Path $ModuleInfo.Prefix) {
                $SourceName = Resolve-Path $ModuleInfo.Prefix -Relative
                "#Region '$SourceName' 0"
                Get-Content $SourceName -OutVariable source
                "#EndRegion '$SourceName' $($Source.Count)"
            } else {
                "#Region 'PREFIX' 0"
                $ModuleInfo.Prefix
                "#EndRegion 'PREFIX'"
            }
            $null = $merge.AppendFormat('{0}{1}', ($prefix | Out-String), $Separator)
        } 
    }
    process {
        foreach ($file in $AllScripts) {
            $SourceName = Resolve-Path $file.FullName -Relative
            Write-Verbose "Adding $SourceName"
                
            $content = & {
                "#Region '$SourceName' 0"
                $file | Get-Content | ForEach-Object {
                    # Extracting the Using Statements to be insterted at the top of the psm1 file
                    if ($_ -match '^using') {
                        $usingList.Add($_)
                    } else {
                        $_.TrimEnd()
                    }
                }
                "#EndRegion '$SourceName'"
            }
            $null = $merge.AppendFormat('{0}{1}', ($content | Out-String), $Separator)
        }
    }
    end {
        if ($ModuleInfo.Suffix) {
            $Suffix = if (Test-Path $ModuleInfo.Suffix) {
                $SourceName = Resolve-Path $ModuleInfo.Suffix -Relative
                "#Region '$SourceName' 0"
                Get-Content $SourceName
                "#EndRegion '$SourceName'"
            } else {
                "#Region 'SUFFIX' 0"
                $ModuleInfo.Suffix
                "#EndRegion 'SUFFIX'"
            }
            $null = $merge.AppendFormat('{0}{1}', ($Suffix | Out-String), $Separator)
        }

        $null = $merge.Insert(0, ($usingList | Sort-Object | Get-Unique | Out-String))
        Write-Verbose "Writing content to $RootModule"
        # BUGBUG: Note that the encoding value *MUST* be in quotes for PowerShell 6
        $merge.ToString() | Set-Content -Path $RootModule -Encoding "$($ModuleInfo.Encoding)"
    } 
}