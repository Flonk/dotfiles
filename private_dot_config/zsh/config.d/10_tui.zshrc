_COLUMNS_COMMAND="git column --mode="column,dense" --padding=3"
alias columns="$_COLUMNS_COMMAND"

get_terminal_size_scaled() {
    local rows cols scaled_rows
    rows=$(tput lines)
    cols=$(tput cols)
    scaled_rows=$(qalc -t "floor($rows * 3)")
    echo "$scaled_rows $cols"
}

breakpoints() {
    local scaled_rows cols size
    read -r scaled_rows cols <<< "$(get_terminal_size_scaled)"
    size=$(echo "$scaled_rows * $cols" | bc)

    if (( $(echo "$size > 65536" | bc -l) )); then
        echo "xl"
    elif (( $(echo "$size > 32768" | bc -l) )); then
        echo "lg"
    elif (( $(echo "$size > 16384" | bc -l) )); then
        echo "md"
    elif (( $(echo "$size > 8192" | bc -l) )); then
        echo "sm"
    else
        echo "xs"
    fi
}

aspect_ratio() {
    local scaled_rows cols aspect_ratio
    read -r scaled_rows cols <<< "$(get_terminal_size_scaled)"

    if (( $(echo "$scaled_rows > $cols" | bc -l) )); then
        echo "portrait"
    else
        echo "landscape"
    fi
}

if_is_landscape() {
    local cols=$(tput cols)
    local rows=$(tput lines)
    local aspect_ratio=$(echo "scale=2; $cols / $rows" | bc -l)

    if (( $(echo "$aspect_ratio > 1" | bc -l) )); then
        echo "$1"
    else
        echo "$2"
    fi
}

get_terminal_info() {
    local scaled_rows cols breakpoint aspect simple_aspect
    read -r scaled_rows cols <<< "$(get_terminal_size_scaled)"
    breakpoint=$(breakpoints)
    aspect=$(aspect_ratio)
    echo "${cols}x$(tput lines) $breakpoint $aspect"
}

