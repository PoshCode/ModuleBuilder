function SetModuleContent {
    <#
        .SYNOPSIS
            A wrapper for Set-Content that handles arrays of file paths
        .DESCRIPTION
            The implementation here is strongly dependent on Build-Module doing the right thing
            Build-Module can optionally pass a PREFIX or SUFFIX, but otherwise only passes files

            Because of that, SetModuleContent doesn't test for that

            The goal here is to pretend this is a pipeline, for the sake of memory and file IO
    #>
    [CmdletBinding()]
    param(
        # Where to write the joined output
        [Parameter(Position=0, Mandatory)]
        [string]$OutputPath,

        # Input files, the scripts that will be copied to the output path
        # The FIRST and LAST items can be text content instead of file paths.
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("PSPath", "FullName")]
        [AllowEmptyCollection()]
        [string[]]$SourceFile,

        # The working directory (allows relative paths for other values)
        [string]$WorkingDirectory = $pwd,

        # The encoding defaults to UTF8 (or UTF8NoBom on Core)
        [Parameter(DontShow)]
        [string]$Encoding = $(if($IsCoreCLR) { "UTF8Bom" } else { "UTF8" })
    )
    begin {
        Push-Location $WorkingDirectory -StackName SetModuleContent
        $ContentStarted = $false # There has been no content yet

        # Create a proxy command style scriptblock for Set-Content to keep the file handle open
        $SetContentCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Management\Set-Content', [System.Management.Automation.CommandTypes]::Cmdlet)
        $SetContent = {& $SetContentCmd -Path $OutputPath -Encoding $Encoding }.GetSteppablePipeline($myInvocation.CommandOrigin)
        $SetContent.Begin($true)
    }
    process  {
        foreach($file in $SourceFile) {
            if($SourceName = Resolve-Path $file -Relative -ErrorAction SilentlyContinue) {
                Write-Verbose "Adding $SourceName"
                $SetContent.Process("#Region '$SourceName' 0")
                Get-Content $SourceName -OutVariable source | ForEach-Object { $SetContent.Process($_) }
                $SetContent.Process("#EndRegion '$SourceName' $($Source.Count)")
            } else {
                if(!$ContentStarted) {
                    $SetContent.Process("#Region 'PREFIX' 0")
                    $SetContent.Process($file)
                    $SetContent.Process("#EndRegion 'PREFIX'")
                    $ContentStarted = $true
                } else {
                    $SetContent.Process("#Region 'SUFFIX' 0")
                    $SetContent.Process($file)
                    $SetContent.Process("#EndRegion 'SUFFIX'")
                }
            }
        }
    }
    end {
        $SetContent.End()
        Pop-Location -StackName SetModuleContent
    }
}
