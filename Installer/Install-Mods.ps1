param([switch]$y)
$ErrorActionPreference = 'Stop'

if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA')
{
	if (Test-Path (Join-Path $PSHOME 'powershell.exe'))
	{
		$exe = Join-Path $PSHOME 'powershell.exe'
	}
	else
	{
		$exe = 'powershell.exe'
	}
	$psArgs = @(
		'-NoProfile',
		'-STA',
		'-ExecutionPolicy',
		'Bypass',
		'-File',
		$PSCommandPath
	)
	if ($y)
	{
		$psArgs += '-y'
	}
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
$MaxEnvVarLength = 32767

$BannerLine = '========================================='
$Version = 'v0.0.1'
$Tagline = 'Proprietary installer for DELTANYON.'

$FunctionDir = Join-Path $Root 'Function'
foreach ($f in @(
	'Ask.ps1',
	'Get-DataSection.ps1',
	'Get-ManifestChapters.ps1',
	'Read-Settings.ps1',
	'Resolve-Exe.ps1',
	'Write-Settings.ps1'
))
{
	. (Join-Path $FunctionDir $f)
}

$InstallerSettings = Read-Settings -SettingsPath $SettingsPath
if (!$InstallerSettings)
{
	$InstallerSettings = @{}
}

function End([int]$code, [string]$ErrorMessage = $null)
{
	Write-Host ''
	if ($code)
	{
		if ($ErrorMessage)
		{
			Write-Host $ErrorMessage
			Write-Host ''
		}
		Write-Host 'Installation failed.'
	}
	cmd /c pause
	exit $code
}

function Get-ErrorText($err)
{
	$parts = @()
	$ex = $err.Exception
	while ($ex)
	{
		if ($ex.Message)
		{
			$parts += $ex.Message
		}
		$ex = $ex.InnerException
	}
	$parts -join "`n"
}

function Assert-EnvListLengths($task)
{
	foreach ($entry in @(
		@{ Name = 'DRML_OVERRIDES'; Value = [string]$task.Over }
		@{ Name = 'DRML_PREFIXES'; Value = [string]$task.Prefix }
		@{ Name = 'DRML_POSTFIXES'; Value = [string]$task.Post }
		@{ Name = 'DRML_SOUNDS'; Value = [string]$task.Sounds }
		@{ Name = 'DRML_GAME_DIR'; Value = [IO.Path]::GetDirectoryName($task.DataWin) }
	))
	{
		if ($entry.Value.Length -gt $MaxEnvVarLength)
		{
			throw ('{0} for [{1}] is {2} characters (Windows limit is {3}).' -f $entry.Name, $task.Tag, $entry.Value.Length, $MaxEnvVarLength)
		}
	}
}

function Pick([string]$title, [string]$filter)
{
	Add-Type -AssemblyName System.Windows.Forms | Out-Null
	$d = New-Object System.Windows.Forms.OpenFileDialog
	$d.Title = $title
	$d.Filter = $filter
	$d.CheckFileExists = $true
	$result = $null
	if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK)
	{
		$result = $d.FileName
	}
	$result
}

function Set-Setting([string]$key, [string]$value)
{
	$script:InstallerSettings[$key] = $value
	Write-Settings -Settings $script:InstallerSettings -SettingsPath $SettingsPath
}

function Get-Saved([string]$key, [string]$leaf, [string]$label)
{
	$path = Resolve-Exe $script:InstallerSettings[$key] $leaf
	$result = $null
	if ($path)
	{
		if ($y -or (Ask ('Use saved {0}? ({1})' -f $label, $path)))
		{
			Write-Host "$label (saved): $path"
			Set-Setting $key $path
			$result = $path
		}
	}
	elseif ($script:InstallerSettings.ContainsKey($key))
	{
		Write-Host "Saved $label path was missing."
		$script:InstallerSettings.Remove($key) | Out-Null
		Write-Settings -Settings $script:InstallerSettings -SettingsPath $SettingsPath
	}
	$result
}

function Resolve-Program
{
	param(
		[string]$Key,
		[string]$Leaf,
		[string]$Label,
		[string]$DisplayName,
		[string]$PickTitle,
		[string]$PickFilter,
		[string]$InvalidMsg,
		[scriptblock]$Discover,
		[string]$DiscoverTag,
		[switch]$AskDiscover
	)
	$path = Get-Saved $Key $Leaf $Label
	if (!$path -and $Discover)
	{
		$discovered = & $Discover
		if ($discovered -and (!$AskDiscover -or $y -or (Ask ('Use default {0}? ({1})' -f $Label, $discovered))))
		{
			Set-Setting $Key $discovered
			Write-Host "$DisplayName ($DiscoverTag): $discovered"
			$path = $discovered
		}
	}
	if (!$path)
	{
		$picked = Pick $PickTitle $PickFilter
		if (!$picked)
		{
			End 0
		}
		$path = Resolve-Exe $picked $Leaf
		if (!$path)
		{
			throw ($InvalidMsg -f $picked)
		}
		Set-Setting $Key $path
		Write-Host "${DisplayName}: $path"
	}
	$path
}

function Find-SteamGame
{
	$found = $null
	foreach ($key in @(
		'HKCU:\Software\Valve\Steam',
		'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
		'HKLM:\SOFTWARE\Valve\Steam'
	))
	{
		if (!$found -and (Test-Path -LiteralPath $key))
		{
			$steam = (Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue).InstallPath
			if ($steam -and (Test-Path -LiteralPath $steam))
			{
				$libs = @($steam)
				$vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
				if (Test-Path -LiteralPath $vdf)
				{
					$libs += (Get-Content -LiteralPath $vdf -Encoding UTF8 | Where-Object { $_ -match '"path"\s+"(.+)"' } | ForEach-Object { $Matches[1] -replace '\\\\', '\' })
				}
				foreach ($lib in ($libs | Select-Object -Unique))
				{
					if (!$found)
					{
						$exe = Join-Path $lib 'steamapps\common\DELTARUNE\DELTARUNE.exe'
						if (Test-Path -LiteralPath $exe)
						{
							$found = (Resolve-Path -LiteralPath $exe).Path
						}
					}
				}
			}
		}
	}
	$found
}

function ChapterTag([int]$ch)
{
	if ($ch -eq 0)
	{
		$result = 'Launcher '
	}
	else
	{
		$result = "Chapter $ch"
	}
	$result
}

function WinPaths([string]$install, [int]$ch)
{
	if ($ch -eq 0)
	{
		$base = $install
	}
	else
	{
		$base = Join-Path $install "chapter${ch}_windows"
	}
	$bk = Join-Path $base 'backup'
	[pscustomobject]@{
		DataWin = Join-Path $base 'data.win'
		Backup = Join-Path $bk 'data.win'
		BackupDir = $bk
	}
}

function Get-CodeJobs($section, [int]$ch)
{
	$jobs = @()
	if ($section)
	{
		foreach ($prop in $section.PSObject.Properties)
		{
			$chapters = Get-ManifestChapters $prop.Value
			if ($chapters -notcontains $ch)
			{
				continue
			}
			if ($null -eq $prop.Value)
			{
				$source = $prop.Name
			}
			elseif ($prop.Value.PSObject.Properties.Name -contains 'from')
			{
				$source = [string]$prop.Value.from
			}
			else
			{
				$source = $prop.Name
			}
			if ($source -eq $prop.Name)
			{
				$jobs += $prop.Name
			}
			else
			{
				$jobs += "$($prop.Name)@$source"
			}
		}
	}
	$jobs
}

function Chapters($m)
{
	$nums = @()
	$code = Get-DataSection $m.data 'code'
	foreach ($name in @(
		'override',
		'prefix',
		'postfix'
	))
	{
		$section = Get-DataSection $code $name
		if (!$section)
		{
			continue
		}
		foreach ($p in $section.PSObject.Properties)
		{
			foreach ($n in (Get-ManifestChapters $p.Value))
			{
				$nums += $n
			}
		}
	}
	$sounds = Get-DataSection $m.data 'sounds'
	if ($sounds)
	{
		foreach ($p in $sounds.PSObject.Properties)
		{
			foreach ($n in (Get-ManifestChapters $p.Value))
			{
				$nums += $n
			}
		}
	}
	$nums | Sort-Object -Unique
}

try
{
	Write-Host "`n$BannerLine`n  DELTARUNE Mod Loader $Version`n  $Tagline`n$BannerLine`n"
	if (!(Test-Path -LiteralPath $Manifest))
	{
		throw "manifest.json not found: $Manifest"
	}
	if (!(Test-Path -LiteralPath $Csx))
	{
		throw 'Missing UtmtApi.csx in the Installer folder.'
	}
	if (!(Test-Path -LiteralPath $Worker))
	{
		throw 'Missing Install-Worker.ps1 in the Installer folder.'
	}

	$m = Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json

	$game = Resolve-Program `
		-Key 'DeltaruneExe' `
		-Leaf 'DELTARUNE.exe' `
		-Label 'DELTARUNE install location' `
		-DisplayName 'DELTARUNE' `
		-PickTitle 'Select DELTARUNE.exe' `
		-PickFilter 'DELTARUNE (*.exe)|*.exe' `
		-InvalidMsg 'Selected path is not a DELTARUNE install: {0}' `
		-Discover ${function:Find-SteamGame} `
		-DiscoverTag 'default' `
		-AskDiscover

	$install = [IO.Path]::GetDirectoryName($game)
	if (!(Test-Path (Join-Path $install 'DELTARUNE.exe')))
	{
		throw 'Install folder must contain DELTARUNE.exe.'
	}
	if (!(Test-Path (Join-Path $install 'data.win')))
	{
		throw 'Install folder must contain data.win.'
	}
	if ($game -match '\\steamapps\\common\\')
	{
		$label = 'Install folder (Steam)'
	}
	else
	{
		$label = 'Install folder'
	}
	Write-Host "$label`: $install`n"

	$utmt = Resolve-Program `
		-Key 'UndertaleModCli' `
		-Leaf 'UndertaleModCli.exe' `
		-Label 'UndertaleModCli' `
		-DisplayName 'UndertaleModCli' `
		-PickTitle 'Select UndertaleModCli.exe' `
		-PickFilter 'UndertaleModCli (UndertaleModCli.exe)|UndertaleModCli.exe|Executable (*.exe)|*.exe' `
		-InvalidMsg 'Selected folder does not contain UndertaleModCli.exe: {0}'

	Set-Setting 'DeltaruneExe' $game
	Set-Setting 'UndertaleModCli' $utmt

	Write-Host ''
	Write-Host 'Deploying mod files...'
	foreach ($e in $m.deploy.PSObject.Properties)
	{
		$src = Join-Path $Deploy $e.Name
		if (!(Test-Path -LiteralPath $src))
		{
			continue
		}
		foreach ($ch in (Get-ManifestChapters $e.Value))
		{
			$p = WinPaths $install $ch
			if (!(Test-Path -LiteralPath $p.DataWin))
			{
				continue
			}
			$dst = Join-Path (Split-Path -Parent $p.DataWin) $e.Name
			$tag = ChapterTag $ch
			if (Test-Path -LiteralPath $src -PathType Container)
			{
				if (Test-Path -LiteralPath $dst)
				{
					Remove-Item -LiteralPath $dst -Recurse -Force
				}
				Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
				Write-Host "  [$tag] $($e.Name)/"
			}
			else
			{
				Copy-Item -LiteralPath $src -Destination $dst -Force
				Write-Host "  [$tag] $($e.Name)"
			}
		}
	}

	Write-Host ''
	Write-Host 'Restoring chapters from backups...'
	$installChapters = @()
	if (Test-Path -LiteralPath (Join-Path $install 'data.win'))
	{
		$installChapters += 0
	}
	foreach ($ch in 1..5)
	{
		if (Test-Path -LiteralPath (Join-Path $install "chapter${ch}_windows\data.win"))
		{
			$installChapters += $ch
		}
	}
	foreach ($ch in $installChapters)
	{
		$p = WinPaths $install $ch
		if (!(Test-Path -LiteralPath $p.BackupDir))
		{
			New-Item -ItemType Directory -Path $p.BackupDir -Force | Out-Null
		}
		if (Test-Path -LiteralPath $p.Backup)
		{
			Copy-Item -LiteralPath $p.Backup -Destination $p.DataWin -Force
			Write-Host "  [$(ChapterTag $ch)] Restored from backup."
		}
		else
		{
			Copy-Item -LiteralPath $p.DataWin -Destination $p.Backup -Force
			Write-Host "  [$(ChapterTag $ch)] Created backup."
		}
	}
	Write-Host ''

	$manifestChapters = @(Chapters $m)
	$code = Get-DataSection $m.data 'code'
	$tasks = foreach ($ch in $manifestChapters)
	{
		$tag = ChapterTag $ch
		$p = WinPaths $install $ch
		if (!(Test-Path -LiteralPath $p.DataWin))
		{
			[pscustomobject]@{
				Ch = $ch
				Tag = $tag
				Status = 'skip'
				Reason = 'data.win not found.'
			}
			continue
		}
		$over = Get-CodeJobs (Get-DataSection $code 'override') $ch
		$pre = Get-CodeJobs (Get-DataSection $code 'prefix') $ch
		$post = Get-CodeJobs (Get-DataSection $code 'postfix') $ch
		$snds = Get-CodeJobs (Get-DataSection $m.data 'sounds') $ch
		if (!$over.Count -and !$pre.Count -and !$post.Count -and !$snds.Count)
		{
			[pscustomobject]@{
				Ch = $ch
				Tag = $tag
				Status = 'skip'
				Reason = 'Nothing to patch in manifest.'
			}
			continue
		}
		[pscustomobject]@{
			Ch = $ch
			Tag = $tag
			Status = 'pending'
			DataWin = $p.DataWin
			Backup = $p.Backup
			BackupDir = $p.BackupDir
			Over = ($over -join ';')
			Prefix = ($pre -join ';')
			Post = ($post -join ';')
			Sounds = ($snds -join ';')
		}
	}

	$pending = @($tasks | Where-Object { $_.Status -eq 'pending' })
	foreach ($task in $pending)
	{
		Assert-EnvListLengths $task
	}
	$patchWord = if ($pending.Count -eq 1) { 'chapter' } else { 'chapters' }
	Write-Host "Patching $($pending.Count) manifest $patchWord in parallel..."
	$results = @($tasks | Where-Object { $_.Status -ne 'pending' })
	if ($pending.Count)
	{
		$worker = [ScriptBlock]::Create((Get-Content -LiteralPath $Worker -Raw))
		$pool = [runspacefactory]::CreateRunspacePool(1, [Math]::Max(1, $manifestChapters.Count))
		$pool.Open()
		$handles = foreach ($task in $pending)
		{
			$ps = [powershell]::Create()
			$ps.RunspacePool = $pool
			[void]$ps.AddScript($worker)
			[void]$ps.AddArgument($task)
			[void]$ps.AddArgument($utmt)
			[void]$ps.AddArgument($Root)
			[void]$ps.AddArgument($Csx)
			[pscustomobject]@{
				Ps = $ps
				Async = $ps.BeginInvoke()
			}
		}
		foreach ($h in $handles)
		{
			try
			{
				$out = $h.Ps.EndInvoke($h.Async)
				if ($out.Count -eq 1)
				{
					$results += $out[0]
				}
				else
				{
					$results += $out
				}
			}
			catch
			{
				$results += [pscustomobject]@{
					Ch = -1
					Tag = 'Unknown'
					Status = 'fail'
					Reason = (Get-ErrorText $_)
					Log = @()
				}
			}
			$h.Ps.Dispose()
		}
		$pool.Close()
		$pool.Dispose()
	}
	$results = @($results | Sort-Object Ch)

	$ok = 0
	$skip = 0
	$fail = @()
	foreach ($r in $results)
	{
		switch ($r.Status)
		{
			'skip'
			{
				Write-Host "[$($r.Tag)] Skipped - $($r.Reason)"
				$skip++
			}
			'fail'
			{
				Write-Host "[$($r.Tag)] FAILED: $($r.Reason)"
				if ($r.Log)
				{
					$r.Log | ForEach-Object { Write-Host $_ }
				}
				$fail += $r
			}
			default
			{
				if ($r.Log)
				{
					Write-Host ''
					$r.Log | ForEach-Object { Write-Host $_ }
				}
				$ok++
			}
		}
	}

	$patchedWord = if ($ok -eq 1) { 'chapter' } else { 'chapters' }
	$summary = "Deployed to root, patched $ok $patchedWord"
	if ($skip -gt 0)
	{
		$skipWord = if ($skip -eq 1) { 'chapter' } else { 'chapters' }
		$summary += ", skipped $skip $skipWord"
	}
	$summary += '.'
	Write-Host "`n$BannerLine`n  Installation finished!`n  $summary"
	if ($fail.Count)
	{
		Write-Host "  Failed: $($fail.Count)"
		$errorText = ($fail | ForEach-Object {
			$lines = @("[$($_.Tag)] $($_.Reason)")
			if ($_.Log)
			{
				$lines += $_.Log
			}
			$lines -join "`n"
		}) -join "`n`n"
		End 1 $errorText
	}
	Write-Host $BannerLine
	End 0
}
catch
{
	End 1 (Get-ErrorText $_)
}
