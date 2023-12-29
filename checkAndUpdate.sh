#!/bin/bash
echo "testiong 314321432143214321"
cd ./minecraft

# Retrieve latest version of Minecraft Bedrock dedicated server
echo "Checking for the latest version of Minecraft Bedrock server ..."

# Test internet connectivity first
curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.$RandNum.212 Safari/537.36" -s https://www.minecraft.net/ -o /dev/null
if [ "$?" != 0 ]; then
    echo "Unable to connect to update website (internet connection may be down).  Skipping update ..."
else
    # Download server index.html to check latest version
    curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.$RandNum.212 Safari/537.36" -o downloads/version.html https://www.minecraft.net/en-us/download/server/bedrock
    LatestURL=$(grep -o 'https://minecraft.azureedge.net/bin-linux/[^"]*' downloads/version.html)

    LatestFile=$(echo "$LatestURL" | sed 's#.*/##')

    if [ -e version_installed.txt ]; then
        InstalledFile=$(cat version_installed.txt)
        echo "Current install is: $InstalledFile"
    fi

    if [[ "$InstalledFile" == "$LatestFile" ]]; then
        echo "Latest version $LatestFile is already installed"
    else
        echo "Installing $LatestFile"
        DownloadFile=$LatestFile
        DownloadURL=$LatestURL

        # Download version of Minecraft Bedrock dedicated server if it's not already local
        if [ ! -f "downloads/$DownloadFile" ]; then
            curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.$RandNum.212 Safari/537.36" -o "./downloads/$DownloadFile" "$DownloadURL"
        fi

        # Install version of Minecraft requested
        if [ ! -z "$DownloadFile" ]; then
            unzip -o "./downloads/$DownloadFile" -x "*server.properties*" "*permissions.json*" "*whitelist.json*" "*valid_known_packs.json*" "*allowlist.json*"
            Permissions=$(chmod u+x ./bedrock_server >/dev/null)
            echo "$DownloadFile" >version_installed.txt
        fi
    fi
fi
