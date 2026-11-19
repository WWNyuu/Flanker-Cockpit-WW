# Su-27 Radio (WW) - desktop installer / uninstaller
# Run through INSTALL.bat / UNINSTALL.bat (Windows PowerShell 5.1, nothing else needed).
#
# INSTALL:
#   1. finds the Saved Games folder (where Windows really keeps it) and every
#      DCS* folder in it (DCS, DCS.openbeta, ...)
#   2. copies files\Su-27 Radio (WW) into <that folder>\Mods\tech\Su-27 Radio (WW)
#      (over an older copy: files of the new version replace the old ones; the
#      remembered DCS folder, the controls backup and the DTC Planner pages of
#      the old copy stay)
#   3. copies the hook (radio presets), the MFD hook and the MFD export into
#      Scripts, the example cartridge into DTC\Su-27 (only when there is none)
#   4. runs the mod's own installer\su27radio_binds.ps1: Export.lua line and the
#      radio / MFD controls (Options > Controls > Su-27 / J-11A)
# UNINSTALL (-Uninstall): controls and Export.lua line out, hooks and export
#   deleted, Mods\tech\Su-27 Radio (WW) deleted. Cartridges in DTC\Su-27 stay.
# -SavedGames <folder>: use this DCS folder (e.g. "D:\Saved Games\DCS") instead
#   of looking for them. -DcsPath <folder>: the DCS install (for the controls).
param([switch]$Uninstall, [string]$SavedGames = "", [string]$DcsPath = "")

if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
	Write-Host ""
	Write-Host "  PROBLEM: PowerShell runs in a restricted mode on this PC (company / school policy)." -ForegroundColor Yellow
	Write-Host "  The installer cannot work in that mode. Nothing was changed." -ForegroundColor Yellow
	Write-Host ""
	exit 1
}

$ErrorActionPreference = "Stop"
$Here = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
$Root = [System.IO.Path]::GetDirectoryName($Here)
$SEP = [System.IO.Path]::DirectorySeparatorChar
$ModName = "Su-27 Radio (WW)"
$Src = [System.IO.Path]::Combine([System.IO.Path]::Combine($Root, "files"), $ModName)
# kept from the old copy when installing over it (paths inside the mod folder)
$Keep = @("installer\dcs_path.txt")

function J($a, $b) { return [System.IO.Path]::Combine($a, ($b -replace '\\', $SEP)) }
function Say($m) { Write-Host ("  " + $m) }
function IsFile($p) { return [System.IO.File]::Exists($p) }
function IsDir($p) { return [System.IO.Directory]::Exists($p) }
function Ensure-Dir($d) { if (-not (IsDir $d)) { [void][System.IO.Directory]::CreateDirectory($d) } }
function Clear-ReadOnly($p) {
	if (IsFile $p) {
		$fi = New-Object System.IO.FileInfo $p
		if ($fi.IsReadOnly) { $fi.IsReadOnly = $false }
	}
}
function CopyFile($a, $b) { Ensure-Dir ([System.IO.Path]::GetDirectoryName($b)); Clear-ReadOnly $b; [System.IO.File]::Copy($a, $b, $true) }
function Remove-File($p) { if (IsFile $p) { Clear-ReadOnly $p; [System.IO.File]::Delete($p) } }

# every file below $from, copied to the same place below $to; returns the count
function Copy-Tree($from, $to) {
	$n = 0
	$base = ([System.IO.DirectoryInfo]$from).FullName.TrimEnd([char]'\', [char]'/')
	foreach ($f in [System.IO.Directory]::GetFiles($base, "*", [System.IO.SearchOption]::AllDirectories)) {
		$rel = $f.Substring($base.Length + 1)
		if ($Keep -contains $rel) { continue }
		CopyFile $f (J $to $rel)
		$n++
	}
	return $n
}

function Get-SavedGamesRoot {
	$v = $null
	try {
		$k = Get-ItemProperty -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -ErrorAction Stop
		$v = $k.'{4C5C32FF-BB9D-43B0-B5B4-2D72E54EAAA4}'
	} catch { $v = $null }
	if ($v) {
		$v = [System.Environment]::ExpandEnvironmentVariables([string]$v)
		if (IsDir $v) { return $v }
	}
	if ($env:USERPROFILE) { return (J $env:USERPROFILE "Saved Games") }
	return $v
}
# the DCS folders to work on
function Get-Targets {
	if ($SavedGames -ne "") {
		$sg = $SavedGames.Trim().Trim([char]'"').TrimEnd([char]'\', [char]'/')
		if (-not (IsDir $sg)) { throw ("Folder not found: " + $sg) }
		$name = [System.IO.Path]::GetFileName($sg)
		if (($name -like "DCS*") -or (IsDir (J $sg "Config")) -or (IsDir (J $sg "Mods"))) { return @($sg) }
		$r = @()
		foreach ($d in @(Get-ChildItem -LiteralPath $sg -Directory)) { if ($d.Name -like "DCS*") { $r += $d.FullName } }
		if ($r.Count -eq 0) { throw ("No DCS folder in " + $sg) }
		return $r
	}
	$root = Get-SavedGamesRoot
	$r = @()
	if ($root -and (IsDir $root)) {
		foreach ($d in @(Get-ChildItem -LiteralPath $root -Directory)) {
			if ($d.Name -like "DCS*" -and ((IsDir (J $d.FullName "Config")) -or (IsDir (J $d.FullName "Mods")) -or (IsDir (J $d.FullName "Logs")))) { $r += $d.FullName }
		}
	}
	if ($r.Count -eq 0) {
		throw ("No DCS folder found in " + $root + ". Start DCS once, or run from a command prompt:  INSTALL.bat -SavedGames ""D:\Saved Games\DCS""")
	}
	return $r
}
# other folders in Mods\tech that hold this mod (an old copy under another name)
function Get-OtherCopies($tech) {
	$r = @()
	if (-not (IsDir $tech)) { return $r }
	foreach ($d in @(Get-ChildItem -LiteralPath $tech -Directory)) {
		if ($d.Name -eq $ModName) { continue }
		$e = J $d.FullName "entry.lua"
		if (-not (IsFile $e)) { continue }
		try { $t = [System.IO.File]::ReadAllText($e) } catch { continue }
		if ($t -match 'declare_plugin\(\s*"su27_radio"') { $r += $d.FullName }
	}
	return $r
}
function Run-Binds($dst, $sg, $remove) {
	$ps = J $dst "installer\su27radio_binds.ps1"
	if (-not (IsFile $ps)) { Say "Controls: installer\su27radio_binds.ps1 missing, not changed"; return }
	$a = @{ SavedGames = $sg }
	if ($DcsPath -ne "") { $a.DcsPath = $DcsPath }
	if ($remove) { $a.Uninstall = $true }
	& $ps @a
}

function Install-One($sg) {
	Say ("DCS folder: " + $sg)
	$tech = J $sg "Mods\tech"
	$dst = J $tech $ModName
	$others = @(Get-OtherCopies $tech)
	if ($others.Count -gt 0) {
		foreach ($o in $others) { Say ("PROBLEM: another copy of the mod is in " + $o) }
		Say "Two copies make DCS load the mod twice. Delete that folder, then run INSTALL.bat again."
		Say "Nothing was changed in this DCS folder."
		return $false
	}
	$old = IsDir $dst
	$n = Copy-Tree $Src $dst
	if ($old) { Say ("- mod updated in Mods\tech\" + $ModName + " (" + $n + " files)") }
	else { Say ("- mod copied to Mods\tech\" + $ModName + " (" + $n + " files)") }
	CopyFile (J $dst "Scripts\Hooks\su27radio_hook.lua") (J $sg "Scripts\Hooks\su27radio_hook.lua")
	Say "- hook copied to Scripts\Hooks (the mission's radio presets for MIS)"
	CopyFile (J $dst "Scripts\Hooks\S27MFD_hook.lua") (J $sg "Scripts\Hooks\S27MFD_hook.lua")
	CopyFile (J $dst "Scripts\S27MFD_Export.lua") (J $sg "Scripts\S27MFD_Export.lua")
	Say "- MFD scripts copied (Scripts\S27MFD_Export.lua, Scripts\Hooks\S27MFD_hook.lua)"
	$dtc = J $sg "DTC\Su-27\1 Example comm plan.dtc"
	if (IsFile $dtc) { Say "- DTC\Su-27 already has the example cartridge: left as it is" }
	else {
		$ex = J $dst "Examples\1 Example comm plan.dtc"
		if (IsFile $ex) { CopyFile $ex $dtc; Say "- example cartridge copied to DTC\Su-27 (KASSETA 1)" }
		else { Ensure-Dir (J $sg "DTC\Su-27") }
	}
	$pl = J $dst "DTC Planner"
	if ((-not (IsDir $pl)) -or (@([System.IO.Directory]::GetFiles($pl, "*.html")).Count -eq 0)) {
		Say "- note: no DTC Planner page in the mod folder (the DTC Planner folder is missing from the package)"
	}
	Say "- Export.lua line and controls (Options - Controls - Su-27 / J-11A / Su-33, category ""Su-27 Radio (WW)""):"
	Run-Binds $dst $sg $false
	return $true
}

function Uninstall-One($sg) {
	Say ("DCS folder: " + $sg)
	$dst = J (J $sg "Mods\tech") $ModName
	if (IsDir $dst) { Run-Binds $dst $sg $true }
	else {
		# mod folder already gone: the package's copy takes the controls out
		Run-Binds $Src $sg $true
	}
	foreach ($f in @("Scripts\Hooks\su27radio_hook.lua", "Scripts\Hooks\S27MFD_hook.lua", "Scripts\S27MFD_Export.lua")) {
		$p = J $sg $f
		if (IsFile $p) { Remove-File $p; Say ("- removed " + $f) }
	}
	if (IsDir $dst) {
		Remove-Item -LiteralPath $dst -Recurse -Force
		Say ("- removed Mods\tech\" + $ModName)
	} else { Say ("- Mods\tech\" + $ModName + " was not there") }
	Say "- your cartridges in DTC\Su-27 stay"
	return $true
}

# ---------------------------------------------------------------- run
try {
	if (Get-Process -Name "DCS" -ErrorAction SilentlyContinue) { throw "DCS is running. Close DCS first. Nothing was changed." }
	if (-not $Uninstall -and -not (IsFile (J $Src "entry.lua"))) { throw ("The mod files are missing (" + $Src + "). Unzip the whole package again.") }
	$targets = @(Get-Targets)
	$ok = $true
	foreach ($sg in $targets) {
		Write-Host ""
		if ($Uninstall) { $r = Uninstall-One $sg } else { $r = Install-One $sg }
		if (-not $r) { $ok = $false }
	}
	Write-Host ""
	if ($Uninstall) { Say "Done. The mod is removed. You can delete this package folder." }
	elseif ($ok) {
		Say "Done. Start DCS: Options - Special - Su-27 Radio has the on/off switch."
		Say "After a DCS update or repair the radio controls disappear: run INSTALL.bat again."
	}
	if (-not $ok) { exit 1 }
} catch {
	Write-Host ""
	Write-Host ("  PROBLEM: " + $_.Exception.Message) -ForegroundColor Yellow
	exit 1
}
