function UpdateHashtable {
    [CmdletBinding()]
    param(
        # Base hashtable will be overwritten by the Update hashtable
        [Collections.IDictionary]$Base,

        # Overwrite hashtable
        [Collections.IDictionary]$Update,

        # A list of values which (if found on Base) should not be updated
        [string[]]$ImportantBaseProperties
    )

    foreach ($property in $Update.Keys) {
        if($property -notin $ImportantBaseProperties -or -not $Base.ContainsKey($property)) {
            $Base.$property = $Update.$property
        }
    }
    $Base

}