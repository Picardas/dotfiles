# Prompt: [(venv) ][[root@]host ]~/path[ git][ duration] ❯ (duration needs bash 5+)

case $- in
	*i*) ;;
	*) return ;;
esac

# The prompt shows the venv itself
export VIRTUAL_ENV_DISABLE_PROMPT=1
export CONDA_CHANGEPS1=false

# SGR code, zero-width for readline
_prompt_c() { printf '\001\033[%sm\002' "$1"; }
_PROMPT_RESET=$(_prompt_c 0)

# Identity segment, computed once
_prompt_set_identity() {
	local color= virt=
	if command -v systemd-detect-virt > /dev/null 2>&1 ; then
		virt=$(systemd-detect-virt --container 2>/dev/null)
	fi
	if [[ -e /.dockerenv || -e /run/.containerenv || -n $container ]] \
		|| [[ -n $virt && $virt != none && $virt != wsl ]]; then
		color=34
	elif [[ -n $SSH_CONNECTION || -n $SSH_CLIENT || -n $SSH_TTY ]]; then
		color=33
	elif [[ -n $WSL_DISTRO_NAME || -e /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
		color=32
	fi

	_prompt_identity=
	if (( EUID == 0 )); then
		_prompt_identity="$(_prompt_c '1;31')root${_PROMPT_RESET}"
		[[ -n $color ]] && _prompt_identity+="$(_prompt_c "$color")@${HOSTNAME%%.*}${_PROMPT_RESET}"
	elif [[ -n $color ]]; then
		_prompt_identity="$(_prompt_c "$color")${HOSTNAME%%.*}${_PROMPT_RESET}"
	fi
	[[ -n $_prompt_identity ]] && _prompt_identity+=' '
}
_prompt_set_identity
unset -f _prompt_set_identity

# Walk up for .git without spawning git
_prompt_in_repo() {
	[[ -n $GIT_DIR ]] && return 0
	local d=$PWD
	while :; do
		[[ -e $d/.git ]] && return 0
		[[ -z $d || $d == / ]] && return 1
		d=${d%/*}
	done
}

_prompt_git_info() {
	command -v git > /dev/null 2>&1 || return

	local gitdir inside
	{ IFS= read -r gitdir; IFS= read -r inside; } \
		< <(command git rev-parse --git-dir --is-inside-work-tree 2>/dev/null)
	[[ $inside == true ]] || return

	local line head= oid= ahead=0 behind=0 staged= unstaged= untracked= conflict=
	while IFS= read -r line; do
		case $line in
			'# branch.oid '*) oid=${line#\# branch.oid } ;;
			'# branch.head '*) head=${line#\# branch.head } ;;
			'# branch.ab '*)
				line=${line#\# branch.ab }
				ahead=${line%% *}; ahead=${ahead#+}
				behind=${line##* }; behind=${behind#-} ;;
			[12]' '*)
				[[ ${line:2:1} != . ]] && staged=1
				[[ ${line:3:1} != . ]] && unstaged=1 ;;
			'u '*) conflict=1 ;;
			'? '*) untracked=1 ;;
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

	local r=$_PROMPT_RESET out marks=
	if [[ $head == '(detached)' ]]; then
		out=" $(_prompt_c '1;36')${oid:0:7}$r"
	else
		out=" $(_prompt_c '1;35')$head$r"
	fi
	[[ -n $staged ]] && marks+="$(_prompt_c 32)+$r"
	[[ -n $unstaged ]] && marks+="$(_prompt_c 33)*$r"
	[[ -n $untracked ]] && marks+="$(_prompt_c 31)?$r"
	[[ -n $conflict ]] && marks+="$(_prompt_c '1;36')!$r"
	[[ -n $marks ]] && out+=" $marks"
	[[ -n $op ]] && out+=" $(_prompt_c 33)$op$r"
	(( ahead > 0 )) && out+=" $(_prompt_c 36)⇡$ahead$r"
	(( behind > 0 )) && out+=" $(_prompt_c 36)⇣$behind$r"
	printf '%s' "$out"
}

# Command start time
_prompt_timer=
if [[ -n $EPOCHREALTIME ]]; then
	PS0='${_prompt_timer:0:$((_prompt_timer=${EPOCHREALTIME/[.,]/}, 0))}'
fi

# First, so $? is intact
_prompt_save_status() { _prompt_status=$?; }

# Last, so it overrides other hooks
_prompt_command() {
	local exit_status=${_prompt_status:-0} r=$_PROMPT_RESET

	local duration=
	if [[ -n $_prompt_timer ]]; then
		local secs=$(( (${EPOCHREALTIME/[.,]/} - _prompt_timer) / 1000000 ))
		if (( secs >= 5 )); then
			local d=
			(( secs >= 3600 )) && d+="$(( secs / 3600 ))h "
			(( secs % 3600 >= 60 )) && d+="$(( secs % 3600 / 60 ))m "
			(( secs % 60 )) && d+="$(( secs % 60 ))s"
			duration=" $(_prompt_c 33)${d% }$r"
		fi
		_prompt_timer=
	fi

	local venv=
	if [[ -n $VIRTUAL_ENV ]]; then
		venv=${VIRTUAL_ENV_PROMPT//[() ]/}
		[[ -n $venv ]] || venv=${VIRTUAL_ENV##*/}
	elif [[ -n $CONDA_DEFAULT_ENV && $CONDA_DEFAULT_ENV != base ]]; then
		venv=$CONDA_DEFAULT_ENV
	fi
	[[ -n $venv ]] && venv="$(_prompt_c 90)($venv)$r "

	local path=$PWD
	if [[ $PWD == "$HOME" ]]; then
		path='~'
	elif [[ $PWD == "$HOME"/* ]]; then
		path="~${PWD#"$HOME"}"
	fi

	# Abbreviate parent dirs past $PROMPT_DIR_MAX chars (default 40): ~/D/d/bash
	local dir=$path
	if (( ${#dir} > ${PROMPT_DIR_MAX:-40} )) && [[ $dir == */*/* ]]; then
		local rest=${dir#*/} part
		dir=${dir%%/*}/
		while [[ $rest == */* ]]; do
			part=${rest%%/*}
			rest=${rest#*/}
			if [[ $part == .* ]]; then dir+=${part:0:2}/; else dir+=${part:0:1}/; fi
		done
		dir+=$rest
	fi

	local git=
	_prompt_in_repo && git=$(_prompt_git_info)

	local char_color=32
	(( exit_status != 0 )) && char_color=31

	# Indirect, so branch names aren't expanded
	_prompt_ps1="${venv}${_prompt_identity}$(_prompt_c 2)${dir}$r${git}${duration} $(_prompt_c "$char_color")❯$r "
	# Right-aligned time: save cursor, draw, restore
	PS1='\[\e7\e[$((${COLUMNS:-80} - 8))G\e[2m\t\e[0m\e8\]${_prompt_ps1}'

	# Window title
	case $TERM in
		xterm*|*-256color|alacritty|foot*|tmux*) printf '\033]0;%s\007' "$path" ;;
	esac

	return $exit_status
}

case "$PROMPT_COMMAND" in
	*_prompt_command*) ;;
	*)
		# Trim trailing ; to avoid "; ;"
		_prompt_pc=${PROMPT_COMMAND%"${PROMPT_COMMAND##*[![:space:];]}"}
		PROMPT_COMMAND="_prompt_save_status; ${_prompt_pc:+$_prompt_pc; }_prompt_command"
		unset _prompt_pc ;;
esac
