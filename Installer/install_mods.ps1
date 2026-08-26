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
$Csx = Join-Path $Root 'utmt_api.csx'
$Worker = Join-Path $Root 'install_worker.ps1'
$SettingsPath = Join-Path $Root 'settings.json'

function End([int]$code) {
    Write-Host ''
    if ($code) { Write-Host 'Installation failed.' }
    cmd /c pause
    exit $code
}

function Ask([string]$prompt) {
    $r = Read-Host "$prompt [Y/n]"
    if (!$r) { return $true }
    $r -match '^[Yy]'
}

function Pick([string]$title, [string]$filter) {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Title = $title; $d.Filter = $filter; $d.CheckFileExists = $true
    if ($d.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
    $d.FileName
}

function Resolve-Exe([string]$path, [string]$leaf) {
    if (!$path) { return $null }
    if ((Split-Path -Leaf $path) -ieq $leaf -and (Test-Path -LiteralPath $path)) { return (Resolve-Path -LiteralPath $path).Path }
    $sibling = Join-Path ([IO.Path]::GetDirectoryName($path)) $leaf
    if (Test-Path -LiteralPath $sibling) { return (Resolve-Path -LiteralPath $sibling).Path }
}

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

function Write-Settings($settings) {
    $settings | ConvertTo-Json | Set-Content -LiteralPath $SettingsPath -Encoding UTF8
    Remove-Item (Join-Path $Root 'umt.json'), (Join-Path $Root 'install.json') -ErrorAction SilentlyContinue
}

function Set-Setting([string]$key, [string]$value) {
    $s = Read-Settings
    if (!$s) { $s = [pscustomobject]@{} }
    $s | Add-Member -NotePropertyName $key -NotePropertyValue $value -Force
    Write-Settings $s
}

function Get-Saved([string]$key, [string]$leaf, [string]$label) {
    $settings = Read-Settings
    $path = Resolve-Exe $settings.$key $leaf
    if ($path) {
        if ($y -or (Ask "Use saved $label? ($path)")) {
            Write-Host "$label (saved): $path"
            return $path
        }
    } elseif ($settings) {
        Write-Host "Saved $label path is missing; searching again..."
        Remove-Item -LiteralPath $SettingsPath -Force -ErrorAction SilentlyContinue
    }
}

function Get-Game {
    $game = Get-Saved 'DeltaruneExe' 'DELTARUNE.exe' 'DELTARUNE install'
    if ($game) { return $game }
    $default = Steam-Game
    if ($default -and (Ask "Use default DELTARUNE install? ($default)")) {
        Set-Setting 'DeltaruneExe' $default
        Write-Host "DELTARUNE (default): $default"
        return $default
    }
    $picked = Pick 'Select DELTARUNE.exe' 'DELTARUNE (*.exe)|*.exe'
    if (!$picked) { return $null }
    $game = Resolve-Exe $picked 'DELTARUNE.exe'
    if (!$game) { throw "Selected path is not a DELTARUNE install: $picked" }
    Set-Setting 'DeltaruneExe' $game
    Write-Host "DELTARUNE: $game"
    $game
}

function Steam-Game {
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

function Get-Umt {
    $cli = Get-Saved 'UndertaleModCli' 'UndertaleModCli.exe' 'UndertaleModCli'
    if ($cli) { return $cli }
    $cli = Resolve-Exe (Get-Command 'UndertaleModCli.exe' -ErrorAction SilentlyContinue).Source 'UndertaleModCli.exe'
    if ($cli) {
        Set-Setting 'UndertaleModCli' $cli
        Write-Host "UndertaleModCli (PATH): $cli"
        return $cli
    }
    $picked = Pick 'Select UndertaleModCli.exe' 'UndertaleModCli (UndertaleModCli.exe)|UndertaleModCli.exe|Executable (*.exe)|*.exe'
    if (!$picked) { return $null }
    $cli = Resolve-Exe $picked 'UndertaleModCli.exe'
    if (!$cli) { throw "That folder does not contain UndertaleModCli.exe: $picked" }
    Set-Setting 'UndertaleModCli' $cli
    Write-Host "UndertaleModCli: $cli"
    $cli
}

function Get-ManifestChapters($value) {
    if ($null -eq $value) { return @() }
    if ($value -is [System.Array]) { return @($value | ForEach-Object { [int]$_ }) }
    if ($value -is [ValueType]) { return @([int]$value) }
    if ($value.PSObject.Properties.Name -contains 'chapters') {
        $chapters = $value.chapters
        if ($chapters -is [System.Array]) { return @($chapters | ForEach-Object { [int]$_ }) }
        if ($null -ne $chapters) { return @([int]$chapters) }
    }
    return @()
}

function Get-ManifestSource([string]$target, $value) {
    if ($null -eq $value) { return $target }
    if ($value.PSObject.Properties.Name -contains 'from') { return [string]$value.from }
    return $target
}

function Format-CodeJob([string]$target, [string]$source) {
    if ($source -eq $target) { return $target }
    return "$target@$source"
}

function Get-CodeJobs($section, [int]$ch) {
    if (!$section) { return @() }
    $jobs = @()
    foreach ($prop in $section.PSObject.Properties) {
        $chapters = Get-ManifestChapters $prop.Value
        if ($chapters -notcontains $ch) { continue }
        $source = Get-ManifestSource $prop.Name $prop.Value
        $jobs += Format-CodeJob $prop.Name $source
    }
    $jobs
}

function Get-DataSection($data, [string]$name) {
    if (!$data) { return $null }
    if ($data.PSObject.Properties.Name -contains $name) { return $data.$name }
    return $null
}

function Get-CodePatchSections($code) {
    if (!$code) { return @() }
    $sections = @()
    foreach ($name in @('override', 'prefix', 'postfix')) {
        if ($code.PSObject.Properties.Name -contains $name -and $code.$name) {
            $sections += $code.$name
        }
    }
    $sections
}

function Get-CodePatchSection($code, [string]$name) {
    Get-DataSection $code $name
}

function Chapters($m) {
    $nums = @()
    foreach ($section in Get-CodePatchSections (Get-DataSection $m.data 'code')) {
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

function Names($section, [int]$ch) {
    Get-CodeJobs $section $ch
}

function WinPaths([string]$install, [int]$ch) {
    $base = if ($ch -eq 0) { $install } else { Join-Path $install "chapter${ch}_windows" }
    $bk = Join-Path $base 'backup'
    [pscustomobject]@{ DataWin = Join-Path $base 'data.win'; Backup = Join-Path $bk 'data.win'; BackupDir = $bk }
}

function Get-InstallChapters([string]$install) {
    $chs = @()
    if (Test-Path -LiteralPath (Join-Path $install 'data.win')) { $chs += 0 }
    foreach ($ch in 1..5) {
        if (Test-Path -LiteralPath (Join-Path $install "chapter${ch}_windows\data.win")) { $chs += $ch }
    }
    $chs
}

function Restore-Chapters([string]$install) {
    Write-Host 'Restoring chapters from backup...'
    foreach ($ch in (Get-InstallChapters $install)) {
        $tag = if ($ch -eq 0) { 'Root' } else { "Chapter $ch" }
        $p = WinPaths $install $ch
        if (!(Test-Path -LiteralPath $p.BackupDir)) {
            New-Item -ItemType Directory -Path $p.BackupDir -Force | Out-Null
        }
        if (Test-Path -LiteralPath $p.Backup) {
            Copy-Item -LiteralPath $p.Backup -Destination $p.DataWin -Force
            Write-Host "  [$tag] Restored from backup"
        } else {
            Copy-Item -LiteralPath $p.DataWin -Destination $p.Backup -Force
            Write-Host "  [$tag] Created backup"
        }
    }
    Write-Host ''
}

function Deploy($m, [string]$install) {
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
}

function Build-Tasks($m, [string]$install) {
    $tasks = @()
    foreach ($ch in Chapters $m) {
        $tag = if ($ch -eq 0) { 'Root' } else { "Chapter $ch" }
        $p = WinPaths $install $ch
        if (!(Test-Path -LiteralPath $p.DataWin)) {
            $tasks += [pscustomobject]@{ Ch = $ch; Tag = $tag; Status = 'skip'; Reason = 'data.win not found' }
            continue
        }
        $code = Get-DataSection $m.data 'code'
        $over = Names (Get-CodePatchSection $code 'override') $ch
        $pre = Names (Get-CodePatchSection $code 'prefix') $ch
        $post = Names (Get-CodePatchSection $code 'postfix') $ch
        $snds = Names (Get-DataSection $m.data 'sounds') $ch
        if (!$over.Count -and !$pre.Count -and !$post.Count -and !$snds.Count) {
            $tasks += [pscustomobject]@{ Ch = $ch; Tag = $tag; Status = 'skip'; Reason = 'nothing to patch in manifest' }
            continue
        }
        $tasks += [pscustomobject]@{
            Ch = $ch; Tag = $tag; Status = 'pending'
            DataWin = $p.DataWin; Backup = $p.Backup; BackupDir = $p.BackupDir
            Over = ($over -join ';'); Prefix = ($pre -join ';'); Post = ($post -join ';'); Sounds = ($snds -join ';')
        }
    }
    $tasks
}

function Run-Tasks($tasks, [string]$umt, [int]$threads) {
    $pending = @($tasks | Where-Object { $_.Status -eq 'pending' })
    $results = @($tasks | Where-Object { $_.Status -ne 'pending' })
    if (!$pending.Count) { return $results }

    $worker = [ScriptBlock]::Create((Get-Content -LiteralPath $Worker -Raw))
    $pool = [runspacefactory]::CreateRunspacePool(1, [Math]::Max(1, $threads))
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
    $results | Sort-Object Ch
}

try {
    Write-Host "`n========================================`n  DELTANYON - Deltarune Installer`n========================================`n"
    if (!(Test-Path -LiteralPath $Manifest)) { throw "manifest.json not found: $Manifest" }
    if (!(Test-Path -LiteralPath $Csx)) { throw 'Missing utmt_api.csx in Installer folder.' }
    if (!(Test-Path -LiteralPath $Worker)) { throw 'Missing install_worker.ps1 in Installer folder.' }

    $m = Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json
    $game = Get-Game
    if (!$game) { End 0 }

    $install = [IO.Path]::GetDirectoryName($game)
    if (!(Test-Path (Join-Path $install 'DELTARUNE.exe'))) { throw 'Install folder must contain DELTARUNE.exe' }
    if (!(Test-Path (Join-Path $install 'data.win'))) { throw 'Install folder must contain data.win' }
    $label = if ($game -match '\\steamapps\\common\\') { 'Install folder (Steam)' } else { 'Install folder' }
    Write-Host "$label`: $install`n"

    $umt = Get-Umt
    if (!$umt) { End 0 }

    Deploy $m $install

    Restore-Chapters $install

    $manifestChapters = @(Chapters $m)
    $tasks = Build-Tasks $m $install
    $pending = @($tasks | Where-Object { $_.Status -eq 'pending' })
    Write-Host "Patching $($pending.Count) of $($manifestChapters.Count) manifest chapter(s) in parallel..."
    $results = Run-Tasks $tasks $umt $manifestChapters.Count

    foreach ($r in $results) {
        if ($r.Status -eq 'skip') { Write-Host "[$($r.Tag)] Skipped - $($r.Reason)"; continue }
        if ($r.Log) { Write-Host ''; $r.Log | ForEach-Object { Write-Host $_ } }
        if ($r.Status -eq 'fail') { Write-Host "  FAILED: $($r.Reason)" }
    }

    $ok = @($results | Where-Object { $_.Status -eq 'ok' }).Count
    $skip = @($results | Where-Object { $_.Status -eq 'skip' }).Count
    $fail = @($results | Where-Object { $_.Status -eq 'fail' })

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
