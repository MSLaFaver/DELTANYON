function Read-Settings {
	if (Test-Path -LiteralPath $SettingsPath) {
		try { return Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
	}
	$merged = @{}
	foreach ($legacy in @(
		@{ Path = (Join-Path $Root 'umt.json'); Key = 'UndertaleModCli' }
		@{ Path = (Join-Path $Root 'install.json'); Key = 'DeltaruneExe' }
	)) {
		if (!(Test-Path -LiteralPath $legacy.Path)) { continue }
		try {
			$v = (Get-Content -LiteralPath $legacy.Path -Raw -Encoding UTF8 | ConvertFrom-Json).($legacy.Key)
			if ($v) { $merged[$legacy.Key] = $v }
		} catch {}
	}
	if ($merged.Count) {
		$obj = [pscustomobject]$merged
		Write-Settings $obj
		return $obj
	}
}
