function CopyReadMe {
    [CmdletBinding()]
    param(
        # The path to the ReadMe document to copy
        [Parameter(ValueFromPipelineByPropertyName)]
        [AllowNull()][AllowEmptyString()]
        [string]$ReadMe,

        # The name of the module -- because the file is renamed to about_$ModuleName.help.txt
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [Alias("Name")]
        [string]$ModuleName,

        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [string]$OutputDirectory,

        # The culture (language) to store the ReadMe as (defaults to "en")
        [Parameter(ValueFromPipelineByPropertyName)]
        [Globalization.CultureInfo]$Culture = $(Get-UICulture),

        # If set, overwrite the existing readme
        [Switch]$Force
    )
    process {
        # Copy the readme file as an about_ help file
        Write-Verbose "Test for ReadMe: $Pwd/$($ReadMe)"
        if ($ReadMe -and (Test-Path $ReadMe -PathType Leaf)) {
            # Make sure there's a language path
            $LanguagePath = Join-Path $OutputDirectory $Culture
            if (!(Test-Path $LanguagePath -PathType Container)) {
                $null = New-Item $LanguagePath -Type Directory -Force
            }
            Write-Verbose "Copy ReadMe to: $LanguagePath"

            $about_module = Join-Path $LanguagePath "about_$($ModuleName).help.txt"
            if (!(Test-Path $about_module)) {
                Write-Verbose "Turn readme into about_module"
                Copy-Item -LiteralPath $ReadMe -Destination $about_module -Force:$Force
            }
        }
    }
}
