#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 0 ]; then
    echo "Использование: $0" >&2
    exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log_file="$script_dir/access.log"

# Детерминированная генерация ровно 300 строк access.log
{
    for (( i = 1; i <= 300; i++ )); do
        if (( i <= 120 )); then
            ip="192.168.1.10"
        elif (( i <= 210 )); then
            ip="10.0.0.5"
        elif (( i <= 270 )); then
            ip="172.16.0.3"
        else
            ip="192.168.1.20"
        fi

        rem=$(( i % 10 ))
        case "$rem" in
            7) status=401 ;;
            8) status=404 ;;
            9) status=500 ;;
            *) status=200 ;;
        esac

        if (( i % 2 == 0 )); then
            method="GET"
            path="/api/users"
        else
            method="POST"
            path="/api/login"
        fi

        sec=$(( i % 60 ))
        printf '%s - - [15/Aug/2026:10:15:%02d] "%s %s HTTP/1.1" %d\n' \
            "$ip" "$sec" "$method" "$path" "$status"
    done
} > "$log_file"

if [ ! -f "$log_file" ] || [ ! -s "$log_file" ]; then
    echo "Ошибка: не удалось сформировать $log_file" >&2
    exit 1
fi

# Подсчёт общего числа запросов, а также кодов 4xx и 5xx через awk
read -r total_requests count_4xx count_5xx < <(
    awk '
    {
        total++
        if ($NF ~ /^4[0-9]{2}$/) e4++
        if ($NF ~ /^5[0-9]{2}$/) e5++
    }
    END {
        printf "%d %d %d\n", total, e4, e5
    }
    ' "$log_file"
)

# Топ-3 IP-адреса:
# 1) Регулярное выражение grep ERE проверяет валидный IPv4 в начале строки
# 2) sed извлекает первый столбец (IP)
# 3) sort | uniq -c группирует и подсчитывает вхождения
# 4) sort -k1,1nr -k2,2 сортирует по убыванию частоты
# 5) head -n 3 отбирает тройку лидеров
# 6) awk форматирует строку как "IP: число запросов"
octet="(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])"
ip_regex="^${octet}\.${octet}\.${octet}\.${octet} "

top_ips=$(
    grep -E "$ip_regex" "$log_file" \
    | sed -E 's/ .*//' \
    | sort \
    | uniq -c \
    | sort -k1,1nr -k2,2 \
    | head -n 3 \
    | awk '{print $2 ": " $1 " запросов"}'
)

echo "Всего запросов: $total_requests"
echo "Топ-3 IP-адреса:"
echo "$top_ips"
echo "Запросов 4xx: $count_4xx"
echo "Запросов 5xx: $count_5xx"
