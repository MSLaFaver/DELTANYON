function Resolve-Exe([string]$path, [string]$leaf)
{
	$result = $null
	if ($path)
	{
		if ((Split-Path -Leaf $path) -ieq $leaf -and (Test-Path -LiteralPath $path))
		{
			$result = (Resolve-Path -LiteralPath $path).Path
		}
		else
		{
			$sibling = Join-Path ([IO.Path]::GetDirectoryName($path)) $leaf
			if (Test-Path -LiteralPath $sibling)
			{
				$result = (Resolve-Path -LiteralPath $sibling).Path
			}
		}
	}
	$result
}
