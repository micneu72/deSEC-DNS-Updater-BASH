#!/bin/bash
: '
----------------------------------------------------------------------------
    Script Name:     desec.sh
    CreationDate:    08.02.2024
    Last Modified:   08.03.2025 23:19:20
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

# Domain, die aktualisiert werden soll
kodihost="deine.domain.hier.eintragen"
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

if [ -z "$kodihost" ] || [ "$kodihost" = "deine.domain.hier.eintragen" ]; then
    echo "Fehler: Domain konnte nicht aus der Konfigurationsdatei gelesen werden oder wurde nicht angepasst."
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
        echo "IPv4: $ip"
        return 0
    fi

    # Überprüfung, ob der String mit dem IPv6-RegEx übereinstimmt
    if [[ $ip =~ $ipv6_regex ]]; then
        echo "IPv6: $ip"
        return 0
    fi

    echo "Invalid IP"
    return 1
}


# Funktion zur Auflösung eines Hostnamens in eine IPv4- und IPv6-Adresse
hostname_to_ip() {
    local hostname="$1"
    local ipv4_list=""
    local ipv6_list=""

    # Prüfen, ob 'drill' verfügbar ist
    if command -v drill &> /dev/null; then
        local results=$(drill "$hostname" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}|(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,7}|:))|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$')
    elif command -v host &> /dev/null; then
        local results=$(host "$hostname" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}|(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,7}|:))|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$')
    else
        echo "Fehler: Weder 'drill' noch 'host' sind verfügbar."
        return 1
    fi

    # Trenne IPv4 und IPv6 Adressen
    ipv4_list=$(echo "$results" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' | tr '\n' ' ' | sed 's/[[:space:]]$//')
    ipv6_list=$(echo "$results" | grep -E '^([0-9a-fA-F]{1,4}:)' | tr '\n' ' ' | sed 's/[[:space:]]$//')

    # Rückgabe der IP-Adressen
    echo "IP4=$ipv4_list, IP6=$ipv6_list"
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
    local AktuelleIPv4="$1"
    local AktuelleIPv6="$2"

    # Leerzeichen entfernen (vorne, hinten) durch tr
    AktuelleIPv4=$(echo "$AktuelleIPv4" | tr -d '[:space:]')
    AktuelleIPv6=$(echo "$AktuelleIPv6" | tr -d '[:space:]')

    # Optional auch für IPv4 und IPv6, falls sie irgendwo anders Leerzeichen bekommen
    IPv4=$(echo "$IPv4" | tr -d '[:space:]')
    IPv6=$(echo "$IPv6" | tr -d '[:space:]')

    #echo "Debug: AktuelleIPv4='$AktuelleIPv4', AktuelleIPv6='$AktuelleIPv6', IPv4='$IPv4', IPv6='$IPv6'"

    if [[ "$AktuelleIPv4" != "$IPv4" || "$AktuelleIPv6" != "$IPv6" ]]; then
        echo "Die IPs haben sich geändert oder eine davon. Verarbeitung starten."

        if [[ -n "$IPv4" && -n "$IPv6" ]]; then
            echo "Beide IPs sind verfügbar: IPv4 = '$IPv4', IPv6 = '$IPv6'"
            curl -s "https://update.dedyn.io/?hostname=$kodihost&myipv4=$IPv4&myipv6=$IPv6" --header "Authorization: Token $token"
        
        elif [[ -n "$IPv4" ]]; then
            echo "Nur IPv4 ist verfügbar: IPv4 = '$IPv4'"
            curl -s "https://update.dedyn.io/?hostname=$kodihost&myipv4=$IPv4&myipv6=no" --header "Authorization: Token $token"
        
        elif [[ -n "$IPv6" ]]; then
            echo "Nur IPv6 ist verfügbar: IPv6 = '$IPv6'"
            curl -s "https://update.dedyn.io/?hostname=$kodihost&myipv4=no&myipv6=$IPv6" --header "Authorization: Token $token"
        
        else
            echo "Keine der beiden IPs ist verfügbar"
        fi
    else
        echo "Die IPs haben sich nicht geändert. Keine Aktion erforderlich."
    fi
}

# Funktionen ende
start_time=$(date +%s)

# Beispielaufrufe der Funktion
echo "Hostname: $kodihost"
hostname_to_ip "$kodihost"
AktuelleIPs=$(hostname_to_ip "$kodihost")
AktuelleIPv4=$(echo "$AktuelleIPs" | cut -d',' -f1 | cut -d'=' -f2)
AktuelleIPv6=$(echo "$AktuelleIPs" | cut -d',' -f2 | cut -d'=' -f2)
#echo "$AktuelleIPv4 $AktuelleIPv6"


# Beispielaufrufe der Funktion
IPv4=$(curl -4L https://ip.micneu.de)
IPv6=$(curl -6L https://ip.micneu.de)
check_ip_address "$IPv4"
check_ip_address "$IPv6"

check_host "$AktuelleIPv4" "$AktuelleIPv6"

end_time=$(date +%s)
elapsed_time=$(( end_time - start_time ))
echo -e "\n"
format_runtime $elapsed_time
