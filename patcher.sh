#!/bin/bash

# Exit on any error to avoid showing everything was successful even though it wasn't
set -e

VERSION="15_5"
OUTPUT="am2r_${VERSION}"
PATCH_FOLDER="data"

# Cleanup previous directories and files
cleanup_directories() {
    local directories=("assets" "AM2RWrapper" "data" "HDR_HQ_in-game_music" "data.zip" "HDR_HQ_in-game_music.zip" "repo.zip" "AM2R-Autopatcher-Android-main")
    for dir in "${directories[@]}"; do
        if [ -d "$dir" ] || [ -f "$dir" ]; then
            rm -rf "$dir"
        fi
    done
}

cleanup_directories

echo "-------------------------------------------"
echo ""
echo "AM2R 1.5.5 Shell Autopatching Utility"
echo "Originally Scripted by Miepee and help from Lojemiru"
echo "Updated by izzy2fancy"
echo ""
echo "-------------------------------------------"

# Install dependencies
# Assuming you're on a Termux environment
yes | pkg install termux-am zip unzip xdelta3
yes | termux-setup-storage

# Check if apkmod is installed, if not install it. I only use this for signing 'cause it's the only way I found this to work
if ! [ -f /data/data/com.termux/files/usr/bin/apkmod ]; then
    wget https://raw.githubusercontent.com/Hax4us/Apkmod/master/setup.sh
    bash setup.sh
    rm -f setup.sh
fi

# Download repository archive and extract data + HDR_HQ_in-game_music
REPO_ZIP="repo.zip"
REPO_DIR="AM2R-Autopatcher-Android-main"
REPO_URL="https://github.com/izzy2lost/AM2R-Autopatcher-Android/archive/refs/heads/main.zip"

echo "Downloading repository archive..."
wget -O "$REPO_ZIP" "$REPO_URL"

echo "Extracting data and HDR_HQ_in-game_music from repository..."
# Extract only the two directories we need
yes | unzip -q "$REPO_ZIP" "${REPO_DIR}/data/*" "${REPO_DIR}/HDR_HQ_in-game_music/*" -d ./

# Move data contents into ./data (preserve layout)
if [ -d "${REPO_DIR}/data" ]; then
    mkdir -p data
    # Move everything inside the extracted data folder into ./data
    mv "${REPO_DIR}/data/"* data/ || true
fi

# Move HDR_HQ_in-game_music contents if present (we'll keep this dir until user chooses)
if [ -d "${REPO_DIR}/HDR_HQ_in-game_music" ]; then
    mkdir -p HDR_HQ_in-game_music
    mv "${REPO_DIR}/HDR_HQ_in-game_music/"* HDR_HQ_in-game_music/ || true
fi

# NOTE: We do NOT remove $REPO_ZIP or $REPO_DIR here because we need to preserve the extracted music dir until after the HQ prompt.
# They will be cleaned up later (after the HQ music handling).

# Check for AM2R_11.zip in downloads
if [ -f ~/storage/downloads/AM2R_11.zip ]; then
    echo "AM2R_11.zip found! Extracting to ${OUTPUT}"
    # Extract the content to the am2r_xx folder
    unzip -q ~/storage/downloads/AM2R_11.zip -d "${OUTPUT}"
else
    echo -e "\033[0;31mAM2R_11 not found. Place AM2R_11.zip (case sensitive) into your Downloads folder and try again."
    echo -e "\033[1;37m"
    exit -1
fi

echo "Applying Android patch..."
xdelta3 -dfs "${OUTPUT}"/data.win data/droid.xdelta "${OUTPUT}"/game.droid

# Delete unnecessary files
rm "${OUTPUT}"/D3DX9_43.dll "${OUTPUT}"/AM2R.exe "${OUTPUT}"/data.win 

if [ -f data/android/AM2R.ini ]; then
    cp -p data/android/AM2R.ini "${OUTPUT}"/
fi

# Music
cp data/files_to_copy/*.ogg "${OUTPUT}"/

echo ""
echo -e "\033[0;32mInstall high quality in-game music? Increases filesize by 230 MB and may lag the game\!"
echo -e "\033[1;37m"
echo "[y/n]"

read -n1 INPUT
echo ""

if [ "$INPUT" = "y" ]; then
    echo "Copying HQ music..."
    # If the earlier extracted HDR_HQ_in-game_music dir exists, use it
    if [ -d HDR_HQ_in-game_music ]; then
        cp -f HDR_HQ_in-game_music/*.ogg "${OUTPUT}"/ || true
    else
        # Fallback: try to extract HDR_HQ_in-game_music from the repo archive (in case mv failed earlier)
        echo "HQ music not present locally, attempting extraction from repository archive..."
        if [ -f "$REPO_ZIP" ]; then
            yes | unzip -q "$REPO_ZIP" "${REPO_DIR}/HDR_HQ_in-game_music/*" -d ./
            if [ -d "${REPO_DIR}/HDR_HQ_in-game_music" ]; then
                mkdir -p HDR_HQ_in-game_music
                mv "${REPO_DIR}/HDR_HQ_in-game_music/"* HDR_HQ_in-game_music/ || true
                cp -f HDR_HQ_in-game_music/*.ogg "${OUTPUT}"/ || true
            else
                echo "Could not extract HDR_HQ_in-game_music from repository archive."
            fi
        else
            echo "Repository archive not found; cannot obtain HDR_HQ_in-game_music."
        fi
    fi
    # Remove local HQ music folder now that we've copied its contents
    rm -rf HDR_HQ_in-game_music/
fi

# Now cleanup the temporary repository extraction and zip file
rm -rf "$REPO_DIR" "$REPO_ZIP"

echo "Updating lang folder..."
# Remove old lang
rm -R "${OUTPUT}"/lang/
# Install new lang
cp -RTp data/files_to_copy/lang/ "${OUTPUT}"/lang/

echo "Renaming music to lowercase..."
# Zip them without compression and extracting them as all lowercase
# Music needs to be all lowercase
zip -0qr temp.zip "${OUTPUT}"/*.ogg
rm "${OUTPUT}"/*.ogg
unzip -qLL temp.zip
rm temp.zip

echo "Packaging APK..."
# Decompile the apk
apkmod -d -i data/android/AM2RWrapper.apk -o AM2RWrapper
# Copy
mv "${OUTPUT}" assets
cp -Rp assets AM2RWrapper
# Edited yaml thing to not compress ogg's
echo "Editing apktool.yml..."
sed -i "s/doNotCompress:/doNotCompress:\n- ogg/" AM2RWrapper/apktool.yml
# Build
# Check if aapt2 exists, if not use aapt instead
if [ -f /usr/bin/aapt2 ]; then
    apkmod -r -i AM2RWrapper -o "AM2R-${VERSION}.apk"
else
    apkmod -a -r -i AM2RWrapper -o "AM2R-${VERSION}.apk"
fi
# Sign apk
apkmod -s -i "AM2R-${VERSION}.apk" -o "AM2R-${VERSION}-signed.apk"

# Cleanup
rm -R assets/ AM2RWrapper/ data/ "AM2R-${VERSION}.apk"

# Move signed APK
mv "AM2R-${VERSION}-signed.apk" ~/storage/downloads/AM2R-"${VERSION}"-signed.apk

echo ""
echo -e "\033[0;32mThe operation was completed successfully and the APK can be found in your Downloads folder as \"AM2R-${VERSION}-signed.apk\"."
echo -e "\033[0;32mSee you next mission\!"
echo -e "\033[1;37m"
xdg-open ~/storage/downloads/AM2R-"${VERSION}"-signed.apk
