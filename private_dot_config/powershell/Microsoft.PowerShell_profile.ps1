#Requires -Version 7

#Basic PSReadLine Settings
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -HistoryNoDuplicates:$true
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadlineKeyHandler -Chord Ctrl+d -Function ViExit
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# More key handlers, from PSReadLine's sample profile
# https://github.com/PowerShell/PSReadLine/blob/master/PSReadLine/SamplePSReadLineProfile.ps1
. (Join-Path $PSScriptRoot 'psreadline-handlers.ps1')

# Windows Terminal Integration
$Global:__LastHistoryId = -1

function Global:__Terminal-Get-LastExitCode
{
	if ($? -eq $True)
	{
		return 0
	}
	$LastHistoryEntry = $(Get-History -Count 1)
	$IsPowerShellError = $Error[0].InvocationInfo.HistoryId -eq $LastHistoryEntry.Id
	if ($IsPowerShellError)
	{
		return -1
	}
	return $LastExitCode
}

# posh-git is kept for git tab completion; the prompt comes from prompt.ps1
Import-Module posh-git
Import-Module chezmoi-completions

. (Join-Path $PSScriptRoot 'prompt.ps1')
