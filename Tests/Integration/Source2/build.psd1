@{
    Path                     = "Source2.psd1"
    OutputDirectory          = "..\Result2"
    Generators      = @(
        @{ Generator = "ConvertTo-Script"; Function = "Set-Source"; GUID = '6b8e5f3a-2c1d-4e7b-9a4f-1c3e5d7b9a2f' }
    )
}
