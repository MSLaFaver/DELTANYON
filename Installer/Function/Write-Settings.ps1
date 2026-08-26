function Write-Settings($settings) {
	$settings | ConvertTo-Json | Set-Content -LiteralPath $SettingsPath -Encoding UTF8
	Remove-Item (Join-Path $Root 'umt.json'), (Join-Path $Root 'install.json') -ErrorAction SilentlyContinue
}
