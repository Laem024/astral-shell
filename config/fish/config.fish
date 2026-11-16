source /usr/share/cachyos-fish-config/cachyos-config.fish

fish_add_path /home/laem024/.opencode/bin

function clear
    command clear
    printf '\e[3J'
end

function fish_user_key_bindings
    bind \cl 'printf "\e[3J\e[H\e[2J"'
end