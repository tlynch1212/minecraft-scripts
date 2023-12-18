#!/bin/bash
# Author: James Chambers - https://jamesachambers.com/minecraft-bedrock-edition-ubuntu-dedicated-server-guide/
# Minecraft Bedrock server startup script using screen

# Set path variable
USERPATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
PathLength=${#USERPATH}
if [[ "$PathLength" -gt 12 ]]; then
    PATH="$USERPATH"
else
    echo "Unable to set path variable.  You likely need to download an updated version of SetupMinecraft.sh from GitHub!"
fi

# Check to make sure we aren't running as root
if [[ $(id -u) = 0 ]]; then
    echo "This script is not meant to be run as root. Please run ./start.sh as a non-root user, without sudo;  Exiting..."
    exit 1
fi

# Randomizer for user agent
RandNum=$((1 + $RANDOM % 5000))

# Check if server is already started
ScreenWipe=$(screen -wipe 2>&1)
if screen -list | grep -q '\.minecraft\s'; then
    echo "Server is already started!  Press screen -r minecraft to open it"
    exit 1
fi

# Change directory to server directory
cd /minecraft-server/minecraft-server

# Create logs/backups/downloads folder if it doesn't exist
if [ ! -d "logs" ]; then
    mkdir logs
fi
if [ ! -d "downloads" ]; then
    mkdir downloads
fi
if [ ! -d "backups" ]; then
    mkdir backups
fi

# Check if network interfaces are up
NetworkChecks=0
if [ -e '/sbin/route' ]; then
    DefaultRoute=$(/sbin/route -n | awk '$4 == "UG" {print $2}')
else
    DefaultRoute=$(route -n | awk '$4 == "UG" {print $2}')
fi
while [ -z "$DefaultRoute" ]; do
    echo "Network interface not up, will try again in 1 second"
    sleep 1
    if [ -e '/sbin/route' ]; then
        DefaultRoute=$(/sbin/route -n | awk '$4 == "UG" {print $2}')
    else
        DefaultRoute=$(route -n | awk '$4 == "UG" {print $2}')
    fi
    NetworkChecks=$((NetworkChecks + 1))
    if [ $NetworkChecks -gt 20 ]; then
        echo "Waiting for network interface to come up timed out - starting server without network connection ..."
        break
    fi
done

# Take ownership of server files and set correct permissions
Permissions=$(sudo bash /minecraft-server/minecraft-server/fixpermissions.sh -a)

# Create backup
if [ -d "worlds" ]; then
    echo "Backing up server (to minecraftbe/minecraft/backups folder)"
    if [ -n "$(which pigz)" ]; then
        echo "Backing up server (multiple cores) to minecraftbe/minecraft/backups folder"
        tar -I pigz -pvcf backups/$(date +%Y.%m.%d.%H.%M.%S).tar.gz worlds
    else
        echo "Backing up server (single cored) to minecraftbe/minecraft/backups folder"
        tar -pzvcf backups/$(date +%Y.%m.%d.%H.%M.%S).tar.gz worlds
    fi
fi

# Rotate backups -- keep most recent 10
Rotate=$(
    pushd /minecraft-server/minecraft-server/backups
    ls -1tr | head -n -10 | xargs -d '\n' rm -f --
    popd
)

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

    echo "Latest version online is $LatestFile"
    if [ -e version_pin.txt ]; then
        echo "version_pin.txt found with override version, using version specified: $(cat version_pin.txt)"
        PinFile=$(cat version_pin.txt)
    fi

    if [ -e version_installed.txt ]; then
        InstalledFile=$(cat version_installed.txt)
        echo "Current install is: $InstalledFile"
    fi

    if [[ "$PinFile" == *"zip" ]] && [[ "$InstalledFile" == "$PinFile" ]]; then
        echo "Requested version $PinFile is already installed"
    elif [ ! -z "$PinFile" ]; then
        echo "Installing $PinFile"
        DownloadFile=$PinFile
        DownloadURL="https://minecraft.azureedge.net/bin-linux/$PinFile"

        # Download version of Minecraft Bedrock dedicated server if it's not already local
        if [ ! -f "downloads/$DownloadFile" ]; then
            curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.$RandNum.212 Safari/537.36" -o "downloads/$DownloadFile" "$DownloadURL"
        fi

        # Install version of Minecraft requested
        if [ ! -z "$DownloadFile" ]; then
            if [ ! -e /minecraft-server/minecraft-server/server.properties ]; then
                unzip -o "downloads/$DownloadFile" -x "*permissions.json*" "*whitelist.json*" "*valid_known_packs.json*" "*allowlist.json*"
            else
                unzip -o "downloads/$DownloadFile" -x "*server.properties*" "*permissions.json*" "*whitelist.json*" "*valid_known_packs.json*" "*allowlist.json*"
            fi
            Permissions=$(chmod u+x /minecraft-server/minecraft-server/bedrock_server >/dev/null)
            echo "$DownloadFile" >version_installed.txt
        fi
    elif [[ "$InstalledFile" == "$LatestFile" ]]; then
        echo "Latest version $LatestFile is already installed"
    else
        echo "Installing $LatestFile"
        DownloadFile=$LatestFile
        DownloadURL=$LatestURL

        # Download version of Minecraft Bedrock dedicated server if it's not already local
        if [ ! -f "downloads/$DownloadFile" ]; then
            curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.$RandNum.212 Safari/537.36" -o "downloads/$DownloadFile" "$DownloadURL"
        fi

        # Install version of Minecraft requested
        if [ ! -z "$DownloadFile" ]; then
            if [ ! -e /minecraft-server/minecraft-server/server.properties ]; then
                unzip -o "downloads/$DownloadFile" -x "*permissions.json*" "*whitelist.json*" "*valid_known_packs.json*" "*allowlist.json*"
            else
                unzip -o "downloads/$DownloadFile" -x "*server.properties*" "*permissions.json*" "*whitelist.json*" "*valid_known_packs.json*" "*allowlist.json*"
            fi
            Permissions=$(chmod u+x /minecraft-server/minecraft-server/bedrock_server >/dev/null)
            echo "$DownloadFile" >version_installed.txt
        fi
    fi
fi

if [ ! -e /minecraft-server/minecraft-server/allowlist.json ]; then
    echo "Creating default allowlist.json..."
    echo '[]' >/minecraft-server/minecraft-server/allowlist.json
fi
if [ ! -e /minecraft-server/minecraft-server/permissions.json ]; then
    echo "Creating default permissions.json..."
    echo '[]' >/minecraft-server/minecraft-server/permissions.json
fi
ContentLogging=$(grep "content-log-file-enabled" /minecraft-server/minecraft-server/server.properties)
if [ -z "$ContentLogging" ]; then
    echo "" >> /minecraft-server/minecraft-server/server.properties
    echo "content-log-file-enabled=true" >> /minecraft-server/minecraft-server/server.properties
    echo "# Enables logging content errors to a file" >> /minecraft-server/minecraft-server/server.properties
fi

echo "Starting Minecraft server.  To view window type screen -r minecraft"
echo "To minimize the window and let the server run in the background, press Ctrl+A then Ctrl+D"

CPUArch=$(uname -m)
if [[ "$CPUArch" == *"aarch64"* ]]; then
    cd /minecraft-server/minecraft-server
    if [ -n "$(which box64)" ]; then
        BASH_CMD="box64 bedrock_server"
    else
        BASH_CMD="LD_LIBRARY_PATH=/minecraft-server/minecraft-server /minecraft-server/minecraft-server/bedrock_server"
    fi
else
    BASH_CMD="LD_LIBRARY_PATH=/minecraft-server/minecraft-server /minecraft-server/minecraft-server/bedrock_server"
fi

if command -v gawk &>/dev/null; then
    BASH_CMD+=$' | gawk \'{ print strftime(\"[%Y-%m-%d %H:%M:%S]\"), $0 }\''
else
    echo "gawk application was not found -- timestamps will not be available in the logs.  Please delete SetupMinecraft.sh and run the script the new recommended way!"
fi
screen -L -Logfile logs/minecraft.$(date +%Y.%m.%d.%H.%M.%S).log -dmS minecraft /bin/bash -c "${BASH_CMD}"