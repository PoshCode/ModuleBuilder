function Convert-LineNumber {
    <#
        .SYNOPSIS
            Convert the line number in a built module to a file and line number in source
        .EXAMPLE
            Convert-LineNumber -ScriptName ~\ErrorMaker.psm1 -ScriptLineNumber 27
        .EXAMPLE
            Convert-LineNumber -PositionMessage "At C:\Users\Joel\OneDrive\Documents\PowerShell\Modules\ErrorMaker\ErrorMaker.psm1:27 char:4"
    #>
    [CmdletBinding(DefaultParameterSetName="FromInvocationInfo")]
    param(
        # A position message as found in PowerShell's error messages, ScriptStackTrace, or InvocationInfo
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName="FromString")]
        [string]$PositionMessage,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, Position=0, ParameterSetName="FromInvocationInfo")]
        [Alias("PSCommandPath")]
        [string]$ScriptName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, Position=1, ParameterSetName="FromInvocationInfo")]
        [Alias("LineNumber")]
        [int]$ScriptLineNumber,

        # Output paths as short paths, relative to the SourceRoot
        [switch]$Relative
    )
    begin {
        $filemap = @{}
        # # Conditionally define the Resolve function as either Convert-Path or Resolve-Path
        # ${function:Resolve} = if ($Relative) {
        #     { process {
        #             $_ | Resolve-Path -Relative
        #         } }
        # } else {
        #     { process {
        #             $_ | Convert-Path
        #         } }
        # }
    }
    process {
        if($PSCmdlet.ParameterSetName -eq "FromString") {
            $Invocation = ParseLineNumber $PositionMessage
            $ScriptName = $Invocation.ScriptName
            $ScriptLineNumber = $Invocation.ScriptLineNumber
        }
        $PSScriptRoot = Split-Path $ScriptName

        if(!(Test-Path $ScriptName)) {
            throw "'$ScriptName' does not exist"
        }

        Push-Location $PSScriptRoot
        try {
            if (!$filemap.ContainsKey($ScriptName)) {
                # Note: the new pattern is #Region but the old one was # BEGIN
                $matches = Select-String '^(?:#Region|# BEGIN) (?<ScriptName>.*) (?<LineNumber>\d+)?$' -Path $ScriptName
                $filemap[$ScriptName] = @($matches.ForEach{
                        [PSCustomObject]@{
                            PSTypeName = "BuildSourceMapping"
                            ScriptName = $_.Matches[0].Groups["ScriptName"].Value.Trim("'")
                            StartLineNumber = $_.LineNumber
                        }
                    })
            }

            $hit = $filemap[$ScriptName]

            # These are all negative, because BinarySearch returns the match *after* the line we're searching for
            # We need the match *before* the line we're searching for
            # And we need it as a zero-based index:
            $index = -2 - [Array]::BinarySearch($hit.StartLineNumber, $ScriptLineNumber)
            $Source = $hit[$index]

            [PSCustomObject]@{
                PSTypeName = "SourceLocation"
                ScriptName = $Source.ScriptName
                ScriptLineNumber = $ScriptLineNumber - $Source.StartLineNumber
            }
        } finally {
            Pop-Location
        }
    }
}
