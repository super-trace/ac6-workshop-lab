#!/usr/bin/env bash
# banner.sh intro COMMAND LINE...: the green AC6 WORKSHOP LAB box that opens a
#   recipe, with COMMAND at its top right and each LINE inside it.
# banner.sh green|red TEXT: a closing box with TEXT centered, such as LAB IS UP.
# Every box is 76 columns wide, so it fits an 80-column terminal.
set -euo pipefail

inner=74
reset=$'\033[0m'
border=$'\033[32m'
title=$'\033[1;92m'
text=$'\033[92m'

# width TEXT: TEXT's length in characters, not bytes (the en dash in "2–5"
# is three bytes), whatever the locale.
width() { perl -CA -e 'print length $ARGV[0]' -- "$1"; }

# rule LEFT FILL RIGHT: a full-width border line.
rule() {
    local fill
    printf -v fill '%*s' "$inner" ''
    printf '%s\n' "${1}${fill// /$2}${3}"
}

# row LEFT_COLOR LEFT [RIGHT_COLOR RIGHT]: a line inside the intro box, LEFT
# indented three columns and RIGHT ending three columns from the edge.
row() {
    local left="$2" right="${4:-}"
    local gap=$(( inner - 6 - $(width "$left") - $(width "$right") ))
    printf '%s║%s   %s%s%s%*s%s%s%s   %s║%s\n' "$border" "$reset" \
        "$1" "$left" "$reset" "$gap" '' "${3:-}" "$right" "$reset" "$border" "$reset"
}

case "${1:-}" in
    intro)
        command="$2"
        shift 2
        rule "${border}╔" ═ "╗${reset}"
        row "" ""
        row "$title" "AC6 WORKSHOP LAB" "$text" "$command"
        rule "${border}╟" ─ "╢${reset}"
        row "" ""
        for line in "$@"; do
            row "$text" "$line"
        done
        row "" ""
        rule "${border}╚" ═ "╝${reset}"
        ;;
    green|red)
        [[ "$1" == green ]] && color=$'\033[1;32m' || color=$'\033[1;31m'
        label="$2"
        left=$(( (inner - $(width "$label")) / 2 ))
        right=$(( inner - $(width "$label") - left ))
        printf '%s' "$color"
        rule ╔ ═ ╗
        printf '║%*s║\n' "$inner" ''
        printf '║%*s%s%*s║\n' "$left" '' "$label" "$right" ''
        printf '║%*s║\n' "$inner" ''
        rule ╚ ═ ╝
        printf '%s' "$reset"
        ;;
    *)
        echo "usage: banner.sh intro COMMAND LINE... | banner.sh green|red TEXT" >&2
        exit 2
        ;;
esac
