#!/usr/bin/env zsh

history-search-multi-word () {
	[[ "$__HSMW_MH_SOURCED" != "1" ]] && source "$HSMW_REPO_DIR/hsmw-highlight"
	local right_brace_is_recognised_everywhere
	integer path_dirs_was_set multi_func_def ointeractive_comments
	-hsmw-highlight-fill-option-variables
	emulate -LR zsh
	setopt typesetsilent extendedglob noshortloops localtraps promptsubst
	zmodload zsh/terminfo 2> /dev/null
	zmodload zsh/termcap 2> /dev/null
	typeset -g __hsmw_hcw_index
	typeset -g __hsmw_hcw_widget_name __hsmw_hcw_restart __hsmw_hcw_call_count
	typeset -g __hsmw_page_size __hsmw_hl_color __hsmw_synhl __hsmw_active __hsmw_no_check_paths
	typeset -ga __hsmw_disp_list __hsmw_disp_list_newlines __hsmw_region_highlight_data
	typeset -gi __hsmw_page_start_idx __hsmw_prev_offset __hsmw_recedit_trap_executed
	typeset -ga __hsmw_hcw_found
	typeset -gi __hsmw_ctx __hsmw_ctx_idx __hsmw_ctx_prev_idx __hsmw_ctx_text_idx __hsmw_ctx_which
	typeset -gi __hsmw_ctx_page_start_idx __hsmw_ctx_prev_offset
	typeset -g __hsmw_ctx_to_search
	typeset -ga __hsmw_ctx_disp_list
	typeset -gaU __hsmw_ctx_found
	(( __hsmw_hcw_call_count ++ ))
	trap '(( __hsmw_hcw_call_count -- )); return 0;' INT
	if (( ${+functions[_hsmw_main]} == 0 ))
	then
		_hsmw_main () {
			if [[ "$__hsmw_hcw_call_count" -le 1 || "$__hsmw_hcw_restart" = "1" ]]
			then
				if [[ "$__hsmw_hcw_call_count" -le 1 ]]
				then
					zstyle -s ':history-search-multi-word' page-size __hsmw_page_size || __hsmw_page_size=$(( LINES / 3 )) 
					zstyle -s ':history-search-multi-word' highlight-color __hsmw_hl_color || __hsmw_hl_color="fg=yellow,bold" 
					zstyle -T ":plugin:history-search-multi-word" synhl && __hsmw_synhl=1  || __hsmw_synhl=0 
					zstyle -s ":plugin:history-search-multi-word" active __hsmw_active || __hsmw_active="underline" 
					zstyle -T ":plugin:history-search-multi-word" check-paths && __hsmw_no_check_paths=0  || __hsmw_no_check_paths=1 
					-hsmw-highlight-init
				fi
				[[ "$NO_MOVE" != 1 ]] && {
					[[ "$WIDGET" = *-word || "$WIDGET" = *-pforwards ]] && __hsmw_hcw_index="1" 
					[[ "$WIDGET" = *-backwards || "$WIDGET" = *-pbackwards ]] && __hsmw_hcw_index="0" 
				}
				__hsmw_hcw_widget_name="${${${WIDGET%-backwards}%-pbackwards}%-pforwards}" 
				__hsmw_hcw_found=() 
				__hsmw_hcw_finished="0" 
				__hsmw_hcw_restart="0" 
				__hsmw_page_start_idx=0 
				__hsmw_prev_offset=0 
				(( __hsmw_ctx )) && (( ${+functions[_hsmw_ctx_off]} )) && _hsmw_ctx_off 0
			else
				if (( __hsmw_ctx ))
				then
					hsmw-context-main
					return
				fi
				[[ "$NO_MOVE" != 1 ]] && {
					[[ "$WIDGET" = *-word ]] && (( __hsmw_hcw_index ++ ))
					[[ "$WIDGET" = *-backwards ]] && (( __hsmw_hcw_index -- ))
					[[ "$WIDGET" = *-pforwards ]] && (( __hsmw_hcw_index = __hsmw_hcw_index + __hsmw_page_size ))
					[[ "$WIDGET" = *-pbackwards ]] && (( __hsmw_hcw_index = __hsmw_hcw_index - __hsmw_page_size ))
				}
			fi
			local search_buffer="${BUFFER%% ##}" search_pattern="" colsearch_pattern="" nl=$'\n' MATCH MBEGIN MEND 
			local specch="][*?|#~^()><\\" 
			search_buffer="${search_buffer//(#b)((\[?##\])|([$specch]))/${${match[2]:+$match[2]}:-\\${match[3]}}}" 
			search_buffer="${search_buffer/(#s)\\\^/(#s)}" 
			search_buffer="${search_buffer/\$(#e)/(#e)}" 
			search_buffer="${search_buffer##[ ]##}" 
			search_pattern="${search_buffer// ##/*~^*}" 
			colsearch_pattern="${search_buffer// ##/|}" 
			if [[ "${#__hsmw_hcw_found[@]}" -eq "0" ]]
			then
				repeat 1
				do
					if [[ "$search_pattern" != *[A-Z]* ]]
					then
						[[ -z "$search_pattern" ]] && __hsmw_hcw_found=(${(u@)history})  || __hsmw_hcw_found=("${(u@)history[(R)(#i)*$~search_pattern*]}") 
					else
						__hsmw_hcw_found=("${(u@)history[(R)*$~search_pattern*]}") 
					fi
				done
			fi
			integer max_index="${#__hsmw_hcw_found[@]}" 
			if [[ "$max_index" -le "0" ]]
			then
				POSTDISPLAY=$'\n'"No matches found" 
				return 0
			fi
			integer page_size="$__hsmw_page_size" 
			[[ "$page_size" -gt "$max_index" ]] && page_size="$max_index" 
			[[ "$__hsmw_hcw_index" -le 0 ]] && __hsmw_hcw_index="$max_index" 
			[[ "$__hsmw_hcw_index" -gt "$max_index" ]] && __hsmw_hcw_index=1 
			integer page_start_idx=$(( ((__hsmw_hcw_index-1)/page_size)*page_size+1 )) 
			integer on_page_idx=$(( (__hsmw_hcw_index-1) % page_size + 1 )) 
			(( page_start_idx != __hsmw_page_start_idx )) && {
				__hsmw_disp_list=("${(@)__hsmw_hcw_found[page_start_idx,page_start_idx+page_size-1]}") 
				__hsmw_disp_list_newlines=($__hsmw_disp_list) 
				__hsmw_disp_list=("${(@)__hsmw_disp_list//$'\n'/\\n}") 
				__hsmw_disp_list=("${(@)__hsmw_disp_list/(#m)*/  ${MATCH[1,COLUMNS-8]}}") 
				__hsmw_disp_list_newlines=("${(@)__hsmw_disp_list_newlines//$'\n'/ $nl}") 
				__hsmw_disp_list_newlines=("${(@)__hsmw_disp_list_newlines/(#m)*/  ${MATCH[1,COLUMNS-8]}}") 
			}
			local txt_before="${(F)${(@)__hsmw_disp_list[1,on_page_idx-1]}}" 
			local entry="${__hsmw_disp_list[on_page_idx]}" 
			local text="${(F)__hsmw_disp_list}" 
			integer replace_idx=${#txt_before}+2 
			(( replace_idx == 2 )) && replace_idx=1 
			text[replace_idx]=">" 
			local preamble=$'\n'"Ctrl-K – context, Ctrl-J – bump. Entry #$__hsmw_hcw_index of $max_index"$'\n' 
			integer offset=${#preamble}+${#BUFFER} 
			POSTDISPLAY="$preamble$text" 
			if (( page_start_idx != __hsmw_page_start_idx || offset != __hsmw_prev_offset ))
			then
				region_highlight=() 
				if (( __hsmw_synhl ))
				then
					integer pre_index=$offset 
					local line
					for line in "${__hsmw_disp_list_newlines[@]}"
					do
						reply=() 
						-hsmw-highlight-process "$line" "$pre_index"
						region_highlight+=($reply) 
						pre_index+=${#line}+1 
					done
				fi
				if [[ -n "$colsearch_pattern" ]]
				then
					__hsmw_region_highlight_data=() 
					: "${text//(#mi)(${~colsearch_pattern})/$(( hsmw_append(MBEGIN,MEND) ))}"
					region_highlight+=($__hsmw_region_highlight_data) 
				fi
			else
				region_highlight[-1]=() 
			fi
			__hsmw_page_start_idx=page_start_idx 
			__hsmw_prev_offset=offset 
			region_highlight+=("$(( offset + ${#txt_before} )) $(( offset + ${#txt_before} + ${#entry} + 1 )) $__hsmw_active") 
		}
		_hsmw_shappend () {
			__hsmw_region_highlight_data+=("$(( offset + $1 - 1 )) $(( offset + $2 )) ${__hsmw_hl_color}") 
		}
		functions -M hsmw_append 2 2 _hsmw_shappend
	fi
	_hsmw_main
	_hsmw_simulate_widget () {
		(( __hsmw_hcw_call_count ++ ))
		_hsmw_main
	}
	_hsmw_self_insert () {
		LBUFFER+="${KEYS[-1]}" 
		__hsmw_hcw_restart="1" 
		_hsmw_simulate_widget
	}
	_hsmw_backward_delete_char () {
		LBUFFER="${LBUFFER%?}" 
		__hsmw_hcw_restart="1" 
		_hsmw_simulate_widget
	}
	_hsmw_delete_char () {
		RBUFFER="${RBUFFER#?}" 
		__hsmw_hcw_restart="1" 
		_hsmw_simulate_widget
	}
	_hsmw_cancel_accept () {
		(( __hsmw_conc )) && BUFFER="" 
		unset __hsmw_conc
		__hsmw_hcw_index=-1 
		zle .accept-line
	}
	_hsmw_backward_kill_word () {
		zle .backward-kill-word
		__hsmw_hcw_restart="1" 
		_hsmw_simulate_widget
	}
	_hsmw_reset_prompt () {
		zle .reset-prompt
		local NO_MOVE=1 
		_hsmw_simulate_widget
	}
	_hsmw_jump_entry () {
		local entry
		if (( __hsmw_ctx ))
		then
			integer final_hist_found_idx the_index
			final_hist_found_idx=__hsmw_ctx_text_idx+__hsmw_ctx_which-1 
			the_index="${__hsmw_ctx_found[final_hist_found_idx]}" 
			the_index+=__hsmw_ctx_idx 
			entry="${history[$the_index]}" 
		else
			entry="${__hsmw_hcw_found[__hsmw_hcw_index]}" 
		fi
		print -S "$entry"
	}
	if [[ "$__hsmw_hcw_call_count" -eq "1" ]]
	then
		local __hsmw_reset_prompt_protect
		zstyle -t ":plugin:history-search-multi-word" reset-prompt-protect && __hsmw_reset_prompt_protect=1  || __hsmw_reset_prompt_protect=0 
		bindkey -N hsmw emacs
		local down_widget="${${${WIDGET%-backwards}%-pbackwards}%-pforwards}" 
		local up_widget="${down_widget}-backwards" 
		local pdown_widget="${down_widget}-pforwards" 
		local pup_widget="${down_widget}-pbackwards" 
		bindkey -M hsmw '^[OA' "$up_widget"
		bindkey -M hsmw '^[OB' "$down_widget"
		bindkey -M hsmw '^[[A' "$up_widget"
		bindkey -M hsmw '^[[B' "$down_widget"
		[[ -n "$termcap[ku]" ]] && bindkey -M hsmw "$termcap[ku]" "$up_widget"
		[[ -n "$termcap[kd]" ]] && bindkey -M hsmw "$termcap[kd]" "$down_widget"
		[[ -n "$termcap[kD]" ]] && bindkey -M hsmw "$termcap[kD]" .delete-char
		[[ -n "$terminfo[kcuu1]" ]] && bindkey -M hsmw "$terminfo[kcuu1]" "$up_widget"
		[[ -n "$terminfo[kcud1]" ]] && bindkey -M hsmw "$terminfo[kcud1]" "$down_widget"
		[[ -n "$terminfo[kdch1]" ]] && bindkey -M hsmw "$terminfo[kdch1]" .delete-char
		bindkey -M hsmw '^[[D' .backward-char
		bindkey -M hsmw '^[[C' .forward-char
		[[ -n "$termcap[kl]" ]] && bindkey -M hsmw "$termcap[kl]" .backward-char
		[[ -n "$termcap[kr]" ]] && bindkey -M hsmw "$termcap[kr]" .forward-char
		[[ -n "$terminfo[kcub1]" ]] && bindkey -M hsmw "$terminfo[kcub1]" .backward-char
		[[ -n "$terminfo[kcuf1]" ]] && bindkey -M hsmw "$terminfo[kcuf1]" .forward-char
		bindkey -M hsmw "\e[1~" .beginning-of-line
		bindkey -M hsmw "\e[7~" .beginning-of-line
		bindkey -M hsmw "\e[H" .beginning-of-line
		bindkey -M hsmw "\e[4~" .end-of-line
		bindkey -M hsmw "\e[F" .end-of-line
		bindkey -M hsmw "\e[8~" .end-of-line
		[[ -n "$termcap[kh]" ]] && bindkey -M hsmw "$termcap[kh]" .beginning-of-line
		[[ -n "$termcap[@7]" ]] && bindkey -M hsmw "$termcap[@7]" .end-of-line
		[[ -n "$terminfo[khome]" ]] && bindkey -M hsmw "$terminfo[khome]" .beginning-of-line
		[[ -n "$terminfo[kend]" ]] && bindkey -M hsmw "$terminfo[kend]" .end-of-line
		bindkey -M hsmw '^A' .beginning-of-line
		bindkey -M hsmw '^E' .end-of-line
		bindkey -M hsmw '^[b' .backward-word
		bindkey -M hsmw '^[B' .backward-word
		bindkey -M hsmw '^[f' .forward-word
		bindkey -M hsmw '^[F' .forward-word
		bindkey -M hsmw '^[w' .forward-word
		bindkey -M hsmw '^[W' .forward-word
		bindkey -M hsmw '^U' .kill-whole-line
		zle -N _hsmw_backward_kill_word
		bindkey -M hsmw '^W' _hsmw_backward_kill_word
		bindkey -M hsmw '^P' "$up_widget"
		bindkey -M hsmw '^N' "$down_widget"
		bindkey -M hsmw '^L' "$down_widget"
		[[ -n "$termcap[kP]" ]] && bindkey -M hsmw "$termcap[kP]" "$pup_widget"
		[[ -n "$termcap[kN]" ]] && bindkey -M hsmw "$termcap[kN]" "$pdown_widget"
		[[ -n "$terminfo[kpp]" ]] && bindkey -M hsmw "$terminfo[kpp]" "$pup_widget"
		[[ -n "$terminfo[knp]" ]] && bindkey -M hsmw "$terminfo[knp]" "$pdown_widget"
		zle -N -- hsmw-context-main
		bindkey -M hsmw '^K' hsmw-context-main
		bindkey -M hsmw ' ' self-insert
		bindkey -M hsmw '^R' "$down_widget"
		zle -N -- _hsmw_jump_entry
		bindkey -M hsmw '^J' _hsmw_jump_entry
		zle -A self-insert hsmw-saved-self-insert
		zle -N self-insert _hsmw_self_insert
		zle -A backward-delete-char hsmw-saved-backward-delete-char
		zle -N backward-delete-char _hsmw_backward_delete_char
		zle -A delete-char hsmw-saved-delete-char
		zle -N delete-char _hsmw_delete_char
		(( __hsmw_reset_prompt_protect )) && zle -A reset-prompt hsmw-saved-reset-prompt
		(( __hsmw_reset_prompt_protect )) && zle -N reset-prompt _hsmw_reset_prompt
		if (( ${+functions[azhw:zle-line-pre-redraw]} ))
		then
			functions[zle-line-pre-redraw-bkp]=${functions[azhw:zle-line-pre-redraw]} 
			functions[azhw:zle-line-pre-redraw]=":" 
		fi
		if (( ${+functions[azhw:zle-line-finish]} ))
		then
			functions[zle-line-finish-bkp]=${functions[azhw:zle-line-finish]} 
			functions[azhw:zle-line-finish]=":" 
		fi
		zle -la zle-keymap-select && {
			zle -A zle-keymap-select hsmw-saved-zle-keymap-select
			zle -D zle-keymap-select
		}
		zle -la zle-line-pre-redraw && {
			zle -A zle-line-pre-redraw hsmw-saved-zle-line-pre-redraw
			zle -D zle-line-pre-redraw
		}
		zle -A "$down_widget" hsmw-saved-"$down_widget"
		zle -A "$up_widget" hsmw-saved-"$up_widget"
		zle -N "$down_widget" _hsmw_simulate_widget
		zle -N "$up_widget" _hsmw_simulate_widget
		zle -A "$pdown_widget" hsmw-saved-"$pdown_widget"
		zle -A "$pup_widget" hsmw-saved-"$pup_widget"
		zle -N "$pdown_widget" _hsmw_simulate_widget
		zle -N "$pup_widget" _hsmw_simulate_widget
		zle -N _hsmw_cancel_accept
		bindkey -M hsmw "^V" _hsmw_cancel_accept
		bindkey -M hsmw "^[" _hsmw_cancel_accept
		local __hsmw_conc
		zstyle -t ":plugin:history-search-multi-word" clear-on-cancel && __hsmw_conc=1  || __hsmw_conc=0 
		__hsmw_recedit_trap_executed=0 
		trap '(( __hsmw_recedit_trap_executed == 0 )) && zle && { __hsmw_recedit_trap_executed=1; zle .send-break; }' INT
		if zle .recursive-edit -K hsmw
		then
			trap '' INT
			if [[ "$__hsmw_hcw_index" -gt "0" ]]
			then
				if (( __hsmw_ctx ))
				then
					integer final_hist_found_idx the_index
					final_hist_found_idx=__hsmw_ctx_text_idx+__hsmw_ctx_which-1 
					the_index="${__hsmw_ctx_found[final_hist_found_idx]}" 
					the_index+=__hsmw_ctx_idx 
					BUFFER="${history[$the_index]}" 
				else
					BUFFER="${__hsmw_hcw_found[__hsmw_hcw_index]}" 
				fi
				CURSOR="${#BUFFER}" 
			else
				(( __hsmw_conc )) && BUFFER="" 
				unset __hsmw_conc
			fi
		else
			trap '' INT
			(( __hsmw_conc )) && BUFFER="" 
			unset __hsmw_conc
		fi
		POSTDISPLAY="" 
		(( ${+functions[_hsmw_ctx_off]} )) && _hsmw_ctx_off 0
		zle -A hsmw-saved-self-insert self-insert
		zle -A hsmw-saved-backward-delete-char backward-delete-char
		zle -A hsmw-saved-delete-char delete-char
		(( __hsmw_reset_prompt_protect )) && zle -A hsmw-saved-reset-prompt reset-prompt
		zle -D hsmw-saved-self-insert hsmw-saved-backward-delete-char hsmw-saved-delete-char
		(( __hsmw_reset_prompt_protect )) && zle -D hsmw-saved-reset-prompt
		zle -la hsmw-saved-zle-keymap-select && {
			zle -A hsmw-saved-zle-keymap-select zle-keymap-select
			zle -D hsmw-saved-zle-keymap-select
		}
		zle -la zle-line-pre-redraw && {
			zle -A hsmw-saved-zle-line-pre-redraw zle-line-pre-redraw
			zle -D hsmw-saved-zle-line-pre-redraw
		}
		zle -A hsmw-saved-"$down_widget" "$down_widget"
		zle -A hsmw-saved-"$up_widget" "$up_widget"
		zle -D hsmw-saved-"$down_widget" hsmw-saved-"$up_widget"
		zle -A hsmw-saved-"$pdown_widget" "$pdown_widget"
		zle -A hsmw-saved-"$pup_widget" "$pup_widget"
		zle -D hsmw-saved-"$pdown_widget" hsmw-saved-"$pup_widget"
		if (( ${+functions[azhw:zle-line-pre-redraw]} ))
		then
			functions[azhw:zle-line-pre-redraw]=${functions[zle-line-pre-redraw-bkp]} 
		fi
		if (( ${+functions[azhw:zle-line-finish]} ))
		then
			functions[azhw:zle-line-finish]=${functions[zle-line-finish-bkp]} 
		fi
		__hsmw_hcw_call_count="0" 
		zle reset-prompt
	elif (( __hsmw_hcw_call_count > 0 ))
	then
		(( __hsmw_hcw_call_count -- ))
	fi
}