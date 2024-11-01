#!/bin/bash

echo -e "\e[32m"
cat << "EOF"
███████  ██████  ██████      ██   ██ ███████ ███████ ██████      ██ ████████     ████████ ██████   █████  ██████  ██ ███    ██  ██████  
██      ██    ██ ██   ██     ██  ██  ██      ██      ██   ██     ██    ██           ██    ██   ██ ██   ██ ██   ██ ██ ████   ██ ██       
█████   ██    ██ ██████      █████   █████   █████   ██████      ██    ██           ██    ██████  ███████ ██   ██ ██ ██ ██  ██ ██   ███ 
██      ██    ██ ██   ██     ██  ██  ██      ██      ██          ██    ██           ██    ██   ██ ██   ██ ██   ██ ██ ██  ██ ██ ██    ██ 
██       ██████  ██   ██     ██   ██ ███████ ███████ ██          ██    ██           ██    ██   ██ ██   ██ ██████  ██ ██   ████  ██████  
                                                                                                                                        
                                                                                                                                       
 ██  ██████  ██       █████  ███    ██ ██████   █████  ███    ██ ████████ ███████                                                         
██  ██        ██     ██   ██ ████   ██ ██   ██ ██   ██ ████   ██    ██    ██                                                             
██  ██        ██     ███████ ██ ██  ██ ██   ██ ███████ ██ ██  ██    ██    █████                                                          
██  ██        ██     ██   ██ ██  ██ ██ ██   ██ ██   ██ ██  ██ ██    ██    ██                                                             
 ██  ██████  ██      ██   ██ ██   ████ ██████  ██   ██ ██   ████    ██    ███████

Donate: 0x0004230c13c3890F34Bb9C9683b91f539E809000
EOF
echo -e "\e[0m"

function install_node {
    echo "Обновляем сервер..."
    sudo apt-get update -y && sudo apt upgrade -y && sudo apt-get install make screen build-essential unzip lz4 gcc git jq -y
    sudo rm -rf /usr/local/go
    echo "Устанавливаем Go..."
    curl -Ls https://go.dev/dl/go1.22.4.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
    eval $(echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh)
    eval $(echo 'export PATH=$PATH:$HOME/go/bin' | tee -a $HOME/.profile)
    echo "Скачиваем репозиторий проекта..."
    wget https://github.com/hemilabs/heminetwork/releases/download/v0.5.0/heminetwork_v0.5.0_linux_amd64.tar.gz
    tar -xvf heminetwork_v0.5.0_linux_amd64.tar.gz
    rm -rf heminetwork_v0.5.0_linux_amd64.tar.gz
    cd heminetwork_v0.5.0_linux_amd64/
    echo "Создаем кошелек..."
    ./keygen -secp256k1 -json -net="testnet" > /root/heminetwork_v0.5.0_linux_amd64/popm-address.json
    cat /root/heminetwork_v0.5.0_linux_amd64/popm-address.json
    
    # Извлекаем приватный ключ из созданного кошелька
    PRIVATE_KEY=$(jq -r '.private_key' /root/heminetwork_v0.5.0_linux_amd64/popm-address.json)

    # Спрашиваем пользователя, хочет ли он использовать сгенерированный ключ или ввести свой
    read -p "Хотите использовать сгенерированный приватный ключ? (y/n): " use_generated_key
    if [[ "$use_generated_key" == "y" ]]; then
        echo "Используем сгенерированный приватный ключ..."
    else
        read -p "Введите ваш приватный ключ: " PRIVATE_KEY
    fi

    # Экспортируем приватный ключ в системные переменные
    echo "export POPM_PRIVATE_KEY=$PRIVATE_KEY" >> /etc/environment
    echo 'export POPM_STATIC_FEE=5000' >> /etc/environment
    echo 'export POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public' >> /etc/environment
    source /etc/environment

    # Проверяем, что переменная установлена
    if [[ -z "$POPM_PRIVATE_KEY" ]]; then
        echo "Ошибка: приватный ключ не был установлен. Проверьте настройки."
        exit 1
    fi

    echo "Создаем сервисный файл..."
    sudo tee /etc/systemd/system/hemid.service > /dev/null <<EOF
[Unit]
Description=Hemi
After=network.target

[Service]
User=$USER
EnvironmentFile=/etc/environment
WorkingDirectory=/root/heminetwork_v0.5.0_linux_amd64
ExecStart=/root/heminetwork_v0.5.0_linux_amd64/popmd
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    echo "Запускаем сервис..."
    sudo systemctl enable hemid
    sudo systemctl daemon-reload
    sudo systemctl start hemid
    echo "Нода успешно установлена и запущена!"
}

function restart_node {
    echo "Перезапускаем ноду..."
    sudo systemctl restart hemid
}

function change_port {
    read -p "Введите новый порт: " port
    sudo sed -i "s/Environment=\"POPM_BFG_URL=wss:\/\/.*\/v1\/ws\/public\"/Environment=\"POPM_BFG_URL=wss:\/\/$port\/v1\/ws\/public\"/" /etc/systemd/system/hemid.service
    sudo systemctl daemon-reload
    sudo systemctl restart hemid
    echo "Порт изменен и нода перезапущена."
}

function change_fee {
    read -p "Введите новую комиссию: " fee
    sudo sed -i "s/Environment=\"POPM_STATIC_FEE=.*\"/Environment=\"POPM_STATIC_FEE=$fee\"/" /etc/systemd/system/hemid.service
    sudo systemctl daemon-reload
    sudo systemctl restart hemid
    echo "Комиссия изменена и нода перезапущена."
}

function view_logs {
    sudo journalctl -u hemid -f
}

function remove_node {
    echo "Удаляем ноду..."
    sudo systemctl stop hemid
    sudo systemctl disable hemid
    sudo rm -rf /etc/systemd/system/hemid.service
    sudo rm -rf /root/heminetwork_v0.5.0_linux_amd64
    sudo systemctl daemon-reload
    echo "Нода успешно удалена."
}

function import_wallet {
    read -p "Введите приватный ключ: " private_key
    echo "export POPM_PRIVATE_KEY=$private_key" >> /etc/environment
    source /etc/environment
    echo "Кошелек успешно импортирован."
}

function main_menu {
    while true; do
        echo "Выберите действие:"
        echo "1. Установка ноды"
        echo "2. Рестарт ноды"
        echo "3. Изменить порт"
        echo "4. Изменить комиссию"
        echo "5. Просмотр логов"
        echo "6. Удаление ноды"
        echo "7. Импортировать кошелек"
        echo "8. Выход"
        read -p "Введите номер: " choice
        case $choice in
            1) install_node ;;
            2) restart_node ;;
            3) change_port ;;
            4) change_fee ;;
            5) view_logs ;;
            6) remove_node ;;
            7) import_wallet ;;
            8) break ;;
            *) echo "Неверный выбор, попробуйте снова." ;;
        esac
    done
}

main_menu
