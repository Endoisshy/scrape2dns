#!/bin/bash

domain="domain.local" # add your domain here
base_url="https://domain.loal/index.html" # add your base url
wordlist="wordlist.txt"
wildcard_ip=""
output_all="all_subdomains.txt"
output_valid="valid_subdomains.txt"
txt_dump="dns_txt_records.txt"

echo "[*] Fetching $base_url and building wordlist..."
echo $base_url

curl -s $base_url | \
tr '[:space:]' '\n' | \
sed 's/[^a-zA-Z0-9]//g' | \
grep -E '^[a-zA-Z0-9]+$' | \
tr '[:upper:]' '[:lower:]' | \
grep -E '^.{1,15}$' | \ # can be changed to whatever max length you'd like for the subdomain string
sort -u > wordlist.txt

echo "[*] Wordlist created with $(wc -l < "$wordlist") words."

echo "[*] Detecting wildcard DNS behavior..."

# Checks for wildcarded domain

wildcard_ip=$(host fake123xyz.$domain | awk '/has address/ {print $NF}')

if [[ -n "$wildcard_ip" ]]; then
    echo "[!] Wildcard DNS detected: all non-existent subdomains resolve to $wildcard_ip"
else
    echo "[+] No wildcard detected. Proceeding normally."
fi

echo "[*] Enumerating and resolving subdomains..."

while read word; do
    fqdn="$word.$domain"
    ip=$(host "$fqdn" | awk '/has address/ {print $NF}')
    if [[ -n "$ip" ]]; then
        echo "$fqdn has address $ip" >> "$output_all"
        if [[ "$ip" != "$wildcard_ip" ]]; then
            echo "$fqdn has address $ip" | tee -a "$output_valid"
        fi
    fi
done < "$wordlist"

echo "[*] $(wc -l < "$output_valid") valid subdomains found (non-wildcard)."


# This section can be adjusted to do whatever you'd like after gathering your valid subdomains

echo "[*] Dumping DNS TXT records..."
> "$txt_dump"
cut -d' ' -f1 "$output_valid" | while read fqdn; do
    echo "[+] $fqdn" | tee -a "$txt_dump"
    dig +short TXT "$fqdn" | tee -a "$txt_dump" # Change command here
    echo | tee -a "$txt_dump"
done

echo "[*] Done. Results:"
echo "  Wordlist ............... $wordlist"
echo "  All resolved subdomains $output_all"
echo "  Valid subdomains ....... $output_valid"
echo "  DNS TXT records ........ $txt_dump"
