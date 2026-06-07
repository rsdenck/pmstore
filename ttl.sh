#!/usr/bin/env bash
# rsdenck
# NUNCA USAR O IP: 192.168.130.200 (HOST) usar: ttl.sh para consultar ips disponíveis
REDE="192.168.130"

printf "\n%-15s %-8s %-20s\n" "IP" "TTL" "Possível SO"
printf "%-15s %-8s %-20s\n" "---------------" "--------" "--------------------"

for i in $(seq 1 254); do
(
    IP="${REDE}.${i}"

    TTL=$(ping -c 3 -W 1 "$IP" 2>/dev/null \
        | awk -F'ttl=' '/ttl=/{split($2,a," ");sum+=a[1];n++} END{if(n) print int(sum/n)}')

    if [[ -n "$TTL" ]]; then

        if (( TTL <= 64 )); then
            SO="Linux/Unix/LXC"
        elif (( TTL <= 128 )); then
            SO="Windows"
        elif (( TTL <= 255 )); then
            SO="Network Device"
        else
            SO="Desconhecido"
        fi

        printf "%-15s %-8s %-20s\n" "$IP" "$TTL" "$SO"
    fi
) &
done

wait

echo
echo "Varredura concluída."


