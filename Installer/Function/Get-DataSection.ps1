function Get-DataSection($data, [string]$name)
{
	$result = $null
	if ($data -and $data.PSObject.Properties.Name -contains $name)
	{
		$result = $data.$name
	}
	$result
}
