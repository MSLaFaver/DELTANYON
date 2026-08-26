function Ask([string]$prompt) {
	$r = Read-Host "$prompt [Y/n]"
	if (!$r) { return $true }
	$r -match '^[Yy]'
}
