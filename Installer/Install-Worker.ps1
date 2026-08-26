param($Task, $Umt, $Root, $Csx)
$ErrorActionPreference = 'Stop'

$log = @("[$($Task.Tag)] Patching...")
try {
	$id = Get-Random
	$work = Join-Path $env:TEMP "drml_ch$($Task.Ch)_${id}.win"
	$out = Join-Path $env:TEMP "drml_ch$($Task.Ch)_${id}_out.win"
	$listDir = Join-Path $env:TEMP "drml_lists_$($Task.Ch)_${id}"
	Copy-Item -LiteralPath $Task.DataWin -Destination $work -Force

	New-Item -ItemType Directory -Path $listDir -Force | Out-Null
	foreach ($pair in @(
		@{ File = 'override.txt'; Value = $Task.Over }
		@{ File = 'prefix.txt'; Value = $Task.Prefix }
		@{ File = 'postfix.txt'; Value = $Task.Post }
		@{ File = 'sounds.txt'; Value = $Task.Sounds }
	)) {
		if ($pair.Value) {
			Set-Content -LiteralPath (Join-Path $listDir $pair.File) -Value $pair.Value -Encoding UTF8 -NoNewline
		}
	}

	$log += '  Applying UMT script...'
	$psi = New-Object System.Diagnostics.ProcessStartInfo
	$psi.FileName = $Umt
	$psi.Arguments = "load `"$work`" -s `"$Csx`" -o `"$out`""
	$psi.WorkingDirectory = $Root
	$psi.UseShellExecute = $false
	$psi.CreateNoWindow = $true
	$psi.RedirectStandardOutput = $true
	$psi.RedirectStandardError = $true
	$psi.EnvironmentVariables['DRML_LIST_DIR'] = $listDir
	$psi.EnvironmentVariables['DRML_GAME_DIR'] = [IO.Path]::GetDirectoryName($Task.DataWin)
	$proc = [Diagnostics.Process]::Start($psi)
	$stdout = $proc.StandardOutput.ReadToEnd()
	$stderr = $proc.StandardError.ReadToEnd()
	$proc.WaitForExit()
	if ($proc.ExitCode) {
		$detail = ($stderr + $stdout).Trim()
		if ($detail.Length -gt 500) { $detail = $detail.Substring($detail.Length - 500) }
		if ($detail) { $log += "  $detail" }
		throw "UndertaleModCli failed (exit $($proc.ExitCode))."
	}
	Remove-Item -LiteralPath $listDir -Recurse -Force -ErrorAction SilentlyContinue

	if (!(Test-Path -LiteralPath $out)) { throw "UMT did not write output: $out" }
	Remove-Item -LiteralPath $work -Force
	Move-Item -LiteralPath $out -Destination $work -Force
	Remove-Item -LiteralPath $Task.DataWin -Force
	Move-Item -LiteralPath $work -Destination $Task.DataWin -Force
	$log += '  OK'

	[pscustomobject]@{ Ch = $Task.Ch; Tag = $Task.Tag; Status = 'ok'; Reason = $null; Log = $log }
} catch {
	[pscustomobject]@{ Ch = $Task.Ch; Tag = $Task.Tag; Status = 'fail'; Reason = $_.Exception.Message; Log = $log }
}
