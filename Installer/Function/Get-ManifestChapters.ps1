function Get-ManifestChapters($value)
{
	$result = @()
	if ($value -is [System.Array])
	{
		$result = @($value | ForEach-Object { [int]$_ })
	}
	elseif ($value -is [ValueType])
	{
		$result = @([int]$value)
	}
	elseif ($value.PSObject.Properties.Name -contains 'chapters')
	{
		$chapters = $value.chapters
		if ($chapters -is [System.Array])
		{
			$result = @($chapters | ForEach-Object { [int]$_ })
		}
		elseif ($null -ne $chapters)
		{
			$result = @([int]$chapters)
		}
	}
	$result
}
