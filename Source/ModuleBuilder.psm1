foreach ($file in Get-ChildItem "Private", "Public") {
    . $file.FullName
}
