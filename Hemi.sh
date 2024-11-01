#!/bin/bash

# Цвета текста
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # Нет цвета (сброс цвета)

# Проверка наличия curl и установка, если не установлен
if ! command -v curl &> /dev/null; then
    sudo apt update
    sudo apt install curl -y
fi
sleep 1

echo -e "${GREEN}"
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
echo -e "${NC}"

function install_node {
    echo -e "${BLUE}Обновляем сервер...${NC}"
    sudo apt-get update -y && sudo apt upgrade -y && sudo apt-get install make screen build-essential unzip lz4 gcc git jq -y
    sudo rm -rf /usr/local/go
    echo -e "${BLUE}Устанавливаем Go...${NC}"
    curl -Ls https://go.dev/dl/go1.22.4.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
    eval $(echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh)
    eval $(echo 'export PATH=$PATH:$HOME/go/bin' | tee -a $HOME/.profile)
    echo -e "${BLUE}Скачиваем репозиторий проекта...${NC}"
    wget https://github.com/hemilabs/heminetwork/releases/download/v0.5.0/heminetwork_v0.5.0_linux_amd64.tar.gz
    tar -xvf heminetwork_v0.5.0_linux_amd64.tar.gz
    rm -rf heminetwork_v0.5.0_linux_amd64.tar.gz
    cd heminetwork_v0.5.0_linux_amd64/
    echo -e "${BLUE}Создаем кошелек...${NC}"
    ./keygen -secp256k1 -json -net="testnet" > /root/heminetwork_v0.5.0_linux_amd64/popm-address.json
    cat /root/heminetwork_v0.5.0_linux_amd64/popm-address.json
    
    # Извлекаем приватный ключ из созданного кошелька
    PRIVATE_KEY=$(jq -r '.private_key' /root/heminetwork_v0.5.0_linux_amd64/popm-address.json)

    # Спрашиваем пользователя, хочет ли он использовать сгенерированный ключ или ввести свой
    read -p "${YELLOW}Хотите использовать сгенерированный приватный ключ? (y/n): ${NC}" use_generated_key
    if [[ "$use_generated_key" == "y" ]]; then
        echo -e "${GREEN}Используем сгенерированный приватный ключ...${NC}"
    else
        read -p "${YELLOW}Введите ваш приватный ключ: ${NC}" PRIVATE_KEY
    fi

    # Экспортируем приватный ключ в системные переменные
    echo "POPM_BTC_PRIVKEY=$PRIVATE_KEY" | sudo tee -a /etc/environment
    echo 'POPM_STATIC_FEE=5000' | sudo tee -a /etc/environment
    echo 'POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public' | sudo tee -a /etc/environment
    source /etc/environment

    # Проверяем, что переменная установлена
    if [[ -z "$POPM_BTC_PRIVKEY" ]]; then
        echo -e "${RED}Ошибка: приватный ключ не был установлен. Проверьте настройки.${NC}"
        exit 1
    fi

    echo -e "${BLUE}Создаем сервисный файл...${NC}"
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

    echo -e "${BLUE}Запускаем сервис...${NC}"
    sudo systemctl enable hemid
    sudo systemctl daemon-reload
    sudo systemctl start hemid
    echo -e "${GREEN}Нода успешно установлена и запущена!${NC}"
}

function restart_node {
    echo -e "${BLUE}Перезапускаем ноду...${NC}"
    sudo systemctl restart hemid
}

function change_port {
    read -p "${YELLOW}Введите новый порт: ${NC}" port
    sudo sed -i "s/Environment=\"POPM_BFG_URL=wss:\/\/.*\/v1\/ws\/public\"/Environment=\"POPM_BFG_URL=wss:\/\/$port\/v1\/ws\/public\"/" /etc/systemd/system/hemid.service
    sudo systemctl daemon-reload
    sudo systemctl restart hemid
    echo -e "${GREEN}Порт изменен и нода перезапущена.${NC}"
}

function change_fee {
    read -p "${YELLOW}Введите новую комиссию: ${NC}" fee
    sudo sed -i "s/Environment=\"POPM_STATIC_FEE=.*\"/Environment=\"POPM_STATIC_FEE=$fee\"/" /etc/systemd/system/hemid.service
    sudo systemctl daemon-reload
    sudo systemctl restart hemid
    echo -e "${GREEN}Комиссия изменена и нода перезапущена.${NC}"
}

function view_logs {
    echo -e "${YELLOW}Проверка логов (выход из логов CTRL+C)...${NC}"
    sudo journalctl -u hemid -f
}

function remove_node {
    echo -e "${BLUE}Удаляем ноду...${NC}"
    sudo systemctl stop hemid
    sudo systemctl disable hemid
    sudo rm -rf /etc/systemd/system/hemid.service
    sudo rm -rf /root/heminetwork_v0.5.0_linux_amd64
    sudo systemctl daemon-reload
    echo -e "${GREEN}Нода успешно удалена.${NC}"
}

function import_wallet {
    read -p "${YELLOW}Введите приватный ключ: ${NC}" private_key
    echo "POPM_BTC_PRIVKEY=$private_key" | sudo tee -a /etc/environment
    source /etc/environment
    echo -e "${GREEN}Кошелек успешно импортирован.${NC}"
}

function main_menu {
    while true; do
        echo -e "${YELLOW}Выберите действие:${NC}"
        echo -e "${CYAN}1. Установка ноды${NC}"
        echo -e "${CYAN}2. Рестарт ноды${NC}"
        echo -e "${CYAN}3. Изменить порт${NC}"
        echo -e "${CYAN}4. Изменить комиссию${NC}"
        echo -e "${CYAN}5. Просмотр логов${NC}"
        echo -e "${CYAN}6. Удаление ноды${NC}"
        echo -e "${CYAN}7. Импортировать кошелек${NC}"
        echo -e "${CYAN}8. Выход${NC}"
       
        echo -e "${YELLOW}Введите номер:${NC} "
        read choice
        case $choice in
            1) install_node ;;
            2) restart_node ;;
            3) change_port ;;
            4) change_fee ;;
            5) view_logs ;;
            6) remove_node ;;
            7) import_wallet ;;
            8) break ;;
            *) echo -e "${RED}Неверный выбор, попробуйте снова.${NC}" ;;
        esac
    done
}

main_menu
