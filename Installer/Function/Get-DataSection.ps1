function Get-DataSection($data, [string]$name) {
	if (!$data) { return $null }
	if ($data.PSObject.Properties.Name -contains $name) { return $data.$name }
	return $null
}
