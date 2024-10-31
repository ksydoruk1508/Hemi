#!/bin/bash

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
Environment="POPM_BTC_PRIVKEY=$POPM_PRIVATE_KEY"
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
}

function change_port {
    read -p "Enter new port number: " NEW_PORT
    sudo sed -i "s/Environment=\"POPM_BFG_URL=wss:\/\/testnet\.rpc\.hemi\.network\/v1\/ws\/public\"/Environment=\"POPM_BFG_URL=wss:\/\/testnet\.rpc\.hemi\.network:\$NEW_PORT\/v1\/ws\/public\"/g" /etc/systemd/system/hemid.service
    sudo systemctl daemon-reload
    sudo systemctl restart hemid
    echo "Port changed to $NEW_PORT."
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

PS3="Please select an option: "
options=("Install Node" "Change Port" "Remove Node" "Exit")
select opt in "${options[@]}"; do
    case $opt in
        "Install Node")
            install_node
            ;;
        "Change Port")
            change_port
            ;;
        "Remove Node")
            remove_node
            ;;
        "Exit")
            break
            ;;
        *)
            echo "Invalid option $REPLY"
            ;;
    esac
done
