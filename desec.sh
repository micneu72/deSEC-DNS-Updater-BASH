#!/bin/bash
: '
----------------------------------------------------------------------------
    Script Name:     desec.sh
    CreationDate:    08.02.2024
    Last Modified:   25.04.2025 14:30:46
    Copyright:       Michael N. (c)2024
    Purpose:         aktualisiert dns eintrag bei desec.io

----------------------------------------------------------------------------
'
# Standardpfad zur Konfigurationsdatei
CONFIG_FILE="./desec.config"

# Parameter verarbeiten
while getopts "c:" opt; do
  case $opt in
    c)
      CONFIG_FILE="$OPTARG"
      ;;
    \?)
      echo "Ungültige Option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Prüfen, ob die Konfigurationsdatei existiert
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Konfigurationsdatei $CONFIG_FILE nicht gefunden! Erstelle Template-Datei..."
    
    # Template-Inhalt erstellen
    cat > "$CONFIG_FILE" << 'EOF'
#!/bin/bash
# Konfigurationsdatei für desec.sh

# deSEC API Token
token="dein_desec_token_hier_eintragen"

# deSEC Domain
domain="deine.domain.hier.eintragen"

# deSEC host
subname="deine.host.hier.eintragen"
EOF
    
    chmod +x "$CONFIG_FILE"
    echo "Template-Datei $CONFIG_FILE wurde erstellt. Bitte passe die Werte an und starte das Skript erneut."
    exit 0
fi

# Konfigurationsdatei einlesen
source "$CONFIG_FILE"

# Überprüfen, ob die Werte erfolgreich eingelesen wurden
if [ -z "$token" ] || [ "$token" = "dein_desec_token_hier_eintragen" ]; then
    echo "Fehler: Token konnte nicht aus der Konfigurationsdatei gelesen werden oder wurde nicht angepasst."
    exit 1
fi

if [ -z "$domain" ] || [ "$domain" = "deine.domain.hier.eintragen" ]; then
    echo "Fehler: Domain konnte nicht aus der Konfigurationsdatei gelesen werden oder wurde nicht angepasst."
    exit 1
fi

if [ -z "$subname" ] || [ "$subname" = "deine.host.hier.eintragen" ]; then
    echo "Fehler: subname konnte nicht aus der Konfigurationsdatei gelesen werden oder wurde nicht angepasst."
    exit 1
fi

# Funktionen start

# Funktion zur Prüfung, ob der übergebene String eine IPv4- oder IPv6-Adresse ist
check_ip_address() {
    local ip="$1"

    # Regulärer Ausdruck für IPv4 (xxx.xxx.xxx.xxx, wobei xxx von 0 bis 255 sein kann)
    local ipv4_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

    # Regulärer Ausdruck für IPv6 (Standardnotation mit optionalen Abkürzungen "::")
    local ipv6_regex='^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$'

    # Überprüfung, ob der String mit dem IPv4-RegEx übereinstimmt
    if [[ $ip =~ $ipv4_regex ]]; then
        # Sicherstellen, dass die Zahlen im gültigen Bereich (0-255) liegen
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if ((octet < 0 || octet > 255)); then
                echo "Invalid IP"
                return 1
            fi
        done
        echo -e "  WAN IPv4:\t$ip"
        return 0
    fi

    # Überprüfung, ob der String mit dem IPv6-RegEx übereinstimmt
    if [[ $ip =~ $ipv6_regex ]]; then
        echo -e "  WAN IPv6:\t$ip"
        return 0
    fi

    echo "Invalid IP"
    return 1
}


# Funktion zur Auflösung eines Hostnamens in eine IPv4- und IPv6-Adresse
hostname_to_ip() {
    local domain="$1"
    local subname="$2"
    local token="$3"
    
    # IPv4 & IPv6 über api auslesen
    DNSv4data=$(curl -s -H "Authorization: Token $token" "https://desec.io/api/v1/domains/$domain/rrsets/$subname/A/")
    DNSv6data=$(curl -s -H "Authorization: Token $token" "https://desec.io/api/v1/domains/$domain/rrsets/$subname/AAAA/")

    # Trenne IPv4 und IPv6 Adressen
    deSEC_IPv4=$(echo "$DNSv4data" | grep -o '"records": *\[[^]]*\]' | sed 's/.*\["\([^"]*\)"\].*/\1/')
    deSEC_IPv6=$(echo "$DNSv6data" | sed -n 's/.*"records": *\[\s*"\([^"]*\)".*/\1/p')

    # Rückgabe der IP-Adressen
    echo -e "deSEC IPv4:\t$deSEC_IPv4\ndeSEC IPv6:\t$deSEC_IPv6"
}

# Funktion, um die übergebene Laufzeit (in Sekunden) dynamisch darzustellen
format_runtime() {
    local elapsed_time=$1

    if (( elapsed_time < 60 )); then
        echo "Laufzeit: $elapsed_time Sekunden"
    elif (( elapsed_time < 3600 )); then
        local minutes=$(( elapsed_time / 60 ))
        local seconds=$(( elapsed_time % 60 ))
        echo "Laufzeit: $minutes Minuten, $seconds Sekunden"
    elif (( elapsed_time < 86400 )); then
        local hours=$(( elapsed_time / 3600 ))
        local minutes=$(( (elapsed_time % 3600) / 60 ))
        local seconds=$(( elapsed_time % 60 ))
        echo "Laufzeit: $hours Stunden, $minutes Minuten, $seconds Sekunden"
    else
        local days=$(( elapsed_time / 86400 ))
        local hours=$(( (elapsed_time % 86400) / 3600 ))
        local minutes=$(( (elapsed_time % 3600) / 60 ))
        local seconds=$(( elapsed_time % 60 ))
        echo "Laufzeit: $days Tage, $hours Stunden, $minutes Minuten, $seconds Sekunden"
    fi
}

check_host() {
    # Originale Übergabe
    local WAN_IPv4="$1"
    local WAN_IPv6="$2"


    if [[ "$WAN_IPv4" != "$deSEC_IPv4" || "$WAN_IPv6" != "$deSEC_IPv6" ]]; then
        echo "Die IPs haben sich geändert oder eine davon. Verarbeitung starten."

        if [[ -n "$WAN_IPv4" && -n "$WAN_IPv6" ]]; then
            echo "Beide IPs sind verfügbar: IPv4 = '$WAN_IPv4', IPv6 = '$WAN_IPv6'"
            curl -s "https://update.dedyn.io/?hostname=$kodihost&myipv4=$WAN_IPv4&myipv6=$WAN_IPv6" --header "Authorization: Token $token"
        
        elif [[ -n "$WAN_IPv4" ]]; then
            echo "Nur IPv4 ist verfügbar: IPv4 = '$WAN_IPv4'"
            curl -s "https://update.dedyn.io/?hostname=$kodihost&myipv4=$WAN_IPv4&myipv6=no" --header "Authorization: Token $token"
        
        elif [[ -n "$WAN_IPv6" ]]; then
            echo "Nur IPv6 ist verfügbar: IPv6 = '$WAN_IPv6'"
            curl -s "https://update.dedyn.io/?hostname=$kodihost&myipv4=no&myipv6=$WAN_IPv6" --header "Authorization: Token $token"
        
        else
            echo "Keine der beiden IPs ist verfügbar"
        fi
    else
        echo "Die IPs haben sich nicht geändert. Keine Aktion erforderlich."
    fi
}

# Funktionen ende
start_time=$(date +%s)

kodihost="$subname.$domain"

echo "Hostname: $kodihost"
hostname_to_ip "$domain" "$subname" "$token"

# Aktuelle WAN IP ermitteln
WAN_IPv4=$(curl -s4L https://ip.micneu.de)
WAN_IPv6=$(curl -s6L https://ip.micneu.de)
check_ip_address "$WAN_IPv4"
check_ip_address "$WAN_IPv6"

check_host "$WAN_IPv4" "$WAN_IPv6"

end_time=$(date +%s)
elapsed_time=$(( end_time - start_time ))
echo -e "\n"
format_runtime $elapsed_time
