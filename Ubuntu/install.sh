#!/bin/bash
currentScriptDir=""$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )""
applicationUser="steam"
applicationUserDirectory="/home/${applicationUser}"

declare -A applicationDirectories
applicationDirectories["enshrouded"]="${applicationUserDirectory}/enshrouded"
applicationDirectories["enshrouded-saves"]="${applicationUserDirectory}/enshrouded/savegame"
applicationDirectories["enshrouded-logs"]="${applicationUserDirectory}/enshrouded/logs"
applicationDirectories["enshrouded-prefix"]="${applicationUserDirectory}/.enshrouded_prefix"

export DEBIAN_FRONTEND "noninteractive"

# Install Script Dependencies
checkDependencies() {
    echo "Verifying Server Dependencies"
    which curl > /dev/null 2>&1 || apt install curl -y
    id "${applicationUser}" > /dev/null 2>&1 || createApplicationUser
    which steamcmd > /dev/null 2>&1 || installSteamCMD
    which wine64 > /dev/null 2>&1 || installWine
}

# Install Steam CMD
installSteamCMD() {
    apt update -y
    add-apt-repository multiverse -y
    dpkg --add-architecture i386
    echo steam steam/question select "I AGREE" | debconf-set-selections && echo steam steam/license note '' | debconf-set-selections
    apt update -y
    apt install -y lib32z1 lib32gcc-s1 lib32stdc++6 steamcmd -y
    prepareSteamCMD
}

# Create Application User
createApplicationUser() {
    echo    "Installing Application User: ${applicationUser}"
    useradd -m "${applicationUser}" -g "${applicationUser}"
    passwd "${applicationUser}" --lock
}

#TODO: Improve this to not need executable added to home dir
prepareSteamCMD() {
    ln -s /usr/games/steamcmd "${applicationUserDirectory}/steamcmd"
    chown -R "${applicationUser}":"${applicationUser}" "${applicationUserDirectory}/steamcmd"
    su steam -c "/home/steam/steamcmd +quit"
}

installWine() {
    echo "Installing Wine Application"
    dpkg --add-architecture amd64
    mkdir -pm755 /etc/apt/keyrings
    curl -L -o "/etc/apt/keyrings/winehq-archive.key" "https://dl.winehq.org/wine-builds/winehq.key"
    curl -L -o "/etc/apt/sources.list.d/winehq-jammy.sources" "https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources"
    apt update -y
    apt install -y --install-recommends winehq-staging
    apt install -y --allow-unauthenticated cabextract winbind screen xvfb
    curl -L -o "/usr/local/bin/winetricks" "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"
    chmod +x /usr/local/bin/winetricks
    cp "${currentScriptDir}/assets/winetricks.sh" "/home/steam/winetricks.sh"
    chmod +x /home/steam/winetricks.sh
}

setupDirectories() {
    echo "Creating Application Directories"
    for dirs in "${applicationDirectories[@]}"; do
        mkdir -p "${dirs}"
        chown -R "${applicationUser}":"${applicationUser}" "${dirs}"
    done
}

collectUserParameters() {
    read -p "What is the name of Enshrouded server ?" enshroudedServerName
    read -p "What is the password of Enshrouded server ?" enshroudedServerPassword
    read -p "What is the player limit of Enshrouded server (max is 16) ?" enshroudedServerPlayerCount
}

setupApplicationConfig() {
    cp "${currentScriptDir}/assets/enshrouded_server.json" "${applicationDirectories[enshrouded]}/enshrouded_server.json"
    sed -i "s|ENSHROUDED_SERVER_NAME|${enshroudedServerName}|" "${applicationDirectories[enshrouded]}/enshrouded_server.json"
    sed -i "s|ENSHROUDED_SERVER_PASSWORD|${enshroudedServerPassword}|" "${applicationDirectories[enshrouded]}/enshrouded_server.json"
    sed -i "s|ENSHROUDED_SERVER_MAXPLAYERS|${enshroudedServerPlayerCount}|" "${applicationDirectories[enshrouded]}/enshrouded_server.json"
    cp "${currentScriptDir}/assets/enshrouded.service" "/etc/systemd/system/enshrouded.service"
    sed -i "s|APP_DIR|${applicationUserDirectory}|g" "/etc/systemd/system/enshrouded.service"
    sed -i "s|APP_USER|${applicationUser}|g" "/etc/systemd/system/enshrouded.service"
    sed -i "s|APP_GROUP|${applicationUser}|g" "/etc/systemd/system/enshrouded.service"
    chown -R "${applicationUser}":"${applicationUser}" /home/steam/
    sudo su steam -c "${applicationUserDirectory}/steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir ${applicationUserDirectory}/enshrouded +login anonymous +app_update 2278520 +quit"
    systemctl daemon-reload
    systemctl enable enshrouded.service
}

checkDependencies
setupDirectories
collectUserParameters
setupApplicationConfig