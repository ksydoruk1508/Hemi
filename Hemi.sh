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
██   ██ ███████ ███    ███ ██     ███    ██  ██████  ██████  ███████ 
██   ██ ██      ████  ████ ██     ████   ██ ██    ██ ██   ██ ██      
███████ █████   ██ ████ ██ ██     ██ ██  ██ ██    ██ ██   ██ █████   
██   ██ ██      ██  ██  ██ ██     ██  ██ ██ ██    ██ ██   ██ ██      
██   ██ ███████ ██      ██ ██     ██   ████  ██████  ██████  ███████

________________________________________________________________________________________________________________________________________


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
    echo -e "${YELLOW}Хотите использовать сгенерированный приватный ключ? (y/n): ${NC}"
    read use_generated_key
    if [[ "$use_generated_key" == "y" ]]; then
        echo -e "${GREEN}Используем сгенерированный приватный ключ...${NC}"
    else
        echo -e "${YELLOW}Введите ваш приватный ключ: ${NC}"
        read PRIVATE_KEY
    fi

    # Экспортируем приватный ключ в системные переменные
    echo "POPM_BTC_PRIVKEY=$PRIVATE_KEY" | sudo tee -a /etc/environment
    echo 'POPM_STATIC_FEE=1500' | sudo tee -a /etc/environment
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

function update_node {
    echo -e "${BLUE}Обновляем ноду Hemi...${NC}"

        # Проверка существования сервиса
    if systemctl list-units --type=service | grep -q "hemid.service"; then
        sudo systemctl stop hemid
        sudo systemctl disable hemid
        sudo rm /etc/systemd/system/hemid.service
        sudo systemctl daemon-reload
    else
        echo -e "${BLUE}Сервис hemid.service не найден, продолжаем обновление.${NC}"
    fi
    sleep 1

    # Удаление папки с бинарниками, содержащими "hemi" в названии
    echo -e "${BLUE}Удаляем старые файлы ноды...${NC}"
    rm -rf *hemi*
    
    # Обновляем и устанавливаем необходимые пакеты
    sudo apt update && sudo apt upgrade -y

    # Установка бинарника
    echo -e "${BLUE}Загружаем бинарник Hemi...${NC}"
    curl -L -O https://github.com/hemilabs/heminetwork/releases/download/v0.8.0/heminetwork_v0.8.0_linux_amd64.tar.gz

    # Создание директории и извлечение бинарника
    mkdir -p hemi
    tar --strip-components=1 -xzvf heminetwork_v0.8.0_linux_amd64.tar.gz -C hemi
    cd hemi

    # Запрос приватного ключа и комиссии
    echo -e "${YELLOW}Введите ваш приватный ключ от кошелька:${NC} "
    read PRIV_KEY
    echo -e "${YELLOW}Укажите желаемый размер комиссии (минимум 50):${NC} "
    read FEE

    # Создание файла popmd.env
    echo "POPM_BTC_PRIVKEY=$PRIV_KEY" > popmd.env
    echo "POPM_STATIC_FEE=$FEE" >> popmd.env
    echo "POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public" >> popmd.env
    sleep 1

    # Определяем имя текущего пользователя и его домашнюю директорию
    USERNAME=$(whoami)

    if [ "$USERNAME" == "root" ]; then
        HOME_DIR="/root"
    else
        HOME_DIR="/home/$USERNAME"
    fi

    # Создаем или обновляем файл сервиса с использованием определенного имени пользователя и домашней директории
    cat <<EOT | sudo tee /etc/systemd/system/hemid.service > /dev/null
[Unit]
Description=PopMD Service
After=network.target

[Service]
User=$USERNAME
EnvironmentFile=$HOME_DIR/hemi/popmd.env
ExecStart=$HOME_DIR/hemi/popmd
WorkingDirectory=$HOME_DIR/hemi/
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOT

    # Обновление сервисов и включение hemi
    sudo systemctl daemon-reload
    sudo systemctl enable hemid
    sleep 1

    # Запуск ноды
    sudo systemctl start hemid

    # Заключительный вывод
    echo -e "${GREEN}Нода успешно обновлена до версии 0.8.0!${NC}"
}

function check_version {
    echo -e "${BLUE}Проверяем текущую версию ноды...${NC}"
    if [[ -f /root/hemi/popmd ]]; then
        FULL_OUTPUT=$(/root/hemi/popmd --version 2>/dev/null)
        echo -e "${YELLOW}Полный вывод команды:${NC}
$FULL_OUTPUT"
        CURRENT_VERSION=$(echo "$FULL_OUTPUT" | grep -o 'v[0-9]\.[0-9]\.[0-9]\+[^ ]*')
        if [[ -n "$CURRENT_VERSION" ]]; then
            echo -e "${GREEN}Текущая версия ноды: $CURRENT_VERSION${NC}"
        else
            echo -e "${RED}Не удалось извлечь версию из вывода. Пожалуйста, проверьте полный вывод выше.${NC}"
        fi
    elif [[ -f /root/heminetwork_v0.5.0_linux_amd64/popmd ]]; then
        FULL_OUTPUT=$(/root/heminetwork_v0.5.0_linux_amd64/popmd --version 2>/dev/null)
        echo -e "${YELLOW}Полный вывод команды:${NC}
$FULL_OUTPUT"
        CURRENT_VERSION=$(echo "$FULL_OUTPUT" | grep -o 'v[0-9]\.[0-9]\.[0-9]\+[^ ]*')
        if [[ -n "$CURRENT_VERSION" ]]; then
            echo -e "${GREEN}Текущая версия ноды (v0.5.0): $CURRENT_VERSION${NC}"
        else
            echo -e "${RED}Не удалось извлечь версию из вывода. Пожалуйста, проверьте полный вывод выше.${NC}"
        fi
    else
        echo -e "${RED}Не удалось найти бинарный файл для проверки версии.${NC}"
    fi
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
    echo -e "${YELLOW}Введите новую комиссию: ${NC}"
    read fee

    if [[ -f "/root/hemi/popmd.env" ]]; then
        sudo sed -i "s/POPM_STATIC_FEE=[0-9]*/POPM_STATIC_FEE=$fee/" /root/hemi/popmd.env
        sudo systemctl daemon-reload
        sudo systemctl restart hemid
        echo -e "${GREEN}Комиссия изменена на ${fee} сат/байт и нода перезапущена.${NC}"
    else
        echo -e "${RED}Файл настроек /root/hemi/popmd.env не найден. Проверьте путь и попробуйте снова.${NC}"
    fi
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
    echo -e "${YELLOW}Введите приватный ключ: ${NC}"
    read private_key
    echo "POPM_BTC_PRIVKEY=$private_key" | sudo tee -a /etc/environment
    source /etc/environment
    sudo systemctl daemon-reload
    sudo systemctl restart hemid
    echo -e "${GREEN}Кошелек успешно импортирован и нода перезапущена.${NC}"
}

# Путь к файлу с настройками
CONFIG_FILE="/root/hemi/popmd.env"

# URL API для получения комиссии
API_URL="https://mempool.space/testnet/api/v1/fees/mempool-blocks"

function fetch_and_update_fee {
    local fee=$1
    echo "Получено значение газа: ${fee}" >> nohup_gas.log

    if [[ -z "$fee" || ! "$fee" =~ ^[0-9]+$ ]]; then
        echo "Неверное значение газа: ${fee}. Операция отменена." >> nohup_gas.log
        return
    fi

    if [[ -f "$CONFIG_FILE" ]]; then
        sudo sed -i "s/POPM_STATIC_FEE=[0-9]*/POPM_STATIC_FEE=$fee/" "$CONFIG_FILE"
        sudo systemctl daemon-reload
        sudo systemctl restart hemid
        echo "Газ обновлен до ${fee} сат/байт и нода перезапущена." >> nohup_gas.log
    else
        echo "Файл настроек $CONFIG_FILE не найден." >> nohup_gas.log
    fi
}

function auto_adjust_gas {
    echo -e "${YELLOW}Введите максимальную допустимую комиссию (сат/байт): ${NC}"
    read max_fee

    # Проверка, что max_fee является числом
    if ! [[ "$max_fee" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Ошибка: Максимальная комиссия должна быть числом.${NC}"
        return
    fi

    echo -e "${GREEN}Максимальная комиссия установлена на ${max_fee} сат/байт.${NC}"

    # Создаём временный файл со скриптом
    TEMP_SCRIPT=$(mktemp)
    cat << EOF > $TEMP_SCRIPT
#!/bin/bash
$(declare -f fetch_and_update_fee)
CONFIG_FILE="$CONFIG_FILE"
MAX_FEE=$max_fee
while true; do
    fee=\$(curl -sSL "https://mempool.space/testnet/api/v1/fees/recommended" | jq '.fastestFee')
    echo "Полученная комиссия: \$fee, Максимальная комиссия: \$MAX_FEE" >> nohup_gas.log
    if [[ \$? -ne 0 || -z "\$fee" ]]; then
        echo "Ошибка получения комиссии. Пропуск проверки..." >> nohup_gas.log
        sleep 3600
        continue
    fi

    if (( fee > MAX_FEE )); then
        echo "Комиссия \$fee сат/байт превышает установленный максимум (\$MAX_FEE). Ждем снижения..." >> nohup_gas.log
    else
        echo "Обновляем газ до \$fee сат/байт..." >> nohup_gas.log
        fetch_and_update_fee "\$fee"
    fi
    echo "Ожидание 1 час до следующей проверки..." >> nohup_gas.log
    sleep 3600
done
EOF

    # Запускаем скрипт через nohup
    chmod +x $TEMP_SCRIPT
    nohup $TEMP_SCRIPT > nohup_gas.log 2>&1 &
    echo -e "${GREEN}Фоновая корректировка газа запущена через nohup. Логи пишутся в файл nohup_gas.log.${NC}"

    # Удаляем временный файл при завершении работы
    trap "rm -f $TEMP_SCRIPT" EXIT
    sleep 2
}

function view_current_fee {
    echo -e "${BLUE}Проверяем комиссию, установленную в ноде...${NC}"
    if [[ -f "$CONFIG_FILE" ]]; then
        fee=$(grep -oP 'POPM_STATIC_FEE=\K[0-9]+' "$CONFIG_FILE")
        if [[ ! -z "$fee" ]]; then
            echo -e "${GREEN}Текущая установленная комиссия: ${fee} сат/байт${NC}"
        else
            echo -e "${RED}Не удалось найти переменную POPM_STATIC_FEE в файле $CONFIG_FILE.${NC}"
        fi
    else
        echo -e "${RED}Файл настроек $CONFIG_FILE не найден.${NC}"
    fi
}

function main_menu {
    while true; do
        echo -e "${YELLOW}Выберите действие:${NC}"
        echo -e "${CYAN}1. Установка ноды${NC}"
        echo -e "${CYAN}2. Обновление ноды до версии 0.8.0 (08.12.2024)${NC}"
        echo -e "${CYAN}3. Рестарт ноды${NC}"
        echo -e "${CYAN}4. Изменить порт${NC}"
        echo -e "${CYAN}5. Изменить комиссию${NC}"
        echo -e "${CYAN}6. Просмотр логов${NC}"
        echo -e "${CYAN}7. Удаление ноды${NC}"
        echo -e "${CYAN}8. Импортировать кошелек${NC}"
        echo -e "${CYAN}9. Проверить версию ноды${NC}"
        echo -e "${CYAN}10. Перейти к другим нодам${NC}"
        echo -e "${CYAN}11. Автоматическая корректировка газа (hourly)${NC}"
        echo -e "${CYAN}12. Просмотр установленной комиссии${NC}"
        echo -e "${CYAN}13. Выход${NC}"
       
        echo -e "${YELLOW}Введите номер действия:${NC} "
        read choice
        case $choice in
            1) install_node ;;
            2) update_node ;;
            3) restart_node ;;
            4) change_port ;;
            5) change_fee ;;
            6) view_logs ;;
            7) remove_node ;;
            8) import_wallet ;;
            9) check_version ;;
            10) wget -q -O Ultimative_Node_Installer.sh https://raw.githubusercontent.com/ksydoruk1508/Ultimative_Node_Installer/main/Ultimative_Node_Installer.sh && sudo chmod +x Ultimative_Node_Installer.sh && ./Ultimative_Node_Installer.sh ;;
            11) auto_adjust_gas ;;
            12) view_current_fee ;;
            13) exit 0 ;;
            *) echo -e "${RED}Неверный выбор, попробуйте снова.${NC}" ;;
        esac
    done
}

main_menu
