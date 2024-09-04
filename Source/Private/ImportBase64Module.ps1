# The comment-based help for this function is outside the function to avoid packing it
# Normally, I put it inside, but I do not want this in packed scripts

<#
    .SYNOPSIS
        Expands Base64+GZip strings and loads the result as an assembly or module
    .DESCRIPTION
        Converts Base64 encoded string to bytes and decompresses (gzip) it.
        If the result is a valid assembly, it is loaded.
        Otherwise, it is imported as a module.
    .PARAMETER Base64Content
        A Base64 encoded and deflated assembly or script
    .LINK
        CompressToBase64
#>
function ImportBase64Module {
    [CmdletBinding(DefaultParameterSetName = "ByteArray")]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Base64Content
    )
    process {
        $Out = [System.IO.MemoryStream]::new()
        $In = [System.IO.MemoryStream][System.Convert]::FromBase64String($Base64Content)
        $zip = [System.IO.Compression.DeflateStream]::new($In, [System.IO.Compression.CompressionMode]::Decompress)
        $zip.CopyTo($Out)
        trap [System.IO.InvalidDataException] {
            Write-Debug "Base64Content not Compressed. Skipping Deflate."
            $In.CopyTo($Out)
            continue
        }
        $null = $Out.Seek(0, "Begin")
        $null = [System.Reflection.Assembly]::Load($Out.ToArray())
        trap [BadImageFormatException] {
            Write-Debug "Base64Content not an Assembly. Trying New-Module and ScriptBlock.Create."
            $null = $Out.Seek(0, "Begin")
            # Use StreamReader to handle possible BOM
            $Source = [System.IO.StreamReader]::new($Out, $true).ReadToEnd()
            $null = New-Module ([ScriptBlock]::Create($Source)) -Verbose:$false | Import-Module -Scope Global -Verbose:$false
            continue
        }
    }
}
