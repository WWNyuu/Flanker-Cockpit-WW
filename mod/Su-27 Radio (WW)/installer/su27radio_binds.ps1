# Su-27 Radio (WW) - the add-on's controls (Options > Controls > Su-27 / J-11A,
# category "Su-27 Radio (WW)"). Run through INSTALL.bat / UNINSTALL.bat.
#
# INSTALL: <DCS>\Mods\aircraft\Su-27\Input\su-27\joystick|keyboard\default.lua
#   get one marked block (installer\su27radio_binds.lua) before their last
#   "return res"; ED's own lines stay as they are. The J-11A reads the Su-27's
#   files, so it gets the controls too. An older block is replaced. ED's file
#   (without the block) is kept in backup\.
#   A DCS update or repair puts ED's controls files back and the add-on's
#   controls disappear: run INSTALL.bat again. Your own key assignments
#   (Saved Games\DCS\Config\Input) are not touched and come back with them.
# UNINSTALL (-Uninstall): takes the block out again (ED's file is then as it was).
# -DcsPath <folder>: the DCS install folder (default: found in the registry /
#   the usual places / the folder remembered in dcs_path.txt).
param([switch]$Uninstall, [string]$DcsPath = "")

if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
	Write-Host ""
	Write-Host "  PROBLEM: PowerShell runs in a restricted mode on this PC (company / school policy)." -ForegroundColor Yellow
	Write-Host "  The controls could not be added. Nothing was changed." -ForegroundColor Yellow
	Write-Host ""
	exit 1
}

$ErrorActionPreference = "Stop"
$Here = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
$Root = [System.IO.Path]::GetDirectoryName($Here)                 # the add-on folder
$L1 = [System.Text.Encoding]::GetEncoding(28591)                   # bytes <-> text 1:1
$SEP = [System.IO.Path]::DirectorySeparatorChar
$BindBegin = "-- Su-27 Radio (WW) BINDS BEGIN"
$BindEnd = "-- Su-27 Radio (WW) BINDS END"
$BindRel = "Mods\aircraft\Su-27\Input\su-27"

function J($a, $b) { return [System.IO.Path]::Combine($a, ($b -replace '\\', $SEP)) }
function Say($m) { Write-Host ("  " + $m) }
function IsFile($p) { return [System.IO.File]::Exists($p) }
function IsDir($p) { return [System.IO.Directory]::Exists($p) }
function ReadL1($p) { return $L1.GetString([System.IO.File]::ReadAllBytes($p)) }
function Ensure-Dir($d) { if (-not (IsDir $d)) { [void][System.IO.Directory]::CreateDirectory($d) } }
function Clear-ReadOnly($p) {
	if (IsFile $p) {
		$fi = New-Object System.IO.FileInfo $p
		if ($fi.IsReadOnly) { $fi.IsReadOnly = $false }
	}
}
function WriteL1($p, $s) { Ensure-Dir ([System.IO.Path]::GetDirectoryName($p)); Clear-ReadOnly $p; [System.IO.File]::WriteAllBytes($p, $L1.GetBytes($s)) }
function CopyFile($a, $b) { Ensure-Dir ([System.IO.Path]::GetDirectoryName($b)); Clear-ReadOnly $b; [System.IO.File]::Copy($a, $b, $true) }

# ---------------------------------------------------------------- the Su-27's controls
# every DCS install folder (not Saved Games) that has the Su-27's controls
function Get-DcsInstalls {
	$c = @()
	if ($DcsPath -ne "") { $c += $DcsPath }
	foreach ($k in @("HKCU:\Software\Eagle Dynamics\DCS World", "HKCU:\Software\Eagle Dynamics\DCS World OpenBeta",
	                 "HKLM:\SOFTWARE\Eagle Dynamics\DCS World", "HKLM:\SOFTWARE\WOW6432Node\Eagle Dynamics\DCS World")) {
		try { $v = (Get-ItemProperty -LiteralPath $k -ErrorAction Stop).Path; if ($v) { $c += [string]$v } } catch { }
	}
	foreach ($k in @("HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 223750",
	                 "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 223750")) {
		try { $v = (Get-ItemProperty -LiteralPath $k -ErrorAction Stop).InstallLocation; if ($v) { $c += [string]$v } } catch { }
	}
	# the folder remembered from the last run (dcs_path.txt next to this script)
	$mem = J $Here "dcs_path.txt"
	if (IsFile $mem) { $c += ([System.IO.File]::ReadAllText($mem)).Trim() }
	foreach ($dr in @([System.IO.DriveInfo]::GetDrives())) {
		try { if ($dr.DriveType -ne "Fixed" -or -not $dr.IsReady) { continue } } catch { continue }
		$r = $dr.RootDirectory.FullName
		foreach ($sub in @("DCS World", "DCS World OpenBeta", "DCS", "Eagle Dynamics\DCS World", "Eagle Dynamics\DCS World OpenBeta",
		                   "Program Files\Eagle Dynamics\DCS World", "Program Files\Eagle Dynamics\DCS World OpenBeta",
		                   "Games\DCS World", "SteamLibrary\steamapps\common\DCSWorld",
		                   "Program Files (x86)\Steam\steamapps\common\DCSWorld")) { $c += (J $r $sub) }
	}
	$r = @(); $seen = @{}
	foreach ($d in $c) {
		$d = ([string]$d).Trim().Trim([char]'"').TrimEnd([char]'\', [char]'/')
		if ($d -eq "" -or -not (IsDir $d)) { continue }
		$key = $d.ToLowerInvariant()
		if ($seen[$key]) { continue }
		$seen[$key] = $true
		if (IsDir (J $d $BindRel)) { $r += $d }
	}
	return $r
}
function Get-BindBlock($eol) {
	$rows = @(([System.IO.File]::ReadAllText((J $Here "su27radio_binds.lua"))) -split "\r?\n")
	while ($rows.Count -gt 0 -and $rows[$rows.Count - 1] -eq "") { $rows = $rows[0..($rows.Count - 2)] }
	return ([string]::Join($eol, $rows) + $eol)
}
function Strip-Binds([string]$s) {
	return [regex]::Replace($s, "(?ms)^" + [regex]::Escape($BindBegin) + ".*?^" + [regex]::Escape($BindEnd) + "[^\r\n]*(\r?\n)?", "")
}
# "added" / "updated" / "already there" / "removed" / "not there" / why not
function Set-Binds($file, $remove, $backup) {
	if (-not (IsFile $file)) { return "no file" }
	$t = ReadL1 $file
	$has = $t.IndexOf($BindBegin, [System.StringComparison]::Ordinal) -ge 0
	if ($remove) {
		if (-not $has) { return "not there" }
		WriteL1 $file (Strip-Binds $t)
		return "removed"
	}
	$eol = "`n"; if ($t.IndexOf("`r`n", [System.StringComparison]::Ordinal) -ge 0) { $eol = "`r`n" }
	$base = $t
	if ($has) { $base = Strip-Binds $t }
	else { CopyFile $file $backup }        # ED's file as it is now (after an update: the new one)
	$ms = [regex]::Matches($base, "(?m)^return res[ \t]*\r?$")
	if ($ms.Count -eq 0) { return "left alone (not the usual format)" }
	$at = $ms[$ms.Count - 1].Index
	$new = $base.Substring(0, $at) + (Get-BindBlock $eol) + $base.Substring($at)
	if ($new -eq $t) { return "already there" }
	WriteL1 $file $new
	if ($has) { return "updated" }
	return "added"
}
function Do-Binds($remove) {
	$ins = @(Get-DcsInstalls)
	if ($ins.Count -eq 0) {
		Say "Controls: the DCS install folder was not found. Run from a command prompt:"
		Say ("    " + $(if ($remove) { "UNINSTALL.bat" } else { "INSTALL.bat" }) + " -DcsPath ""D:\DCS World""   (your DCS folder)")
		return
	}
	$noAccess = $null
	foreach ($d in $ins) {
		$res = @()
		foreach ($kind in @("joystick", "keyboard")) {
			$f = J $d ($BindRel + "\" + $kind + "\default.lua")
			$bk = J $Root ("backup\ED_Su-27_Input\" + $kind + "\default.lua")
			try { $res += ($kind + " " + (Set-Binds $f $remove $bk)) }
			catch {
				$ex = $_.Exception
				if (($ex -is [System.UnauthorizedAccessException]) -or ($ex.InnerException -is [System.UnauthorizedAccessException])) {
					$res += ($kind + " NOT changed (no permission)"); $noAccess = $d
				} else { $res += ($kind + " NOT changed (" + $ex.Message + ")") }
			}
		}
		Say ("Controls in " + $d + ": " + ($res -join ", "))
		if (-not $remove) { try { [System.IO.File]::WriteAllText((J $Here "dcs_path.txt"), $d) } catch { } }
	}
	if ($noAccess) {
		Say ("  Windows did not allow changes in " + $noAccess + ".")
		Say "  Right-click INSTALL.bat (or UNINSTALL.bat) > Run as administrator."
	}
}

# ---------------------------------------------------------------- run
try {
	Do-Binds ([bool]$Uninstall)
} catch {
	Write-Host ""
	Write-Host ("  PROBLEM: " + $_.Exception.Message) -ForegroundColor Yellow
	exit 1
}
