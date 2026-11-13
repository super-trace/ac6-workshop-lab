#!/usr/bin/env bash
# Goal check for the Grafana exercise (README Scenario 4): some dashboard in
# Grafana shows both devices' metrics and their logs. Every panel query is run
# for real: Prometheus queries (with Grafana's $__ macros and any dashboard
# variables filled in) must return series for both nokia and sonic, and at
# least one Loki query must return lines. The lab provisions no dashboards,
# so any dashboard that passes is one the attendee had built.
set -euo pipefail

grafana="http://localhost:3000"
prometheus="http://127.0.0.1:9090"
loki="http://127.0.0.1:3100"
failed=0
fail() { printf '\033[1;31m!! %s\033[0m\n' "$*" >&2; failed=1; }
heading() { printf '\033[1;36m== %s ==\033[0m\n' "$*"; }
api() { curl -fsS --max-time 10 -u oldprotocol:newbrain "${grafana}/api/$1"; }

if ! api health >/dev/null 2>&1; then
    fail "Grafana is not answering on ${grafana}; run 'just grafana-up'"
    ./scripts/banner.sh red "GRAFANA NOT CHECKED"
    exit 1
fi

# fill EXPR: EXPR with Grafana's macros and dashboard variables replaced, so
# Prometheus and Loki can run it as is. A variable matches every value.
fill() {
    sed -E \
        -e 's/\$\{?__(rate_interval|interval|range|auto)(_ms|_s)?\}?/2m/g' \
        -e 's/([a-z_]+) *=~? *"\$\{?[A-Za-z0-9_]+(:[a-z]+)?\}?"/\1=~".+"/g' \
        -e 's/\$\{?[A-Za-z0-9_]+(:[a-z]+)?\}?/.+/g' <<<"$1"
}

# prom_devices EXPR: the devices EXPR returns series for, one per line.
prom_devices() {
    curl -sS --max-time 10 -G "${prometheus}/api/v1/query" --data-urlencode "query=$1" 2>/dev/null |
        jq -r '.data.result[]?.metric.device // empty' 2>/dev/null | sort -u
}

# loki_lines EXPR: how many lines or series EXPR returns over the last hour.
loki_lines() {
    local start
    start="$(( $(date +%s) - 3600 ))000000000"
    curl -sS --max-time 10 -G "${loki}/loki/api/v1/query_range" \
        --data-urlencode "query=$1" --data-urlencode "start=${start}" --data-urlencode "limit=10" 2>/dev/null |
        jq -r '[.data.result[]? | (.values // []) | length] | add // 0' 2>/dev/null || echo 0
}

uids="$(api 'search?type=dash-db&limit=100' | jq -r '.[].uid')"
if [ -z "$uids" ]; then
    fail "Grafana has no dashboards yet: build one (Scenario 4)"
fi

passed=""
for uid in $uids; do
    dash="$(api "dashboards/uid/${uid}")"
    title="$(jq -r '.dashboard.title' <<<"$dash")"
    heading "Dashboard \"${title}\""
    # Every query target, with the datasource type that runs it: the
    # target's own datasource, else its panel's (rows nest panels), else the
    # default, Prometheus. "-- Mixed --" panels name it per target.
    targets="$(jq -c '
        [.dashboard.panels[]? | ., (.panels[]?)] | .[] |
        .datasource as $pds | .targets[]? | select(.expr != null and .expr != "") |
        {expr, ds: ((.datasource // $pds) | if type == "object" then (.type // .uid // "") else (. // "") end)}' <<<"$dash")"
    devices="" logs=0
    while IFS= read -r t; do
        [ -n "$t" ] || continue
        expr="$(fill "$(jq -r .expr <<<"$t")")"
        ds="$(jq -r .ds <<<"$t" | tr '[:upper:]' '[:lower:]')"
        if [[ "$ds" == *loki* ]]; then
            n="$(loki_lines "$expr")"
            printf '   logs     %-6s %s\n' "$n" "$expr"
            (( n > 0 )) && logs=1
        else
            got="$(prom_devices "$expr" | tr '\n' ' ')"
            printf '   metrics  %-14s %s\n' "${got:-none}" "$expr"
            devices+=" ${got}"
        fi
    done <<<"$targets"
    ok=1
    [[ " $devices " == *" nokia "* ]] || { echo "   no panel shows nokia's metrics"; ok=0; }
    [[ " $devices " == *" sonic "* ]] || { echo "   no panel shows sonic's metrics"; ok=0; }
    (( logs )) || { echo "   no panel shows logs"; ok=0; }
    (( ok )) && passed="$title"
    echo
done

if [ -z "$passed" ] && [ -n "$uids" ]; then
    fail "no dashboard shows metrics from both nokia and sonic and their logs"
fi
if (( failed )); then ./scripts/banner.sh red "NO GRAFANA DASHBOARD YET"; exit 1; fi
echo "   \"${passed}\" shows both devices' metrics and their logs."
./scripts/banner.sh green "GRAFANA DASHBOARD BUILT"
