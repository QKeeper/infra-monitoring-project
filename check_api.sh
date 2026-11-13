#!/usr/bin/env bash
set -u

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
    echo "Использование: $0 URL" >&2
    exit 1
fi

url="$1"

case "$url" in
    http://*|https://*)
        ;;
    *)
        echo "Ошибка: поддерживаются только протоколы http:// и https://" >&2
        echo "Использование: $0 URL" >&2
        exit 1
        ;;
esac

# Выполняем GET-запрос через curl:
# --silent --show-error : подавляем прогресс-бар, сохраняем диагностику ошибок в stderr
# --output /dev/null    : не выводим тело ответа
# --write-out '%{http_code}' : выводим только числовой HTTP-код
# --noproxy 'localhost,127.0.0.1,::1' : исключаем перехват локальных адресов внешним прокси
# --connect-timeout 5 --max-time 15   : защитные таймауты
http_code=$(curl --silent --show-error \
    --output /dev/null \
    --write-out '%{http_code}' \
    --connect-timeout 5 \
    --max-time 15 \
    --proto '=http,https' \
    --noproxy 'localhost,127.0.0.1,::1' \
    -- "$url")
curl_exit=$?

if [ "$curl_exit" -ne 0 ]; then
    echo "API недоступен, код ответа: 000"
    exit 1
fi

if [ "$http_code" = "200" ]; then
    echo "API доступен"
    exit 0
else
    echo "API недоступен, код ответа: $http_code"
    exit 1
fi
