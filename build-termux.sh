#!/usr/bin/env bash

set -e

pr() { echo -e "\033[0;32m[+] ${1}\033[0m"; }
ask() {
	local y
	for ((n = 0; n < 3; n++)); do
		pr "$1 [y/n]"
		if read -r y; then
			if [ "$y" = y ]; then
				return 0
			elif [ "$y" = n ]; then
				return 1
			fi
		fi
		pr "Asking again..."
	done
	return 1
}

pr "Ask for storage permission"
until
	yes | termux-setup-storage >/dev/null 2>&1
	ls /sdcard >/dev/null 2>&1
do sleep 1; done
if [ ! -f ~/.rvmm_"$(date '+%Y%m')" ]; then
	pr "Setting up environment..."
	yes "" | pkg update -y && pkg upgrade -y && pkg install -y git curl jq openjdk-17 zip
	: >~/.rvmm_"$(date '+%Y%m')"
fi
mkdir -p /sdcard/Download/revanced/

if [ -d revanced ] || [ -f config.toml ]; then
	if [ -d revanced ]; then cd revanced; fi
	pr "Checking for revanced updates"
	git fetch
	if git status | grep -q 'is behind\|fatal'; then
		pr "revanced is not synced with upstream."
		pr "Cloning revanced. config.toml will be preserved."
		cd ..
		cp -f revanced/config.toml .
		rm -rf revanced
		git clone https://github.com/WildeBeast2521/revanced --recurse --depth 1
		mv -f config.toml revanced/config.toml
		cd revanced
	fi
else
	pr "Cloning revanced."
	git clone https://github.com/WildeBeast2521/revanced --depth 1
	cd revanced
	sed -i '/^enabled.*/d; /^\[.*\]/a enabled = false' config.toml
	grep -q 'revanced' ~/.gitconfig 2>/dev/null ||
		git config --global --add safe.directory ~/revanced
fi

[ -f ~/storage/downloads/revanced/config.toml ] ||
	cp config.toml ~/storage/downloads/revanced/config.toml

if ask "Open rvmm-config-gen to generate a config?"; then
	am start -a android.intent.action.VIEW -d https://j-hc.github.io/rvmm-config-gen/
fi
printf "\n"
until
	if ask "Open 'config.toml' to configure builds?\nAll are disabled by default, you will need to enable at first time building"; then
		am start -a android.intent.action.VIEW -d file:///sdcard/Download/revanced/config.toml -t text/plain
	fi
	ask "Setup is done. Do you want to start building?"
do :; done
cp -f ~/storage/downloads/revanced/config.toml config.toml

./build.sh

cd build
PWD=$(pwd)
for op in *; do
	[ "$op" = "*" ] && {
		pr "glob fail"
		exit 1
	}
	mv -f "${PWD}/${op}" ~/storage/downloads/revanced/"${op}"
done

pr "Outputs are available in /sdcard/Download/revanced folder"
am start -a android.intent.action.VIEW -d file:///sdcard/Download/revanced -t resource/folder
sleep 2
am start -a android.intent.action.VIEW -d file:///sdcard/Download/revanced -t resource/folder
