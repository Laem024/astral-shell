source /usr/share/cachyos-fish-config/cachyos-config.fish

# Astral palette. The active mode is the universal variable astral_mode.
# Switch with: astral_mode dark  |  astral_mode light
function astral_mode --description "Set the Astral dark or light fish palette"
    switch "$argv[1]"
        case dark
            set -U fish_color_normal E7ECE9
            set -U fish_color_command 7FD0BF
            set -U fish_color_keyword A9B5D9
            set -U fish_color_quote E5B873
            set -U fish_color_redirection A9B5D9
            set -U fish_color_end E5B873
            set -U fish_color_error F08C7B
            set -U fish_color_param E7ECE9
            set -U fish_color_comment 8D9994
            set -U fish_color_selection --background=171C1F
            set -U fish_color_search_match --background=171C1F
            set -U fish_color_operator 7FD0BF
            set -U fish_color_escape 7FD0BF
            set -U fish_color_autosuggestion 8D9994
            set -U fish_color_cwd 7FD0BF
            set -U fish_color_cwd_root F08C7B
            set -U fish_color_user 7FD0BF
            set -U fish_color_host A9B5D9
            set -U fish_color_host_remote E5B873
            set -U fish_color_cancel F08C7B
            set -U fish_pager_color_progress 8D9994
            set -U fish_pager_color_prefix 7FD0BF
            set -U fish_pager_color_completion E7ECE9
            set -U fish_pager_color_description 8D9994
            set -U fish_pager_color_selected_background --background=171C1F
            set -U fish_pager_color_selected_prefix 7FD0BF
            set -U fish_pager_color_selected_completion E7ECE9
            set -U fish_pager_color_selected_description 8D9994
        case light
            set -U fish_color_normal 141B1D
            set -U fish_color_command 17675A
            set -U fish_color_keyword 3B4A7A
            set -U fish_color_quote 8A5B16
            set -U fish_color_redirection 3B4A7A
            set -U fish_color_end 8A5B16
            set -U fish_color_error A9361F
            set -U fish_color_param 141B1D
            set -U fish_color_comment 5A6764
            set -U fish_color_selection --background=FBFCFA
            set -U fish_color_search_match --background=FBFCFA
            set -U fish_color_operator 17675A
            set -U fish_color_escape 17675A
            set -U fish_color_autosuggestion 5A6764
            set -U fish_color_cwd 17675A
            set -U fish_color_cwd_root A9361F
            set -U fish_color_user 17675A
            set -U fish_color_host 3B4A7A
            set -U fish_color_host_remote 8A5B16
            set -U fish_color_cancel A9361F
            set -U fish_pager_color_progress 5A6764
            set -U fish_pager_color_prefix 17675A
            set -U fish_pager_color_completion 141B1D
            set -U fish_pager_color_description 5A6764
            set -U fish_pager_color_selected_background --background=FBFCFA
            set -U fish_pager_color_selected_prefix 17675A
            set -U fish_pager_color_selected_completion 141B1D
            set -U fish_pager_color_selected_description 5A6764
        case '*'
            echo "usage: astral_mode dark|light" >&2
            return 2
    end
    set -U astral_mode "$argv[1]"
end

set -q astral_mode; or astral_mode dark

function fish_prompt
    set -l last_status $status
    set_color $fish_color_cwd
    echo -n (prompt_pwd)
    if test $last_status -eq 0
        set_color $fish_color_command
    else
        set_color $fish_color_error
    end
    echo -n ' ❯ '
    set_color normal
end

function fish_greeting
    set_color $fish_color_comment
    echo "astral · "(date '+%a %d %b %H:%M')
    set_color normal
end

function clear
    command clear
    printf '\e[3J'
end

function fish_user_key_bindings
    bind \cl 'printf "\e[3J\e[H\e[2J"'
end
