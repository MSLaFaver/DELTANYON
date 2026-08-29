function Read-Settings
{
	param([string]$SettingsPath)

	$settings = @{}
	if (Test-Path -LiteralPath $SettingsPath)
	{
		try
		{
			$loaded = Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
			foreach ($prop in $loaded.PSObject.Properties)
			{
				if ($prop.Value)
				{
					$settings[$prop.Name] = [string]$prop.Value
				}
			}
		}
		catch
		{
		}
	}
	$settings
}
