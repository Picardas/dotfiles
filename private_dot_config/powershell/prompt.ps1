# Prompt: [(venv) ][[root@]host ]~/path[ git][ duration] ❯

# The prompt shows the venv itself
$env:VIRTUAL_ENV_DISABLE_PROMPT = '1'
$env:CONDA_CHANGEPS1 = 'false'

function global:Get-PromptColor([string]$Code) { "`e[$($Code)m" }
$global:PromptReset = "`e[0m"

# Identity segment, computed once
$global:PromptIdentity = ''
& {
	$color = $null
	if ($IsLinux) {
		$virt = $null
		if (Get-Command systemd-detect-virt -CommandType Application -ErrorAction Ignore) {
			$virt = systemd-detect-virt --container 2>$null
		}
		if ((Test-Path /.dockerenv) -or (Test-Path /run/.containerenv) -or $env:container -or
			($virt -and $virt -ne 'none' -and $virt -ne 'wsl')) {
			$color = '34'
		}
	}
	if (-not $color -and ($env:SSH_CONNECTION -or $env:SSH_CLIENT -or $env:SSH_TTY)) {
		$color = '33'
	}
	if (-not $color -and $IsLinux -and
		($env:WSL_DISTRO_NAME -or (Test-Path /proc/sys/fs/binfmt_misc/WSLInterop))) {
		$color = '32'
	}

	if ($IsWindows) {
		$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
		$isRoot = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
	} else {
		$isRoot = (id -u) -eq '0'
	}

	$hostName = ([Environment]::MachineName -split '\.')[0]
	$identity = ''
	if ($isRoot) {
		$identity = "$(Get-PromptColor '1;31')root$global:PromptReset"
		if ($color) { $identity += "$(Get-PromptColor $color)@$hostName$global:PromptReset" }
	} elseif ($color) {
		$identity = "$(Get-PromptColor $color)$hostName$global:PromptReset"
	}
	if ($identity) { $global:PromptIdentity = "$identity " }
}

# Resolved once per session
$global:PromptGit = (Get-Command git -CommandType Application -ErrorAction Ignore |
	Select-Object -First 1).Source

# Walk up for .git without spawning git
function global:Test-PromptInRepo {
	if ($env:GIT_DIR) { return $true }
	$dir = $executionContext.SessionState.Path.CurrentFileSystemLocation.ProviderPath
	while ($dir) {
		$dotGit = [IO.Path]::Combine($dir, '.git')
		if ([IO.Directory]::Exists($dotGit) -or [IO.File]::Exists($dotGit)) { return $true }
		$dir = [IO.Path]::GetDirectoryName($dir)
	}
	return $false
}

function global:Get-PromptGit {
	if (-not $global:PromptGit -or -not (Test-PromptInRepo)) { return '' }

	$revParse = @(& $global:PromptGit rev-parse --git-dir --is-inside-work-tree 2>$null)
	if ($revParse.Count -lt 2 -or $revParse[1] -ne 'true') { return '' }
	$gitDir = $revParse[0]

	$head = ''; $oid = ''; $ahead = 0; $behind = 0
	$staged = $false; $unstaged = $false; $untracked = $false; $conflict = $false
	foreach ($line in @(& $global:PromptGit status --porcelain=v2 --branch 2>$null)) {
		if ($line.StartsWith('# branch.oid ')) { $oid = $line.Substring(13) }
		elseif ($line.StartsWith('# branch.head ')) { $head = $line.Substring(14) }
		elseif ($line.StartsWith('# branch.ab ')) {
			$ab = $line.Substring(12) -split ' '
			$ahead = [int]$ab[0].TrimStart('+')
			$behind = [int]$ab[1].TrimStart('-')
		}
		elseif ($line -match '^[12] ') {
			if ($line[2] -ne '.') { $staged = $true }
			if ($line[3] -ne '.') { $unstaged = $true }
		}
		elseif ($line.StartsWith('u ')) { $conflict = $true }
		elseif ($line.StartsWith('? ')) { $untracked = $true }
	}

	$op = ''
	if (Test-Path -PathType Container (Join-Path $gitDir 'rebase-merge')) { $op = 'rebase' }
	elseif (Test-Path -PathType Container (Join-Path $gitDir 'rebase-apply')) {
		$op = if (Test-Path (Join-Path $gitDir 'rebase-apply/applying')) { 'am' } else { 'rebase' }
	}
	elseif (Test-Path (Join-Path $gitDir 'MERGE_HEAD')) { $op = 'merge' }
	elseif (Test-Path (Join-Path $gitDir 'CHERRY_PICK_HEAD')) { $op = 'cherry-pick' }
	elseif (Test-Path (Join-Path $gitDir 'REVERT_HEAD')) { $op = 'revert' }
	elseif (Test-Path (Join-Path $gitDir 'BISECT_LOG')) { $op = 'bisect' }

	$r = $global:PromptReset
	if ($head -eq '(detached)') {
		$out = " $(Get-PromptColor '1;36')$($oid.Substring(0, [Math]::Min(7, $oid.Length)))$r"
	} else {
		$out = " $(Get-PromptColor '1;35')$head$r"
	}
	$marks = ''
	if ($staged) { $marks += "$(Get-PromptColor 32)+$r" }
	if ($unstaged) { $marks += "$(Get-PromptColor 33)*$r" }
	if ($untracked) { $marks += "$(Get-PromptColor 31)?$r" }
	if ($conflict) { $marks += "$(Get-PromptColor '1;36')!$r" }
	if ($marks) { $out += " $marks" }
	if ($op) { $out += " $(Get-PromptColor 33)$op$r" }
	if ($ahead -gt 0) { $out += " $(Get-PromptColor 36)⇡$ahead$r" }
	if ($behind -gt 0) { $out += " $(Get-PromptColor 36)⇣$behind$r" }
	return $out
}

$global:PromptLastHistoryId = (Get-History -Count 1).Id

function prompt {
	$failed = -not $?
	$origLastExitCode = $global:LASTEXITCODE
	$r = $global:PromptReset

	$duration = ''
	$last = Get-History -Count 1
	if ($last -and $last.Id -ne $global:PromptLastHistoryId) {
		$global:PromptLastHistoryId = $last.Id
		$secs = [int][Math]::Floor(($last.EndExecutionTime - $last.StartExecutionTime).TotalSeconds)
		if ($secs -ge 5) {
			$parts = @()
			if ($secs -ge 3600) { $parts += "$([Math]::Floor($secs / 3600))h" }
			if ($secs % 3600 -ge 60) { $parts += "$([Math]::Floor(($secs % 3600) / 60))m" }
			if ($secs % 60) { $parts += "$($secs % 60)s" }
			$duration = " $(Get-PromptColor 33)$($parts -join ' ')$r"
		}
	}

	$venv = ''
	if ($env:VIRTUAL_ENV) {
		$venv = $env:VIRTUAL_ENV_PROMPT -replace '[() ]', ''
		if (-not $venv) { $venv = Split-Path -Leaf $env:VIRTUAL_ENV }
	} elseif ($env:CONDA_DEFAULT_ENV -and $env:CONDA_DEFAULT_ENV -ne 'base') {
		$venv = $env:CONDA_DEFAULT_ENV
	}
	if ($venv) { $venv = "$(Get-PromptColor 90)($venv)$r " }

	$path = $executionContext.SessionState.Path.CurrentLocation.Path
	if ($path -eq $HOME) {
		$path = '~'
	} elseif ($path.StartsWith("$HOME$([IO.Path]::DirectorySeparatorChar)")) {
		$path = '~' + $path.Substring($HOME.Length)
	}

	# Abbreviate parent dirs past $env:PROMPT_DIR_MAX chars (default 40): ~/D/d/powershell
	$dirMax = 40
	if ($env:PROMPT_DIR_MAX -match '^\d+$') { $dirMax = [int]$env:PROMPT_DIR_MAX }
	if ($path.Length -gt $dirMax) {
		$sep = [IO.Path]::DirectorySeparatorChar
		$parts = $path.Split($sep)
		for ($i = 1; $i -lt $parts.Count - 1; $i++) {
			$keep = if ($parts[$i].StartsWith('.')) { 2 } else { 1 }
			$parts[$i] = $parts[$i].Substring(0, [Math]::Min($keep, $parts[$i].Length))
		}
		$path = $parts -join $sep
	}

	$charColor = if ($failed) { '31' } else { '32' }
	$git = Get-PromptGit

	$global:LASTEXITCODE = $origLastExitCode
	$char = '❯' * ($NestedPromptLevel + 1)

	# Right-aligned time: save cursor, draw, restore
	$time = ''
	$width = $Host.UI.RawUI.WindowSize.Width
	if ($width -gt 40) {
		$time = "`e7`e[$($width - 8)G$(Get-PromptColor 2)$(Get-Date -Format HH:mm:ss)$r`e8"
	}
	return "$time$venv$global:PromptIdentity$(Get-PromptColor 2)$path$r$git$duration $(Get-PromptColor $charColor)$char$r "
}
