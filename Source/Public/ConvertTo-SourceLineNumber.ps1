function ConvertTo-SourceLineNumber {
    <#
        .SYNOPSIS
            Convert the line number in a built module to a file and line number in source
        .EXAMPLE
            ConvertTo-SourceLineNumber -SourceFile ~\ErrorMaker.psm1 -SourceLineNumber 27
        .EXAMPLE
            ConvertTo-SourceLineNumber -PositionMessage "At C:\Users\Joel\OneDrive\Documents\PowerShell\Modules\ErrorMaker\ErrorMaker.psm1:27 char:4"
    #>
    [Alias("Convert-LineNumber")]
    [CmdletBinding(DefaultParameterSetName="FromString")]
    param(
        # A position message as found in PowerShell's error messages, ScriptStackTrace, or InvocationInfo
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName="FromString")]
        [string]$PositionMessage,

        # The SourceFile (from an InvocationInfo) is the module psm1 path
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, Position=0, ParameterSetName="FromInvocationInfo")]
        [Alias("PSCommandPath", "File", "ScriptName", "Script")]
        [string]$SourceFile,

        # The SourceLineNumber (from an InvocationInfo) is the module line number
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, Position=1, ParameterSetName="FromInvocationInfo")]
        [Alias("LineNumber", "Line", "ScriptLineNumber")]
        [int]$SourceLineNumber,

        # The actual InvocationInfo
        [Parameter(ValueFromPipeline, DontShow, ParameterSetName="FromInvocationInfo")]
        [psobject]$InputObject,

        # If set, passes through the InputObject, overwriting the SourceFile and SourceLineNumber.
        # Otherwise, creates a new SourceLocation object with just those properties.
        [Parameter(ParameterSetName="FromInvocationInfo")]
        [switch]$Passthru
    )
    begin {
        $filemap = @{}
    }
    process {
        if ($PSCmdlet.ParameterSetName -eq "FromString") {
            $Invocation = ParseLineNumber $PositionMessage
            $SourceFile = $Invocation.SourceFile
            $SourceLineNumber = $Invocation.SourceLineNumber
        }
        if (!(Test-Path $SourceFile)) {
            throw "'$SourceFile' does not exist"
        }
        Push-Location (Split-Path $SourceFile)
        try {
            if (!$filemap.ContainsKey($SourceFile)) {
                # Note: the new pattern is #Region but the old one was # BEGIN
                $regions = Select-String '^(?:#Region|# BEGIN) (?<SourceFile>.*) (?<LineNumber>-?\d+)?$' -Path $SourceFile
                if ($regions.Count -eq 0) {
                    Write-Warning "No SourceMap for $SourceFile"
                    return
                }
                $filemap[$SourceFile] = @($regions.ForEach{
                        [PSCustomObject]@{
                            PSTypeName = "BuildSourceMapping"
                            SourceFile = $_.Matches[0].Groups["SourceFile"].Value.Trim("'")
                            StartLineNumber = $_.LineNumber
                            # This offset is added when calculating the line number
                            # because of the new line we're adding prior to the content
                            # of each script file in the built module.
                            Offset = $_.Matches[0].Groups["LineNumber"].Value
                        }
                    })
            }

            $hit = $filemap[$SourceFile]

            # These are all negative, because BinarySearch returns the match *after* the line we're searching for
            # We need the match *before* the line we're searching for
            # And we need it as a zero-based index:
            $index = -2 - [Array]::BinarySearch($hit.StartLineNumber, $SourceLineNumber)
            $Source = $hit[$index]

            if($Passthru) {
                $InputObject |
                    Add-Member -MemberType NoteProperty -Name SourceFile -Value $Source.SourceFile -PassThru -Force |
                    Add-Member -MemberType NoteProperty -Name SourceLineNumber -Value ($SourceLineNumber - $Source.StartLineNumber + $Source.Offset) -PassThru -Force
            } else {
                [PSCustomObject]@{
                    PSTypeName = "SourceLocation"
                    SourceFile = $Source.SourceFile
                    SourceLineNumber = $SourceLineNumber - $Source.StartLineNumber + $Source.Offset
                }
            }
        } finally {
            Pop-Location
        }
    }
}
