#Requires -Version 7
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

#Basic PSReadLine Settings
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -HistoryNoDuplicates:$true
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadlineKeyHandler -Chord Ctrl+d -Function ViExit
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

#region Smart Insert/Delete
# The next four key handlers are designed to make entering matched quotes
# parens, and braces a nicer experience.  I'd like to include functions
# in the module that do this, but this implementation still isn't as smart
# as ReSharper, so I'm just providing it as a sample.
Set-PSReadLineKeyHandler -Key '"', "'" `
    -BriefDescription SmartInsertQuote `
    -LongDescription "Insert paired quotes if not already on a quote" `
    -ScriptBlock {
    param($key, $arg)

    $quote = $key.KeyChar

    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    # If text is selected, just quote it without any smarts
    if ($selectionStart -ne -1)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $quote + $line.SubString($selectionStart, $selectionLength) + $quote)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
        return
    }

    $ast = $null
    $tokens = $null
    $parseErrors = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$parseErrors, [ref]$null)

    function FindToken
    {
        param($tokens, $cursor)

        foreach ($token in $tokens)
        {
            if ($cursor -lt $token.Extent.StartOffset)
            { continue
            }
            if ($cursor -lt $token.Extent.EndOffset)
            {
                $result = $token
                $token = $token -as [StringExpandableToken]
                if ($token)
                {
                    $nested = FindToken $token.NestedTokens $cursor
                    if ($nested)
                    { $result = $nested
                    }
                }

                return $result
            }
        }
        return $null
    }

    $token = FindToken $tokens $cursor

    # If we're on or inside a **quoted** string token (so not generic), we need to be smarter
    if ($token -is [StringToken] -and $token.Kind -ne [TokenKind]::Generic)
    {
        # If we're at the start of the string, assume we're inserting a new string
        if ($token.Extent.StartOffset -eq $cursor)
        {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote ")
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
            return
        }

        # If we're at the end of the string, move over the closing quote if present.
        if ($token.Extent.EndOffset -eq ($cursor + 1) -and $line[$cursor] -eq $quote)
        {
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
            return
        }
    }

    if ($null -eq $token -or
        $token.Kind -eq [TokenKind]::RParen -or $token.Kind -eq [TokenKind]::RCurly -or $token.Kind -eq [TokenKind]::RBracket)
    {
        if ($line[0..$cursor].Where{ $_ -eq $quote }.Count % 2 -eq 1)
        {
            # Odd number of quotes before the cursor, insert a single quote
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
        } else
        {
            # Insert matching quotes, move cursor to be in between the quotes
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote")
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
        }
        return
    }

    # If cursor is at the start of a token, enclose it in quotes.
    if ($token.Extent.StartOffset -eq $cursor)
    {
        if ($token.Kind -eq [TokenKind]::Generic -or $token.Kind -eq [TokenKind]::Identifier -or
            $token.Kind -eq [TokenKind]::Variable -or $token.TokenFlags.hasFlag([TokenFlags]::Keyword))
        {
            $end = $token.Extent.EndOffset
            $len = $end - $cursor
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace($cursor, $len, $quote + $line.SubString($cursor, $len) + $quote)
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($end + 2)
            return
        }
    }

    # We failed to be smart, so just insert a single quote
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
}

Set-PSReadLineKeyHandler -Key '(', '{', '[' `
    -BriefDescription InsertPairedBraces `
    -LongDescription "Insert matching braces" `
    -ScriptBlock {
    param($key, $arg)

    $closeChar = switch ($key.KeyChar)
    {
        <#case#> '('
        { [char]')'; break
        }
        <#case#> '{'
        { [char]'}'; break
        }
        <#case#> '['
        { [char]']'; break
        }
    }

    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($selectionStart -ne -1)
    {
        # Text is selected, wrap it in brackets
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $key.KeyChar + $line.SubString($selectionStart, $selectionLength) + $closeChar)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
    } else
    {
        # No text is selected, insert a pair
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)$closeChar")
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    }
}

Set-PSReadLineKeyHandler -Key ')', ']', '}' `
    -BriefDescription SmartCloseBraces `
    -LongDescription "Insert closing brace or skip" `
    -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($line[$cursor] -eq $key.KeyChar)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    } else
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)")
    }
}

Set-PSReadLineKeyHandler -Key Backspace `
    -BriefDescription SmartBackspace `
    -LongDescription "Delete previous character or matching quotes/parens/braces" `
    -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($cursor -gt 0)
    {
        $toMatch = $null
        if ($cursor -lt $line.Length)
        {
            switch ($line[$cursor])
            {
                <#case#> '"'
                { $toMatch = '"'; break
                }
                <#case#> "'"
                { $toMatch = "'"; break
                }
                <#case#> ')'
                { $toMatch = '('; break
                }
                <#case#> ']'
                { $toMatch = '['; break
                }
                <#case#> '}'
                { $toMatch = '{'; break
                }
            }
        }

        if ($toMatch -ne $null -and $line[$cursor - 1] -eq $toMatch)
        {
            [Microsoft.PowerShell.PSConsoleReadLine]::Delete($cursor - 1, 2)
        } else
        {
            [Microsoft.PowerShell.PSConsoleReadLine]::BackwardDeleteChar($key, $arg)
        }
    }
}
#endregion Smart Insert/Delete

# Sometimes you enter a command but realize you forgot to do something else first.
# This binding will let you save that command in the history so you can recall it,
# but it doesn't actually execute.  It also clears the line with RevertLine so the
# undo stack is reset - though redo will still reconstruct the command line.
Set-PSReadLineKeyHandler -Key Alt+w `
    -BriefDescription SaveInHistory `
    -LongDescription "Save current line in history but do not execute" `
    -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    [Microsoft.PowerShell.PSConsoleReadLine]::AddToHistory($line)
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
}

# `ForwardChar` accepts the entire suggestion text when the cursor is at the end of the line.
# This custom binding makes `RightArrow` behave similarly - accepting the next word instead of the entire suggestion text.
Set-PSReadLineKeyHandler -Key RightArrow `
    -BriefDescription ForwardCharAndAcceptNextSuggestionWord `
    -LongDescription "Move cursor one character to the right in the current editing line and accept the next word in suggestion when it's at the end of current editing line" `
    -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($cursor -lt $line.Length)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::ForwardChar($key, $arg)
    } else
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptNextSuggestionWord($key, $arg)
    }
}

# Cycle through arguments on current line and select the text. This makes it easier to quickly change the argument if re-running a previously run command from the history
# or if using a psreadline predictor. You can also use a digit argument to specify which argument you want to select, i.e. Alt+1, Alt+a selects the first argument
# on the command line.
Set-PSReadLineKeyHandler -Key Alt+a `
    -BriefDescription SelectCommandArguments `
    -LongDescription "Set current selection to next command argument in the command line. Use of digit argument selects argument by position" `
    -ScriptBlock {
    param($key, $arg)

    $ast = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$null, [ref]$null, [ref]$cursor)

    $asts = $ast.FindAll( {
            $args[0] -is [System.Management.Automation.Language.ExpressionAst] -and
            $args[0].Parent -is [System.Management.Automation.Language.CommandAst] -and
            $args[0].Extent.StartOffset -ne $args[0].Parent.Extent.StartOffset
        }, $true)

    if ($asts.Count -eq 0)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
        return
    }

    $nextAst = $null

    if ($null -ne $arg)
    {
        $nextAst = $asts[$arg - 1]
    } else
    {
        foreach ($ast in $asts)
        {
            if ($ast.Extent.StartOffset -ge $cursor)
            {
                $nextAst = $ast
                break
            }
        }

        if ($null -eq $nextAst)
        {
            $nextAst = $asts[0]
        }
    }

    $startOffsetAdjustment = 0
    $endOffsetAdjustment = 0

    if ($nextAst -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
        $nextAst.StringConstantType -ne [System.Management.Automation.Language.StringConstantType]::BareWord)
    {
        $startOffsetAdjustment = 1
        $endOffsetAdjustment = 2
    }

    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($nextAst.Extent.StartOffset + $startOffsetAdjustment)
    [Microsoft.PowerShell.PSConsoleReadLine]::SetMark($null, $null)
    [Microsoft.PowerShell.PSConsoleReadLine]::SelectForwardChar($null, ($nextAst.Extent.EndOffset - $nextAst.Extent.StartOffset) - $endOffsetAdjustment)
}

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

# function prompt {
#   # First, emit a mark for the _end_ of the previous command.
#   $gle = $(__Terminal-Get-LastExitCode);
#   $LastHistoryEntry = $(Get-History -Count 1)
#   # Skip finishing the command if the first command has not yet started
#   if ($Global:__LastHistoryId -ne -1) {
#     if ($LastHistoryEntry.Id -eq $Global:__LastHistoryId) {
#       # Don't provide a command line or exit code if there was no history entry (eg. ctrl+c, enter on no command)
#       $out += "`e]133;D`a"
#     } else {
#       $out += "`e]133;D;$gle`a"
#     }
#   }


#   $loc = $($executionContext.SessionState.Path.CurrentLocation);

#   # Prompt started
#   $out += "`e]133;A$([char]07)";

#   # CWD
#   $out += "`e]9;9;`"$loc`"$([char]07)";

#   # (your prompt here)
#   $out += "PS $loc$('>' * ($nestedPromptLevel + 1)) ";

#   # Prompt ended, Command started
#   $out += "`e]133;B$([char]07)";

#   $Global:__LastHistoryId = $LastHistoryEntry.Id

#   return $out
# }
Import-Module scoop-completion
Import-Module posh-git
. "$HOME\scoop\apps\chezmoi\current\completions\chezmoi.ps1"
