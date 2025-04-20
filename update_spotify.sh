#!/bin/bash

URL="https://spotify.en.uptodown.com/android/versions"
CONFIG_TOML="config.toml"

# Fetch the page
PAGE_CONTENT=$(curl -s -H "User-Agent: Mozilla/5.0" "$URL")

# Parse version
while IFS="|" read -r DL_URL VERSION; do
    ARCH_PAGE=$(curl -s -H "User-Agent: Mozilla/5.0" "$DL_URL")
    ARCH=$(echo "$ARCH_PAGE" | grep -A4 'icon-40-architecture' | grep '<td>' | sed -E 's/<[^>]+>//g' | xargs)

    if [[ "$ARCH" =~ "armeabi-v7a" && "$ARCH" =~ "arm64-v8a" && ! "$ARCH" =~ "x86_64" && ! "$ARCH" =~ "mips" ]]; then
        CURRENT_VERSION="$VERSION"
        break
    fi
done < <(echo "$PAGE_CONTENT" | awk '
    /<div data-url="/ {
        match($0, /<div data-url="([^"]+)"/, divurl);
        current_url = divurl[1];
        inside_block = 1;
    }
    inside_block && /<span class="version">/ {
        match($0, /<span class="version">([^<]+)<\/span>/, version);
        print current_url "|" version[1];
        inside_block = 0;
    }
')

if [ -z "$CURRENT_VERSION" ]; then
    echo "No version found!"
    exit 1
fi

# Get current version from config.toml
CONFIG_VERSION=$(awk '
    BEGIN { found = 0 }
    /^\[Spotify\]/ { found = 1; next }
    /^\[.*\]/ { found = 0 }
    found && /version[[:space:]]*=/ {
        match($0, /version[[:space:]]*=[[:space:]]*"([^"]+)"/, m)
        if (m[1] != "") print m[1]
        exit
    }
' "$CONFIG_TOML")

if [ -z "$CONFIG_VERSION" ]; then
    echo "Could not find Spotify version in $CONFIG_TOML"
    exit 1
fi

# Compare versions
if [[ "$CURRENT_VERSION" != "$CONFIG_VERSION" ]]; then
    echo "New version found: $CURRENT_VERSION (was $CONFIG_VERSION)"
    sed -i "/\[Spotify\]/,/^\[.*\]/ s/version *= *\"[^\"]*\"/version = \"$CURRENT_VERSION\"/" "$CONFIG_TOML"
    echo "Updated config.toml"
    exit 0
else
    echo "Version is up-to-date: $CURRENT_VERSION"
    exit 1
fi
