param($Task, $Utmt, $Root, $Csx)
$ErrorActionPreference = 'Stop'

$log = @("[$($Task.Tag)] Patching...")
try
{
	$id = Get-Random
	$work = Join-Path $env:TEMP "drml_ch$($Task.Ch)_${id}.win"
	$out = Join-Path $env:TEMP "drml_ch$($Task.Ch)_${id}_out.win"
	Copy-Item -LiteralPath $Task.DataWin -Destination $work -Force

	$log += '  Applying UTMT script...'
	$psi = New-Object System.Diagnostics.ProcessStartInfo
	$psi.FileName = $Utmt
	$psi.Arguments = "load `"$work`" -s `"$Csx`" -o `"$out`""
	$psi.WorkingDirectory = $Root
	$psi.UseShellExecute = $false
	$psi.CreateNoWindow = $true
	$psi.RedirectStandardOutput = $true
	$psi.RedirectStandardError = $true
	$psi.EnvironmentVariables['DRML_OVERRIDES'] = [string]$Task.Over
	$psi.EnvironmentVariables['DRML_PREFIXES'] = [string]$Task.Prefix
	$psi.EnvironmentVariables['DRML_POSTFIXES'] = [string]$Task.Post
	$psi.EnvironmentVariables['DRML_SOUNDS'] = [string]$Task.Sounds
	$psi.EnvironmentVariables['DRML_GAME_DIR'] = [IO.Path]::GetDirectoryName($Task.DataWin)
	$proc = [Diagnostics.Process]::Start($psi)
	$stdout = $proc.StandardOutput.ReadToEnd()
	$stderr = $proc.StandardError.ReadToEnd()
	$proc.WaitForExit()
	if ($proc.ExitCode)
	{
		$detail = ($stderr + $stdout).Trim()
		if ($detail)
		{
			foreach ($line in ($detail -split "`r?`n"))
			{
				$log += "  $line"
			}
		}
		throw "UndertaleModCli failed (exit $($proc.ExitCode))."
	}

	if (!(Test-Path -LiteralPath $out))
	{
		throw "UTMT did not write output: $out"
	}
	Remove-Item -LiteralPath $work -Force
	Move-Item -LiteralPath $out -Destination $work -Force
	Remove-Item -LiteralPath $Task.DataWin -Force
	Move-Item -LiteralPath $work -Destination $Task.DataWin -Force
	$log += '  OK!'

	[pscustomobject]@{
		Ch = $Task.Ch
		Tag = $Task.Tag
		Status = 'ok'
		Reason = $null
		Log = $log
	}
}
catch
{
	$reason = $_.Exception.Message
	$ex = $_.Exception.InnerException
	while ($ex)
	{
		if ($ex.Message)
		{
			$reason = "$reason`n$($ex.Message)"
		}
		$ex = $ex.InnerException
	}
	[pscustomobject]@{
		Ch = $Task.Ch
		Tag = $Task.Tag
		Status = 'fail'
		Reason = $reason
		Log = $log
	}
}
