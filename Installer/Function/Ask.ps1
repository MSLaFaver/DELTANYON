function Ask([string]$prompt)
{
	$r = Read-Host "$prompt [Y/n]"
	$result = $true
	if ($r)
	{
		$result = $r -match '^[Yy]'
	}
	$result
}
