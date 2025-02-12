#!/bin/bash

# Функции для цветного вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
YELLOW='\033[1;33m'

print_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        HyperSpace Node Manager         ║${NC}"
    echo -e "${BLUE}║        Telegram: @nodetrip             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
}

create_key_file() {
    echo -e "${GREEN}Вставка приватного ключа${NC}"
    echo -e "${BLUE}Пожалуйста, вставьте ваш приватный ключ (без пробелов и переносов строк):${NC}"
    read -r private_key
    
    if [ -z "$private_key" ]; then
        echo -e "${RED}Ошибка: Приватный ключ не может быть пустым${NC}"
        return 1
    fi
    
    # Сохраняем ключ в файл
    echo "$private_key" > hyperspace.pem
    chmod 644 hyperspace.pem
    
    echo -e "${GREEN}✅ Приватный ключ успешно сохранен в файл hyperspace.pem${NC}"
    return 0
}

install_node() {
    echo -e "${GREEN}Обновление системы...${NC}"
    sudo apt update && sudo apt upgrade -y
    cd $HOME
    rm -rf $HOME/.cache/hyperspace/models/*
    sleep 5

    echo -e "${GREEN}🚀 Установка HyperSpace CLI...${NC}"
    while true; do
        curl -s https://download.hyper.space/api/install | bash | tee /root/hyperspace_install.log

        if ! grep -q "Failed to parse version from release data." /root/hyperspace_install.log; then
            echo -e "${GREEN}✅ HyperSpace CLI установлен успешно!${NC}"
            break
        else
            echo -e "${RED}❌ Установка не удалась. Повторная попытка через 5 секунд...${NC}"
            sleep 5
        fi
    done

    echo -e "${GREEN}🚀 Установка AIOS...${NC}"
    echo 'export PATH=$PATH:$HOME/.aios' >> ~/.bashrc
    export PATH=$PATH:$HOME/.aios
    source ~/.bashrc

    screen -S hyperspace -dm
    screen -S hyperspace -p 0 -X stuff $'aios-cli start\n'
    sleep 5

    echo -e "${GREEN}Создание файла приватного ключа...${NC}"
    echo -e "${YELLOW}Откроется редактор nano. Вставьте ваш приватный ключ и сохраните файл (CTRL+X, Y, Enter)${NC}"
    sleep 2
    nano hyperspace.pem

    aios-cli hive import-keys ./hyperspace.pem

    echo -e "${GREEN}🔑 Вход в систему...${NC}"
    aios-cli hive login
    sleep 5

    echo -e "${GREEN}Загрузка модели...${NC}"
    aios-cli models add hf:second-state/Qwen1.5-1.8B-Chat-GGUF:Qwen1.5-1.8B-Chat-Q4_K_M.gguf

    echo -e "${GREEN}Подключение к системе...${NC}"
    aios-cli hive connect
    aios-cli hive select-tier 3

    echo -e "${GREEN}🔍 Проверка статуса ноды...${NC}"
    aios-cli status

    echo -e "${GREEN}✅ Установка завершена!${NC}"
}

check_logs() {
    echo -e "${GREEN}Проверка логов ноды:${NC}"
    screen -r hyperspace
}

check_points() {
    echo -e "${GREEN}Проверка баланса пойнтов:${NC}"
    export PATH=$PATH:$HOME/.aios
    
    if ! pgrep -f "aios-cli" > /dev/null; then
        echo -e "${YELLOW}Демон не запущен. Запускаем...${NC}"
        aios-cli start &
        sleep 5
    fi
    
    aios-cli hive points
}

check_status() {
    echo -e "${GREEN}Проверка статуса ноды:${NC}"
    export PATH=$PATH:$HOME/.aios
    
    if ! pgrep -f "aios-cli" > /dev/null; then
        echo -e "${YELLOW}Демон не запущен. Запускаем...${NC}"
        aios-cli start &
        sleep 5
    fi
    
    aios-cli status
}

remove_node() {
    echo -e "${RED}Удаление ноды...${NC}"
    screen -X -S hyperspace quit
    rm -rf $HOME/.aios
    rm -rf $HOME/.cache/hyperspace
    rm -f hyperspace.pem
    echo -e "${GREEN}Нода успешно удалена${NC}"
}

while true; do
    print_header
    echo -e "${GREEN}Выберите действие:${NC}"
    echo "1) Установить ноду"
    echo "2) Проверить логи"
    echo "3) Проверить пойнты"
    echo "4) Проверить статус"
    echo "5) Удалить ноду"
    echo "0) Выход"
    
    read -p "Ваш выбор: " choice

    case $choice in
        1) install_node ;;
        2) check_logs ;;
        3) check_points ;;
        4) check_status ;;
        5) remove_node ;;
        0) exit 0 ;;
        *) echo -e "${RED}Неверный выбор${NC}" ;;
    esac

    read -p "Нажмите Enter для продолжения..."
done
