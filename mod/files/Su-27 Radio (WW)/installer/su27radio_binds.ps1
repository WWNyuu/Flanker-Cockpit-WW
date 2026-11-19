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
# MFD (v0.2): Saved Games\DCS\Scripts\Export.lua gets one line that loads
#   Scripts\S27MFD_Export.lua (the MFD's radar / datalink / RWR feed; INSTALL.bat
#   copies it and Hooks\S27MFD_hook.lua). -SavedGames <folder> (INSTALL.bat
#   passes it).
# UNINSTALL (-Uninstall): takes the block out again (ED's file is then as it was)
#   and the Export.lua line.
# -DcsPath <folder>: the DCS install folder (default: found in the registry /
#   the usual places / the folder remembered in dcs_path.txt).
param([switch]$Uninstall, [string]$DcsPath = "", [string]$SavedGames = "")

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
$BindRel33 = "Mods\aircraft\Su-33\Input"
$ExpComment = "-- Su-27 MFD (WW) add-on (MFD data: radar, datalink, RWR)"
$ExpLine = "pcall(function() local l=require('lfs'); dofile(l.writedir()..'Scripts/S27MFD_Export.lua') end)"

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

# ---------------------------------------------------------------- Export.lua line
function Split-Lines([string]$s) {
	$c = New-Object System.Collections.Generic.List[string]
	$t = New-Object System.Collections.Generic.List[string]
	$i = 0
	while ($i -lt $s.Length) {
		$j = $s.IndexOf([char]10, $i)
		if ($j -lt 0) { $c.Add($s.Substring($i)); $t.Add(""); break }
		if ($j -gt $i -and $s[$j - 1] -eq [char]13) { $c.Add($s.Substring($i, $j - 1 - $i)); $t.Add("`r`n") }
		else { $c.Add($s.Substring($i, $j - $i)); $t.Add("`n") }
		$i = $j + 1
	}
	return @{ c = $c; t = $t }
}
function Is-ActiveExportLine([string]$l) {
	$k = $l.IndexOf("--", [System.StringComparison]::Ordinal)
	if ($k -ge 0) { $l = $l.Substring(0, $k) }
	return ($l.IndexOf("S27MFD_Export.lua", [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
}
function Is-OurExportLine([string]$l) {
	return (($l.IndexOf("S27MFD_Export.lua", [System.StringComparison]::OrdinalIgnoreCase) -ge 0) -or ($l.IndexOf("Su-27 MFD (WW) add-on", [System.StringComparison]::Ordinal) -ge 0))
}
function Check-Export($exp) {
	if (-not (IsFile $exp)) { return }
	$b = [System.IO.File]::ReadAllBytes($exp)
	if ($b.Length -ge 2 -and (($b[0] -eq 0xFF -and $b[1] -eq 0xFE) -or ($b[0] -eq 0xFE -and $b[1] -eq 0xFF))) {
		throw ("Scripts\Export.lua is saved as UTF-16 ('Unicode') - DCS cannot read it like that.`n  Open it in Notepad, File > Save As..., Encoding UTF-8, then run this again.`n    " + $exp)
	}
}
function Add-ExportLine($exp) {
	$s = ""
	if (IsFile $exp) { $s = ReadL1 $exp } else { Ensure-Dir ([System.IO.Path]::GetDirectoryName($exp)) }
	$p = Split-Lines $s
	foreach ($l in $p.c) { if (Is-ActiveExportLine $l) { return "line already there" } }
	$nl = "`r`n"
	if ($s.IndexOf("`r`n", [System.StringComparison]::Ordinal) -lt 0 -and $s.IndexOf([char]10) -ge 0) { $nl = "`n" }
	if ($s.Length -eq 0) { $add = $ExpComment + $nl + $ExpLine + $nl }
	elseif ($p.t[$p.t.Count - 1] -eq "") { $add = $nl + $nl + $ExpComment + $nl + $ExpLine }
	else { $add = $nl + $ExpComment + $nl + $ExpLine + $nl }
	WriteL1 $exp ($s + $add)
	return "line added"
}
function Remove-ExportLine($exp) {
	if (-not (IsFile $exp)) { return 0 }
	$s = ReadL1 $exp
	$p = Split-Lines $s
	$n = $p.c.Count
	$cnt = 0
	$drop = New-Object bool[] ([Math]::Max($n, 1))
	for ($i = 0; $i -lt $n; $i++) { if (Is-OurExportLine $p.c[$i]) { $drop[$i] = $true; $cnt++ } }
	if ($cnt -eq 0) { return 0 }
	for ($i = 1; $i -lt $n; $i++) {
		if ($drop[$i] -and -not $drop[$i - 1] -and $p.c[$i].IndexOf("Su-27 MFD (WW) add-on", [System.StringComparison]::Ordinal) -ge 0 -and $p.c[$i - 1].Trim() -eq "") { $drop[$i - 1] = $true }
	}
	$last = -1
	for ($i = 0; $i -lt $n; $i++) { if (-not $drop[$i]) { $last = $i } }
	$noEnd = $drop[$n - 1] -and ($p.t[$n - 1] -eq "")
	$sb = New-Object System.Text.StringBuilder
	for ($i = 0; $i -lt $n; $i++) {
		if ($drop[$i]) { continue }
		[void]$sb.Append($p.c[$i])
		if (-not ($noEnd -and $i -eq $last)) { [void]$sb.Append($p.t[$i]) }
	}
	WriteL1 $exp $sb.ToString()
	return $cnt
}


function Do-Export($remove) {
	if ($SavedGames -eq "" -or -not (IsDir $SavedGames)) { Say "Export.lua: Saved Games folder not given, not changed"; return }
	$exp = J $SavedGames "Scripts\Export.lua"
	Check-Export $exp
	if ($remove) {
		$n = Remove-ExportLine $exp
		Say ("Export.lua: " + $(if ($n -gt 0) { "MFD line removed" } else { "no MFD line" }))
	} else {
		Say ("Export.lua: " + (Add-ExportLine $exp))
	}
}

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
		# v1.3 test 8: the Su-33 too (its controls are in Input\joystick, no su-33 folder)
		foreach ($jet in @(@("Su-27", $BindRel), @("Su-33", $BindRel33))) {
			if (-not (IsDir (J $d $jet[1]))) { continue }
			foreach ($kind in @("joystick", "keyboard")) {
				$f = J $d ($jet[1] + "\" + $kind + "\default.lua")
				$bk = J $Root ("backup\ED_" + $jet[0] + "_Input\" + $kind + "\default.lua")
				try { $res += ($jet[0] + " " + $kind + " " + (Set-Binds $f $remove $bk)) }
				catch {
					$ex = $_.Exception
					if (($ex -is [System.UnauthorizedAccessException]) -or ($ex.InnerException -is [System.UnauthorizedAccessException])) {
						$res += ($jet[0] + " " + $kind + " NOT changed (no permission)"); $noAccess = $d
					} else { $res += ($jet[0] + " " + $kind + " NOT changed (" + $ex.Message + ")") }
				}
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
	Do-Export ([bool]$Uninstall)
} catch {
	Write-Host ("  PROBLEM (Export.lua): " + $_.Exception.Message) -ForegroundColor Yellow
}
try {
	Do-Binds ([bool]$Uninstall)
} catch {
	Write-Host ""
	Write-Host ("  PROBLEM: " + $_.Exception.Message) -ForegroundColor Yellow
	exit 1
}
