# Prompt: [(venv) ][[root@]host ]~/path[ git][ duration] ❯ (git is async)

zmodload zsh/datetime zsh/system
autoload -Uz add-zsh-hook

# The prompt shows the venv itself
export VIRTUAL_ENV_DISABLE_PROMPT=1
export CONDA_CHANGEPS1=false

# Identity segment, computed once
_prompt_identity=
() {
	local color= virt=
	if (( $+commands[systemd-detect-virt] )); then
		virt=$(systemd-detect-virt --container 2>/dev/null)
	fi
	if [[ -e /.dockerenv || -e /run/.containerenv || -n $container ]] \
		|| [[ -n $virt && $virt != none && $virt != wsl ]]; then
		color=blue
	elif [[ -n $SSH_CONNECTION || -n $SSH_CLIENT || -n $SSH_TTY ]]; then
		color=yellow
	elif [[ -n $WSL_DISTRO_NAME || -e /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
		color=green
	fi

	if (( EUID == 0 )); then
		_prompt_identity='%B%F{red}root%f%b'
		[[ -n $color ]] && _prompt_identity+="%F{$color}@%m%f"
	elif [[ -n $color ]]; then
		_prompt_identity="%F{$color}%m%f"
	fi
	[[ -n $_prompt_identity ]] && _prompt_identity+=' '
}

# Walk up for .git without spawning git
_prompt_in_repo() {
	[[ -n $GIT_DIR ]] && return 0
	local d=$PWD
	while :; do
		[[ -e $d/.git ]] && return 0
		[[ $d == / ]] && return 1
		d=${d:h}
	done
}

# Runs in a background subshell
_prompt_git_info() {
	emulate -L zsh
	(( $+commands[git] )) || return

	local gitdir inside
	{ IFS= read -r gitdir; IFS= read -r inside } \
		< <(command git rev-parse --git-dir --is-inside-work-tree 2>/dev/null)
	[[ $inside == true ]] || return

	local line head oid ahead=0 behind=0 staged= unstaged= untracked= conflict=
	while IFS= read -r line; do
		case $line in
			('# branch.oid '*) oid=${line#\# branch.oid } ;;
			('# branch.head '*) head=${line#\# branch.head } ;;
			('# branch.ab '*)
				line=${line#\# branch.ab }
				ahead=${${line%% *}#+}
				behind=${${line##* }#-} ;;
			([12]' '*)
				[[ ${line[3]} != . ]] && staged=1
				[[ ${line[4]} != . ]] && unstaged=1 ;;
			('u '*) conflict=1 ;;
			('? '*) untracked=1 ;;
		esac
	done < <(command git status --porcelain=v2 --branch 2>/dev/null)

	local op=
	if [[ -d $gitdir/rebase-merge ]]; then op=rebase
	elif [[ -d $gitdir/rebase-apply ]]; then
		if [[ -f $gitdir/rebase-apply/applying ]]; then op=am; else op=rebase; fi
	elif [[ -f $gitdir/MERGE_HEAD ]]; then op=merge
	elif [[ -f $gitdir/CHERRY_PICK_HEAD ]]; then op=cherry-pick
	elif [[ -f $gitdir/REVERT_HEAD ]]; then op=revert
	elif [[ -f $gitdir/BISECT_LOG ]]; then op=bisect
	fi

	local out marks=
	if [[ $head == '(detached)' ]]; then
		out=" %B%F{cyan}${oid[1,7]}%f%b"
	else
		out=" %B%F{magenta}${head//\%/%%}%f%b"
	fi
	[[ -n $staged ]] && marks+='%F{green}+%f'
	[[ -n $unstaged ]] && marks+='%F{yellow}*%f'
	[[ -n $untracked ]] && marks+='%F{red}?%f'
	[[ -n $conflict ]] && marks+='%B%F{cyan}!%f%b'
	[[ -n $marks ]] && out+=" $marks"
	[[ -n $op ]] && out+=" %F{yellow}$op%f"
	(( ahead > 0 )) && out+=" %F{cyan}⇡$ahead%f"
	(( behind > 0 )) && out+=" %F{cyan}⇣$behind%f"
	print -rn -- "$out"
}

# SGR faint on/off
_prompt_faint=$'\e[2m' _prompt_unfaint=$'\e[22m'

# Abbreviate parent dirs past $PROMPT_DIR_MAX chars (default 40): ~/D/d/zsh
_prompt_dir() {
	emulate -L zsh
	local dir=${(%):-%~}
	if (( $#dir > ${PROMPT_DIR_MAX:-40} )); then
		local -a parts=("${(@s:/:)dir}")
		local -i i
		for (( i = 2; i < $#parts; i++ )); do
			if [[ $parts[i] == .* ]]; then
				parts[i]=${parts[i][1,2]}
			else
				parts[i]=${parts[i][1]}
			fi
		done
		dir=${(j:/:)parts}
	fi
	typeset -g REPLY=${dir//\%/%%}
}

_prompt_render() {
	local venv=
	if [[ -n $VIRTUAL_ENV ]]; then
		venv=${VIRTUAL_ENV_PROMPT//[() ]/}
		[[ -n $venv ]] || venv=${VIRTUAL_ENV:t}
	elif [[ -n $CONDA_DEFAULT_ENV && $CONDA_DEFAULT_ENV != base ]]; then
		venv=$CONDA_DEFAULT_ENV
	fi
	[[ -n $venv ]] && venv="%F{8}(${venv//\%/%%})%f "

	_prompt_dir
	PROMPT="${venv}${_prompt_identity}%{$_prompt_faint%}${REPLY}%{$_prompt_unfaint%}${_prompt_git}${_prompt_duration} %F{${_prompt_char_color}}❯%f "
}

_prompt_git_done() {
	emulate -L zsh
	local fd=$1 data=
	if [[ -z $2 || $2 == hup ]]; then
		IFS= read -r -u $fd data
		exec {fd}<&-
	fi
	zle -F $fd 2>/dev/null
	_prompt_git_fd=

	if [[ $data != $_prompt_git ]]; then
		_prompt_git=$data
		_prompt_render
		zle && zle reset-prompt
	fi
}

_prompt_git_request() {
	emulate -L zsh
	typeset -g _prompt_git_fd _prompt_git_pid

	# Cancel any in-flight request
	if [[ -n $_prompt_git_fd ]] && { true <&$_prompt_git_fd } 2>/dev/null; then
		zle -F $_prompt_git_fd 2>/dev/null
		exec {_prompt_git_fd}<&-
		kill -TERM $_prompt_git_pid 2>/dev/null
	fi
	_prompt_git_fd=

	if ! _prompt_in_repo; then
		_prompt_git=
		return
	fi

	exec {_prompt_git_fd}< <(
		print -r -- $sysparams[pid]
		_prompt_git_info
	)
	# Force a fork so Ctrl+C keeps working (zsh quirk)
	command true
	read -r _prompt_git_pid <&$_prompt_git_fd
	zle -F $_prompt_git_fd _prompt_git_done
}

_prompt_preexec() {
	_prompt_timer=$EPOCHREALTIME
}

_prompt_precmd() {
	local exit_status=$?
	_prompt_char_color=green
	(( exit_status != 0 )) && _prompt_char_color=red

	_prompt_duration=
	if [[ -n $_prompt_timer ]]; then
		local -i secs=$(( EPOCHREALTIME - _prompt_timer ))
		if (( secs >= 5 )); then
			local d=
			(( secs >= 3600 )) && d+="$(( secs / 3600 ))h "
			(( secs % 3600 >= 60 )) && d+="$(( secs % 3600 / 60 ))m "
			(( secs % 60 )) && d+="$(( secs % 60 ))s"
			_prompt_duration=" %F{yellow}${d% }%f"
		fi
		_prompt_timer=
	fi

	# Keep the stale git segment until the directory changes
	if [[ $PWD != $_prompt_git_pwd ]]; then
		_prompt_git=
		_prompt_git_pwd=$PWD
	fi

	_prompt_git_request
	_prompt_render
}

# First, so $? is intact
precmd_functions=(_prompt_precmd ${precmd_functions:#_prompt_precmd})
add-zsh-hook preexec _prompt_preexec

# Right-aligned time
RPROMPT="%{$_prompt_faint%}%D{%H:%M:%S}%{$_prompt_unfaint%}"
