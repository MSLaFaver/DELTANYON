function Write-Settings {
	param(
		[hashtable]$Settings,
		[string]$SettingsPath,
		[string]$Root
	)

	if (!$Settings -or !$Settings.Count) { return }

	[pscustomobject]$Settings | ConvertTo-Json | Set-Content -LiteralPath $SettingsPath -Encoding UTF8
	Remove-Item (Join-Path $Root 'umt.json'), (Join-Path $Root 'install.json') -ErrorAction SilentlyContinue
}
