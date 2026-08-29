function Write-Settings
{
	param([hashtable]$Settings, [string]$SettingsPath)

	if ($Settings -and $Settings.Count)
	{
		[pscustomobject]$Settings | ConvertTo-Json | Set-Content -LiteralPath $SettingsPath -Encoding UTF8
	}
}
