function Read-Settings {
	param(
		[string]$SettingsPath,
		[string]$Root
	)

	if (Test-Path -LiteralPath $SettingsPath) {
		try {
			$loaded = Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
			$settings = @{}
			foreach ($prop in $loaded.PSObject.Properties) {
				if ($prop.Value) { $settings[$prop.Name] = [string]$prop.Value }
			}
			return $settings
		} catch {}
	}

	$merged = @{}
	foreach ($legacy in @(
		@{ Path = (Join-Path $Root 'umt.json'); Key = 'UndertaleModCli' }
		@{ Path = (Join-Path $Root 'install.json'); Key = 'DeltaruneExe' }
	)) {
		if (!(Test-Path -LiteralPath $legacy.Path)) { continue }
		try {
			$v = (Get-Content -LiteralPath $legacy.Path -Raw -Encoding UTF8 | ConvertFrom-Json).($legacy.Key)
			if ($v) { $merged[$legacy.Key] = [string]$v }
		} catch {}
	}

	if ($merged.Count) {
		Write-Settings -Settings $merged -SettingsPath $SettingsPath -Root $Root
		return $merged
	}

	return @{}
}
