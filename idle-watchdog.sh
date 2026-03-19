#!/usr/bin/env bash
set -euo pipefail

idle_seconds=10
check_interval=1
vnc_port="${VNC_PORT:-5900}"
novnc_port="${NOVNC_WEBSOCKIFY_PORT:-6080}"

log() {
    printf '%s [browser-idle] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

port_to_hex() {
    printf '%04X\n' "$1"
}

count_established_connections_for_hex_port() {
    local port_hex="$1"
    local file
    local count=0
    local file_count

    for file in /proc/net/tcp /proc/net/tcp6; do
        [ -r "$file" ] || continue
        file_count="$(awk -v port="$port_hex" 'NR > 1 {
            split($2, local_address, ":")
            if (toupper(local_address[2]) == port && $4 == "01") {
                count++
            }
        } END {
            print count + 0
        }' "$file")"
        count=$((count + file_count))
    done

    printf '%s\n' "$count"
}

browser_processes() {
    pgrep -f 'chromium|firefox|chrome|google-chrome|edge|microsoft-edge' 2>/dev/null || true
}

browser_state_summary() {
    local summary
    local pids

    pids="$(browser_processes | tr '\n' ',' | sed 's/,$//')"
    [ -z "$pids" ] && {
        printf '%s\n' "no browser processes"
        return
    }

    summary="$(ps -o stat= -p "$pids" 2>/dev/null | awk '
        {
            counts[$1]++
            total++
        }
        END {
            if (total == 0) {
                print "no active processes"
                exit
            }

            first = 1
            for (state in counts) {
                if (!first) {
                    printf ", "
                }
                printf "%s=%d", state, counts[state]
                first = 0
            }
        }
    ')"

    printf '%s\n' "$summary"
}

vnc_port_hex="$(port_to_hex "$vnc_port")"
novnc_port_hex="$(port_to_hex "$novnc_port")"
last_active_epoch="$(date +%s)"
is_paused=0
previous_vnc_connections=-1
previous_novnc_connections=-1
last_paused_report_epoch=0

log "Watchdog starting: idle_seconds=10, check_interval=1, vnc_port=${vnc_port}, novnc_port=${novnc_port}, browser_states=$(browser_state_summary)"

while true; do
    now="$(date +%s)"
    vnc_connections="$(count_established_connections_for_hex_port "$vnc_port_hex")"
    novnc_connections="$(count_established_connections_for_hex_port "$novnc_port_hex")"
    total_connections=$((vnc_connections + novnc_connections))

    if [ "$vnc_connections" -ne "$previous_vnc_connections" ] || [ "$novnc_connections" -ne "$previous_novnc_connections" ]; then
        if [ "$total_connections" -gt 0 ]; then
            log "Connections established: vnc=${vnc_connections}, novnc=${novnc_connections}"
        elif [ "$total_connections" -eq 0 ]; then
            log "All connections closed: vnc=${vnc_connections}, novnc=${novnc_connections}"
        fi
        previous_vnc_connections="$vnc_connections"
        previous_novnc_connections="$novnc_connections"
    fi

    if [ "$total_connections" -gt 0 ]; then
        last_active_epoch="$now"
        last_idle_reported=-1
        if [ "$is_paused" -eq 1 ]; then
            log "Activity detected; resuming browsers immediately. browser_states_before=$(browser_state_summary)"
            if pkill -CONT -f 'chromium|firefox|chrome|google-chrome|edge|microsoft-edge'; then
                log "Sent SIGCONT to browsers. browser_states_after=$(browser_state_summary)"
            else
                log "No browser processes matched SIGCONT. browser_states_after=$(browser_state_summary)"
            fi
            is_paused=0
        fi
    else
        idle_for=$((now - last_active_epoch))
        if [ "$idle_for" -ge "10" ] && [ "$is_paused" -eq 0 ]; then
            log "Idle threshold reached after ${idle_for}s without connections; pausing browsers. browser_states_before=$(browser_state_summary)"
            if pkill -STOP -f 'chromium|firefox|chrome|google-chrome|edge|microsoft-edge'; then
                log "Sent SIGSTOP to browsers. browser_states_after=$(browser_state_summary)"
                sync
                log "Synced dirty pages to disk to enable memory reclamation"
            else
                log "No browser processes matched SIGSTOP. browser_states_after=$(browser_state_summary)"
            fi
            is_paused=1
            last_paused_report_epoch="$now"
        elif [ "$is_paused" -eq 1 ] && [ $((now - last_paused_report_epoch)) -ge 30 ]; then
            log "Browsers still paused; waiting for a VNC/noVNC connection. browser_states=$(browser_state_summary)"
            last_paused_report_epoch="$now"
        fi
    fi

    sleep "$check_interval"
done
