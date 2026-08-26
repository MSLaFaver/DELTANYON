function Get-ManifestChapters($value) {
    if ($null -eq $value) { return @() }
    if ($value -is [System.Array]) { return @($value | ForEach-Object { [int]$_ }) }
    if ($value -is [ValueType]) { return @([int]$value) }
    if ($value.PSObject.Properties.Name -contains 'chapters') {
        $chapters = $value.chapters
        if ($chapters -is [System.Array]) { return @($chapters | ForEach-Object { [int]$_ }) }
        if ($null -ne $chapters) { return @([int]$chapters) }
    }
    return @()
}
