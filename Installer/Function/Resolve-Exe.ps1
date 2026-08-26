function Resolve-Exe([string]$path, [string]$leaf) {
	if (!$path) { return $null }
	if ((Split-Path -Leaf $path) -ieq $leaf -and (Test-Path -LiteralPath $path)) { return (Resolve-Path -LiteralPath $path).Path }
	$sibling = Join-Path ([IO.Path]::GetDirectoryName($path)) $leaf
	if (Test-Path -LiteralPath $sibling) { return (Resolve-Path -LiteralPath $sibling).Path }
}
