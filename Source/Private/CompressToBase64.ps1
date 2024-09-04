function CompressToBase64 {
    <#
        .SYNOPSIS
            Compresses and encodes a module file for embedding into a script
        .DESCRIPTION
            Reads the raw bytes and then compress (gzip) them, before base64 encoding the result
        .EXAMPLE
            Get-ChildItem *.dll, *.psm1 | CompressToBase64 -ExpandScript ImportBase64Module > Script.ps1

            Script.ps1 will contain the base64 encoded (and compressed) contents of the files, piped to the ImportBase64Module function
        .LINK
            ImportBase64Module
    #>
    [CmdletBinding(DefaultParameterSetName = "Base64")]
    [OutputType([string])]
    param(
        # The path to the dll or script file to compress
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("PSPath")]
        [string[]]$Path,

        # If set, wraps the Base64 encoded content in the specified command
        [Parameter(Mandatory, Position = 1, ParameterSetName = "ExpandScriptName")]
        [string]$ExpandScriptName,

        # If set, wraps the Base64 encoded content in the specified command
        [Parameter(Mandatory, Position = 1, ParameterSetName = "ExpandScript")]
        [ScriptBlock]$ExpandScript
    )
    begin {
        $Result = @()
        if ($ExpandScriptName -and !$ExpandScript) {
            $ExpandScript = (Get-Command $ExpandScriptName).ScriptBlock
        }
    }
    process {
        foreach ($File in $Path | Convert-Path) {
            $Source = [System.IO.MemoryStream][System.IO.File]::ReadAllBytes($File)
            $OutputStream = [System.IO.Compression.DeflateStream]::new(
                [System.IO.MemoryStream]::new(),
                [System.IO.Compression.CompressionMode]::Compress)
            $Source.CopyTo($OutputStream)
            $OutputStream.Flush()
            $ByteArray = $OutputStream.BaseStream.ToArray()
            if (!$ExpandScript) {
                [Convert]::ToBase64String($ByteArray)
            } else {
                $Result += [Convert]::ToBase64String($ByteArray)
            }
        }
    }
    end {
        if ($ExpandScript) {
            [ScriptBlock]::Create("@(`n'$($Result -join "'`n'")'`n)|.{`n${ExpandScript}`n}").ToString()
        }
    }
}
