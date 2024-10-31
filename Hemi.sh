#!/bin/bash

echo -e "\e[32m"
cat << "EOF"
███████  ██████  ██████      ██   ██ ███████ ███████ ██████      ██ ████████     ████████ ██████   █████  ██████  ██ ███    ██  ██████  
██      ██    ██ ██   ██     ██  ██  ██      ██      ██   ██     ██    ██           ██    ██   ██ ██   ██ ██   ██ ██ ████   ██ ██       
█████   ██    ██ ██████      █████   █████   █████   ██████      ██    ██           ██    ██████  ███████ ██   ██ ██ ██ ██  ██ ██   ███ 
██      ██    ██ ██   ██     ██  ██  ██      ██      ██          ██    ██           ██    ██   ██ ██   ██ ██   ██ ██ ██  ██ ██ ██    ██ 
██       ██████  ██   ██     ██   ██ ███████ ███████ ██          ██    ██           ██    ██   ██ ██   ██ ██████  ██ ██   ████  ██████  
                                                                                                                                        
                                                                                                                                        
 ██  ██████ ██       █████  ███    ██ ██████   █████  ███    ██ ████████ ███████                                                        
██  ██       ██     ██   ██ ████   ██ ██   ██ ██   ██ ████   ██    ██    ██                                                             
██  ██       ██     ███████ ██ ██  ██ ██   ██ ███████ ██ ██  ██    ██    █████                                                          
██  ██       ██     ██   ██ ██  ██ ██ ██   ██ ██   ██ ██  ██ ██    ██    ██                                                             
 ██  ██████ ██      ██   ██ ██   ████ ██████  ██   ██ ██   ████    ██    ███████


Donate: 0x0004230c13c3890F34Bb9C9683b91f539E809000
EOF
echo -e "\e[0m"

function install_node {
    echo "Updating and upgrading system packages..."
    sudo apt-get update -y && sudo apt upgrade -y
    echo "Installing dependencies..."
    sudo apt-get install make screen build-essential unzip lz4 gcc git jq -y

    echo "Installing Go..."
    sudo rm -rf /usr/local/go
    curl -Ls https://go.dev/dl/go1.22.4.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
    eval $(echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh)
    eval $(echo 'export PATH=$PATH:$HOME/go/bin' | tee -a $HOME/.profile)

    echo "Downloading project repository..."
    wget https://github.com/hemilabs/heminetwork/releases/download/v0.5.0/heminetwork_v0.5.0_linux_amd64.tar.gz
    tar -xvf heminetwork_v0.5.0_linux_amd64.tar.gz
    rm -rf heminetwork_v0.5.0_linux_amd64.tar.gz
    cd heminetwork_v0.5.0_linux_amd64/

    echo "Creating wallet..."
    ./keygen -secp256k1 -json -net="testnet" > /root/heminetwork_v0.5.0_linux_amd64/popm-address.json
    cat popm-address.json
    echo "Save the above file and its data - this is your wallet!"

    read -p "Enter your private key: " PRIVATE_KEY
    export POPM_PRIVATE_KEY=$PRIVATE_KEY
    echo "export POPM_PRIVATE_KEY=$PRIVATE_KEY" >> ~/.bashrc
    echo "export POPM_STATIC_FEE=5000" >> ~/.bashrc
    echo "export POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public" >> ~/.bashrc
    source ~/.bashrc

    echo "Creating service file..."
    sudo tee /etc/systemd/system/hemid.service > /dev/null <<EOF
[Unit]
Description=Hemi
After=network.target

[Service]
User=$USER
Environment="POPM_BTC_PRIVKEY=$PRIVATE_KEY"
Environment="POPM_STATIC_FEE=5000"
Environment="POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public"
WorkingDirectory=/root/heminetwork_v0.5.0_linux_amd64
ExecStart=/root/heminetwork_v0.5.0_linux_amd64/popmd
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    echo "Starting service..."
    sudo systemctl enable hemid
    sudo systemctl daemon-reload
    sudo systemctl start hemid
    echo "Node installation complete."
    exit 0
}

function restart_node {
    echo "Restarting node..."
    sudo systemctl daemon-reload
    sudo systemctl restart hemid
    echo "Node restarted."
}

function change_port {
    read -p "Enter new port number: " NEW_PORT
    sudo sed -i "s/Environment="POPM_BFG_URL=wss:\/\/testnet\.rpc\.hemi\.network\/v1\/ws\/public"/Environment="POPM_BFG_URL=wss:\/\/testnet\.rpc\.hemi\.network:\$NEW_PORT\/v1\/ws\/public"/g" /etc/systemd/system/hemid.service
    sudo systemctl daemon-reload
    sudo systemctl restart hemid
    echo "Port changed to $NEW_PORT."
}

function import_wallet {
    read -p "Enter your private key to import: " PRIVATE_KEY
    export POPM_PRIVATE_KEY=$PRIVATE_KEY
    echo "export POPM_PRIVATE_KEY=$PRIVATE_KEY" >> ~/.bashrc
    echo "Creating service file for imported wallet..."
    sudo tee /etc/systemd/system/hemid.service > /dev/null <<EOF
[Unit]
Description=Hemi
After=network.target

[Service]
User=$USER
Environment="POPM_BTC_PRIVKEY=$PRIVATE_KEY"
Environment="POPM_STATIC_FEE=5000"
Environment="POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public"
WorkingDirectory=/root/heminetwork_v0.5.0_linux_amd64
ExecStart=/root/heminetwork_v0.5.0_linux_amd64/popmd
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    echo "Reloading and restarting service with new wallet..."
    sudo systemctl daemon-reload
    sudo systemctl restart hemid
    echo "Wallet imported and node restarted."
}

function view_logs {
    echo "Viewing logs..."
    sudo journalctl -u hemid -f --no-hostname -o cat
}

function remove_node {
    echo "Stopping and disabling service..."
    sudo systemctl stop hemid
    sudo systemctl disable hemid
    sudo rm /etc/systemd/system/hemid.service
    sudo systemctl daemon-reload
    echo "Removing node files..."
    rm -rf /root/heminetwork_v0.5.0_linux_amd64
    echo "Node removed successfully."
}

PS3="Выберите действие: "
options=("Установка ноды" "Рестарт ноды" "Изменение порта" "Просмотр логов" "Удаление ноды" "Импортировать кошелек" "Выход")
select opt in "${options[@]}"; do
    case $opt in
        "Установка ноды")
            install_node
            ;;
        "Рестарт ноды")
            restart_node
            ;;
        "Изменение порта")
            change_port
            ;;
        "Просмотр логов")
            view_logs
            ;;
        "Удаление ноды")
            remove_node
            ;;
        "Импортировать кошелек")
            import_wallet
            ;;
        "Выход")
            break
            ;;
        *)
            echo "Неверный вариант $REPLY"
            ;;
    esac
done
