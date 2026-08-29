param([switch]$y)
$ErrorActionPreference = 'Stop'

if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
	$exe = if (Test-Path (Join-Path $PSHOME 'powershell.exe')) { Join-Path $PSHOME 'powershell.exe' } else { 'powershell.exe' }
	$psArgs = @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
	if ($y) { $psArgs += '-y' }
	& $exe @psArgs
	exit $LASTEXITCODE
}

$Root = $PSScriptRoot
$Mod = (Resolve-Path (Join-Path $Root '..\Mod')).Path
$Manifest = Join-Path $Mod 'manifest.json'
$Deploy = Join-Path $Mod 'Deploy'
$Csx = Join-Path $Root 'UtmtApi.csx'
$Worker = Join-Path $Root 'Install-Worker.ps1'
$SettingsPath = Join-Path $Root 'settings.json'

$FunctionDir = Join-Path $Root 'Function'
foreach ($f in @(
	'Ask.ps1', 'Resolve-Exe.ps1', 'Write-Settings.ps1', 'Read-Settings.ps1',
	'Get-ManifestChapters.ps1', 'Get-DataSection.ps1'
)) {
	. (Join-Path $FunctionDir $f)
}

$InstallerSettings = Read-Settings -SettingsPath $SettingsPath -Root $Root
if (!$InstallerSettings) { $InstallerSettings = @{} }

function End([int]$code) {
	Write-Host ''
	if ($code) { Write-Host 'Installation failed.' }
	cmd /c pause
	exit $code
}

function Pick([string]$title, [string]$filter) {
	Add-Type -AssemblyName System.Windows.Forms | Out-Null
	$d = New-Object System.Windows.Forms.OpenFileDialog
	$d.Title = $title; $d.Filter = $filter; $d.CheckFileExists = $true
	if ($d.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
	$d.FileName
}

function Set-Setting([string]$key, [string]$value) {
	$script:InstallerSettings[$key] = $value
	Write-Settings -Settings $script:InstallerSettings -SettingsPath $SettingsPath -Root $Root
}

function Get-Saved([string]$key, [string]$leaf, [string]$label) {
	$path = Resolve-Exe $script:InstallerSettings[$key] $leaf
	if ($path) {
		if ($y -or (Ask "Use saved $label? ($path)")) {
			Write-Host "$label (saved): $path"
			Set-Setting $key $path
			return $path
		}
	} elseif ($script:InstallerSettings.ContainsKey($key)) {
		Write-Host "Saved $label path was missing."
		$script:InstallerSettings.Remove($key) | Out-Null
		Write-Settings -Settings $script:InstallerSettings -SettingsPath $SettingsPath -Root $Root
	}
}

function Resolve-Program {
	param(
		[string]$Key, [string]$Leaf, [string]$Label, [string]$DisplayName,
		[string]$PickTitle, [string]$PickFilter, [string]$InvalidMsg,
		[scriptblock]$Discover, [string]$DiscoverTag, [switch]$AskDiscover
	)
	$path = Get-Saved $Key $Leaf $Label
	if ($path) { return $path }

	if ($Discover) {
		$path = & $Discover
		if ($path) {
			if (!$AskDiscover -or $y -or (Ask "Use default $Label? ($path)")) {
				Set-Setting $Key $path
				Write-Host "$DisplayName ($DiscoverTag): $path"
				return $path
			}
			$path = $null
		}
	}

	$picked = Pick $PickTitle $PickFilter
	if (!$picked) { End 0 }
	$path = Resolve-Exe $picked $Leaf
	if (!$path) { throw ($InvalidMsg -f $picked) }
	Set-Setting $Key $path
	Write-Host "${DisplayName}: $path"
	$path
}

function Find-SteamGame {
	foreach ($key in 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam') {
		if (!(Test-Path -LiteralPath $key)) { continue }
		$steam = (Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue).InstallPath
		if (!$steam -or !(Test-Path -LiteralPath $steam)) { continue }
		$libs = @($steam)
		$vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
		if (Test-Path -LiteralPath $vdf) {
			$libs += (Get-Content -LiteralPath $vdf -Encoding UTF8 | Where-Object { $_ -match '"path"\s+"(.+)"' } | ForEach-Object { $Matches[1] -replace '\\\\', '\' })
		}
		foreach ($lib in ($libs | Select-Object -Unique)) {
			$exe = Join-Path $lib 'steamapps\common\DELTARUNE\DELTARUNE.exe'
			if (Test-Path -LiteralPath $exe) { return (Resolve-Path -LiteralPath $exe).Path }
		}
	}
}

function ChapterTag([int]$ch) {
	if ($ch -eq 0) { 'Root' } else { "Chapter $ch" }
}

function WinPaths([string]$install, [int]$ch) {
	$base = if ($ch -eq 0) { $install } else { Join-Path $install "chapter${ch}_windows" }
	$bk = Join-Path $base 'backup'
	[pscustomobject]@{ DataWin = Join-Path $base 'data.win'; Backup = Join-Path $bk 'data.win'; BackupDir = $bk }
}

function Get-CodeJobs($section, [int]$ch) {
	if (!$section) { return @() }
	$jobs = @()
	foreach ($prop in $section.PSObject.Properties) {
		$chapters = Get-ManifestChapters $prop.Value
		if ($chapters -notcontains $ch) { continue }
		$source = if ($null -eq $prop.Value) { $prop.Name }
			elseif ($prop.Value.PSObject.Properties.Name -contains 'from') { [string]$prop.Value.from }
			else { $prop.Name }
		$jobs += if ($source -eq $prop.Name) { $prop.Name } else { "$($prop.Name)@$source" }
	}
	$jobs
}

function Chapters($m) {
	$nums = @()
	$code = Get-DataSection $m.data 'code'
	foreach ($name in @('override', 'prefix', 'postfix')) {
		$section = Get-DataSection $code $name
		if (!$section) { continue }
		foreach ($p in $section.PSObject.Properties) {
			foreach ($n in (Get-ManifestChapters $p.Value)) { $nums += $n }
		}
	}
	$sounds = Get-DataSection $m.data 'sounds'
	if ($sounds) {
		foreach ($p in $sounds.PSObject.Properties) {
			foreach ($n in (Get-ManifestChapters $p.Value)) { $nums += $n }
		}
	}
	$nums | Sort-Object -Unique
}

try {
	Write-Host "`n========================================`n  DELTARUNE Mod Loader`n========================================`n"
	if (!(Test-Path -LiteralPath $Manifest)) { throw "manifest.json not found: $Manifest" }
	if (!(Test-Path -LiteralPath $Csx)) { throw 'Missing UtmtApi.csx in Installer folder.' }
	if (!(Test-Path -LiteralPath $Worker)) { throw 'Missing Install-Worker.ps1 in Installer folder.' }

	$m = Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json

	$game = Resolve-Program `
		-Key 'DeltaruneExe' -Leaf 'DELTARUNE.exe' -Label 'DELTARUNE install' -DisplayName 'DELTARUNE' `
		-PickTitle 'Select DELTARUNE.exe' -PickFilter 'DELTARUNE (*.exe)|*.exe' `
		-InvalidMsg 'Selected path is not a DELTARUNE install: {0}' `
		-Discover ${function:Find-SteamGame} -DiscoverTag 'default' -AskDiscover

	$install = [IO.Path]::GetDirectoryName($game)
	if (!(Test-Path (Join-Path $install 'DELTARUNE.exe'))) { throw 'Install folder must contain DELTARUNE.exe' }
	if (!(Test-Path (Join-Path $install 'data.win'))) { throw 'Install folder must contain data.win' }
	$label = if ($game -match '\\steamapps\\common\\') { 'Install folder (Steam)' } else { 'Install folder' }
	Write-Host "$label`: $install`n"

	$umt = Resolve-Program `
		-Key 'UndertaleModCli' -Leaf 'UndertaleModCli.exe' -Label 'UndertaleModCli' -DisplayName 'UndertaleModCli' `
		-PickTitle 'Select UndertaleModCli.exe' -PickFilter 'UndertaleModCli (UndertaleModCli.exe)|UndertaleModCli.exe|Executable (*.exe)|*.exe' `
		-InvalidMsg 'That folder does not contain UndertaleModCli.exe: {0}' `
		-Discover { Resolve-Exe (Get-Command 'UndertaleModCli.exe' -ErrorAction SilentlyContinue).Source 'UndertaleModCli.exe' } `
		-DiscoverTag 'PATH'

	Set-Setting 'DeltaruneExe' $game
	Set-Setting 'UndertaleModCli' $umt

	Write-Host 'Deploying mod files...'
	foreach ($e in $m.deploy.PSObject.Properties) {
		if (@($e.Value) -notcontains 0) { continue }
		$src = Join-Path $Deploy $e.Name; $dst = Join-Path $install $e.Name
		if (!(Test-Path -LiteralPath $src)) { Write-Host "  Skipped (not found): $($e.Name)"; continue }
		if (Test-Path -LiteralPath $src -PathType Container) {
			if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
			Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
			Write-Host "  $($e.Name)/"
		} else {
			Copy-Item -LiteralPath $src -Destination $dst -Force
			Write-Host "  $($e.Name)"
		}
	}

	Write-Host 'Restoring chapters from backup...'
	$installChapters = @()
	if (Test-Path -LiteralPath (Join-Path $install 'data.win')) { $installChapters += 0 }
	foreach ($ch in 1..5) {
		if (Test-Path -LiteralPath (Join-Path $install "chapter${ch}_windows\data.win")) { $installChapters += $ch }
	}
	foreach ($ch in $installChapters) {
		$p = WinPaths $install $ch
		if (!(Test-Path -LiteralPath $p.BackupDir)) {
			New-Item -ItemType Directory -Path $p.BackupDir -Force | Out-Null
		}
		if (Test-Path -LiteralPath $p.Backup) {
			Copy-Item -LiteralPath $p.Backup -Destination $p.DataWin -Force
			Write-Host "  [$(ChapterTag $ch)] Restored from backup"
		} else {
			Copy-Item -LiteralPath $p.DataWin -Destination $p.Backup -Force
			Write-Host "  [$(ChapterTag $ch)] Created backup"
		}
	}
	Write-Host ''

	$manifestChapters = @(Chapters $m)
	$code = Get-DataSection $m.data 'code'
	$tasks = foreach ($ch in $manifestChapters) {
		$tag = ChapterTag $ch
		$p = WinPaths $install $ch
		if (!(Test-Path -LiteralPath $p.DataWin)) {
			[pscustomobject]@{ Ch = $ch; Tag = $tag; Status = 'skip'; Reason = 'data.win not found' }
			continue
		}
		$over = Get-CodeJobs (Get-DataSection $code 'override') $ch
		$pre = Get-CodeJobs (Get-DataSection $code 'prefix') $ch
		$post = Get-CodeJobs (Get-DataSection $code 'postfix') $ch
		$snds = Get-CodeJobs (Get-DataSection $m.data 'sounds') $ch
		if (!$over.Count -and !$pre.Count -and !$post.Count -and !$snds.Count) {
			[pscustomobject]@{ Ch = $ch; Tag = $tag; Status = 'skip'; Reason = 'nothing to patch in manifest' }
			continue
		}
		[pscustomobject]@{
			Ch = $ch; Tag = $tag; Status = 'pending'
			DataWin = $p.DataWin; Backup = $p.Backup; BackupDir = $p.BackupDir
			Over = ($over -join ';'); Prefix = ($pre -join ';'); Post = ($post -join ';'); Sounds = ($snds -join ';')
		}
	}

	$pending = @($tasks | Where-Object { $_.Status -eq 'pending' })
	Write-Host "Patching $($pending.Count) of $($manifestChapters.Count) manifest chapter(s) in parallel..."
	$results = @($tasks | Where-Object { $_.Status -ne 'pending' })
	if ($pending.Count) {
		$worker = [ScriptBlock]::Create((Get-Content -LiteralPath $Worker -Raw))
		$pool = [runspacefactory]::CreateRunspacePool(1, [Math]::Max(1, $manifestChapters.Count))
		$pool.Open()
		$handles = foreach ($task in $pending) {
			$ps = [powershell]::Create()
			$ps.RunspacePool = $pool
			[void]$ps.AddScript($worker).AddArgument($task).AddArgument($umt).AddArgument($Root).AddArgument($Csx)
			[pscustomobject]@{ Ps = $ps; Async = $ps.BeginInvoke() }
		}
		foreach ($h in $handles) {
			try {
				$out = $h.Ps.EndInvoke($h.Async)
				$results += if ($out.Count -eq 1) { $out[0] } else { $out }
			} catch {
				$results += [pscustomobject]@{ Ch = -1; Tag = 'Unknown'; Status = 'fail'; Reason = $_.Exception.Message; Log = @() }
			}
			$h.Ps.Dispose()
		}
		$pool.Close(); $pool.Dispose()
	}
	$results = @($results | Sort-Object Ch)

	$ok = 0; $skip = 0; $fail = @()
	foreach ($r in $results) {
		switch ($r.Status) {
			'skip' { Write-Host "[$($r.Tag)] Skipped - $($r.Reason)"; $skip++ }
			'fail' {
				if ($r.Log) { Write-Host ''; $r.Log | ForEach-Object { Write-Host $_ } }
				Write-Host "  FAILED: $($r.Reason)"
				$fail += $r
			}
			default {
				if ($r.Log) { Write-Host ''; $r.Log | ForEach-Object { Write-Host $_ } }
				$ok++
			}
		}
	}

	Write-Host "`n========================================`n  Done - deployed to root, patched $ok chapter(s), skipped $skip"
	if ($fail.Count) {
		Write-Host "  Failed: $($fail.Count)"
		$fail | ForEach-Object { Write-Host "    [$($_.Tag)] $($_.Reason)" }
		Write-Host '========================================'
		End 1
	}
	Write-Host '========================================'
	End 0
} catch {
	Write-Host $_
	End 1
}
