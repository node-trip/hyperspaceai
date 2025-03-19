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

    # Создаем резервную копию ключа
    if [ -f "$HOME/hyperspace.pem" ]; then
        echo -e "${GREEN}Создаем резервную копию ключа...${NC}"
        cp $HOME/hyperspace.pem $HOME/hyperspace.pem.backup
        chmod 644 $HOME/hyperspace.pem.backup
    fi

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
    
    # Используем тот же метод, что и в отдельном скрипте
    POINTS_OUTPUT=$($HOME/.aios/aios-cli hive points 2>/dev/null)
    if [ ! -z "$POINTS_OUTPUT" ]; then
        CURRENT_POINTS=$(echo "$POINTS_OUTPUT" | grep "Points:" | awk '{print $2}')
        MULTIPLIER=$(echo "$POINTS_OUTPUT" | grep "Multiplier:" | awk '{print $2}')
        TIER=$(echo "$POINTS_OUTPUT" | grep "Tier:" | awk '{print $2}')
        UPTIME=$(echo "$POINTS_OUTPUT" | grep "Uptime:" | awk '{print $2}')
        ALLOCATION=$(echo "$POINTS_OUTPUT" | grep "Allocation:" | awk '{print $2}')
        
        echo -e "${GREEN}✅ Текущие поинты: $CURRENT_POINTS${NC}"
        echo -e "${GREEN}✅ Множитель: $MULTIPLIER${NC}"
        echo -e "${GREEN}✅ Тир: $TIER${NC}"
        echo -e "${GREEN}✅ Аптайм: $UPTIME${NC}"
        echo -e "${GREEN}✅ Аллокация: $ALLOCATION${NC}"
    else
        echo -e "${RED}❌ Не удалось получить значение поинтов${NC}"
    fi
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

restart_node() {
    echo -e "${YELLOW}Перезапуск ноды...${NC}"
    
    # Останавливаем процессы и удаляем файлы демона
    echo -e "${BLUE}Останавливаем процессы и очищаем временные файлы...${NC}"
    lsof -i :50051 | grep LISTEN | awk '{print $2}' | xargs -r kill -9
    rm -rf /tmp/aios*
    rm -rf $HOME/.aios/daemon*
    screen -X -S hyperspace quit
    sleep 5
    
    # Проверка и восстановление файла ключа
    if [ ! -f "$HOME/hyperspace.pem" ] && [ -f "$HOME/hyperspace.pem.backup" ]; then
        echo -e "${YELLOW}Основной файл ключа не найден. Восстанавливаем из резервной копии...${NC}"
        cp $HOME/hyperspace.pem.backup $HOME/hyperspace.pem
        chmod 644 $HOME/hyperspace.pem
    fi
    
    # Создаём screen сессию для запуска ноды
    echo -e "${BLUE}Создаём новую сессию screen...${NC}"
    screen -S hyperspace -dm
    screen -S hyperspace -p 0 -X stuff $'export PATH=$PATH:$HOME/.aios\naios-cli start\n'
    sleep 5
    
    # Аутентификация и подключение к Hive
    echo -e "${BLUE}Аутентификация в Hive...${NC}"
    # Проверяем, существует ли файл ключа
    export PATH=$PATH:$HOME/.aios
    if [ -f "$HOME/hyperspace.pem" ]; then
        echo -e "${GREEN}Импортируем ключ...${NC}"
        aios-cli hive import-keys ./hyperspace.pem
    else
        echo -e "${RED}Файл ключа не найден.${NC}"
        echo -e "${YELLOW}Требуется ввести приватный ключ.${NC}"
        echo -e "${YELLOW}Введите ваш приватный ключ (без пробелов и переносов строк):${NC}"
        read -r private_key
        echo "$private_key" > hyperspace.pem
        chmod 644 hyperspace.pem
        cp $HOME/hyperspace.pem $HOME/hyperspace.pem.backup
        chmod 644 $HOME/hyperspace.pem.backup
        aios-cli hive import-keys ./hyperspace.pem
    fi
    
    echo -e "${BLUE}Вход в систему Hive...${NC}"
    aios-cli hive login
    sleep 5
    
    echo -e "${BLUE}Подключаемся к Hive...${NC}"
    aios-cli hive connect
    sleep 5
    
    # Выбираем тир
    echo -e "${BLUE}Выбираем тир...${NC}"
    aios-cli hive select-tier 3
    sleep 3
    
    # Проверяем статус
    echo -e "${GREEN}Проверка статуса ноды после перезапуска:${NC}"
    aios-cli status
    
    echo -e "${GREEN}✅ Нода перезапущена!${NC}"
}

setup_restart_cron() {
    echo -e "${YELLOW}Настройка автоматического перезапуска ноды${NC}"
    
    # Проверяем наличие cron
    if ! command -v crontab &> /dev/null; then
        echo -e "${RED}crontab не установлен. Устанавливаем...${NC}"
        apt-get update && apt-get install -y cron
    fi
    
    # Проверяем, запущен ли cron
    if ! systemctl is-active --quiet cron; then
        echo -e "${YELLOW}Cron не запущен. Запускаем...${NC}"
        systemctl start cron
        systemctl enable cron
    fi
    
    echo -e "${GREEN}Выберите интервал перезапуска:${NC}"
    echo "1) Каждые 12 часов"
    echo "2) Каждые 24 часа (раз в сутки)"
    echo "3) Другой интервал (ввести вручную)"
    echo "4) Отключить автоматический перезапуск"
    echo "5) Вернуться в главное меню"
    
    read -p "Ваш выбор: " cron_choice
    
    # Создаем команду перезапуска
    RESTART_CMD="lsof -i :50051 | grep LISTEN | awk '{print \$2}' | xargs -r kill -9 && rm -rf /tmp/aios* && rm -rf \$HOME/.aios/daemon* && screen -X -S hyperspace quit && sleep 5 && (if [ ! -f \"\$HOME/hyperspace.pem\" ] && [ -f \"\$HOME/hyperspace.pem.backup\" ]; then cp \$HOME/hyperspace.pem.backup \$HOME/hyperspace.pem; fi) && screen -S hyperspace -dm && screen -S hyperspace -p 0 -X stuff 'export PATH=\$PATH:\$HOME/.aios\naios-cli start\n' && sleep 5 && export PATH=\$PATH:\$HOME/.aios && aios-cli hive import-keys ./hyperspace.pem && aios-cli hive login && sleep 5 && aios-cli hive connect && sleep 5 && aios-cli status"
    SCRIPT_PATH="$HOME/hyperspace_restart.sh"
    
    # Создаем скрипт перезапуска
    echo "#!/bin/bash" > $SCRIPT_PATH
    echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.aios" >> $SCRIPT_PATH
    echo "cd $HOME" >> $SCRIPT_PATH
    echo "$RESTART_CMD" >> $SCRIPT_PATH
    chmod +x $SCRIPT_PATH
    
    case $cron_choice in
        1)
            # Каждые 12 часов (в 00:00 и 12:00)
            CRON_EXPRESSION="0 0,12 * * *"
            ;;
        2)
            # Каждые 24 часа (в 00:00)
            CRON_EXPRESSION="0 0 * * *"
            ;;
        3)
            # Ввод пользовательского cron-выражения
            echo -e "${YELLOW}Введите cron-выражение (например, '0 */6 * * *' для перезапуска каждые 6 часов):${NC}"
            read -r CRON_EXPRESSION
            ;;
        4)
            # Удаляем существующие задания cron для перезапуска
            crontab -l | grep -v "hyperspace_restart.sh" | crontab -
            echo -e "${GREEN}Автоматический перезапуск отключен.${NC}"
            return
            ;;
        5)
            # Возврат в главное меню без изменений
            echo -e "${YELLOW}Возврат в главное меню без изменений настроек перезапуска...${NC}"
            return
            ;;
        *)
            echo -e "${RED}Неверный выбор. Используем значение по умолчанию (12 часов).${NC}"
            CRON_EXPRESSION="0 0,12 * * *"
            ;;
    esac
    
    # Обновляем crontab
    (crontab -l 2>/dev/null | grep -v "hyperspace_restart.sh" ; echo "$CRON_EXPRESSION $SCRIPT_PATH > $HOME/hyperspace_restart.log 2>&1") | crontab -
    
    echo -e "${GREEN}✅ Автоматический перезапуск настроен!${NC}"
    echo -e "${YELLOW}Расписание: $CRON_EXPRESSION${NC}"
    echo -e "${YELLOW}Скрипт перезапуска: $SCRIPT_PATH${NC}"
    echo -e "${YELLOW}Лог перезапуска: $HOME/hyperspace_restart.log${NC}"
}

smart_monitor() {
    echo -e "${GREEN}Настройка умного мониторинга ноды...${NC}"
    
    # Создаем скрипт мониторинга
    cat > $HOME/points_monitor_hyperspace.sh << 'EOL'
#!/bin/bash
LOG_FILE="$HOME/smart_monitor.log"
SCREEN_NAME="hyperspace"
LAST_POINTS="0"
NAN_COUNT=0
MAX_NAN_RETRIES=3
CHECK_INTERVAL=3600  # Проверка каждый час по умолчанию
FAIL_COUNT=0
MAX_FAIL_RETRIES=2  # Максимальное количество ошибок подряд

# Добавляем правильный PATH
export PATH="$PATH:$HOME/.aios"

log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S"): $1" >> $LOG_FILE
}

restart_node() {
    log_message "Начинаем процедуру перезапуска ноды..."
    
    # Используем тот же метод перезапуска, что и при ручном режиме
    lsof -i :50051 | grep LISTEN | awk '{print $2}' | xargs -r kill -9
    rm -rf /tmp/aios*
    rm -rf $HOME/.aios/daemon*
    screen -X -S hyperspace quit
    sleep 5
    
    # Проверяем и восстанавливаем ключ если нужно
    if [ ! -f "$HOME/hyperspace.pem" ] && [ -f "$HOME/hyperspace.pem.backup" ]; then
        cp $HOME/hyperspace.pem.backup $HOME/hyperspace.pem
    fi
    
    # Создаем новую сессию и запускаем ноду
    screen -S hyperspace -dm
    screen -S hyperspace -p 0 -X stuff "export PATH=$PATH:$HOME/.aios\naios-cli start\n"
    sleep 10
    
    # Импортируем ключи и подключаемся
    export PATH=$PATH:$HOME/.aios
    aios-cli hive import-keys ./hyperspace.pem
    aios-cli hive login
    sleep 10
    aios-cli hive connect
    sleep 5
    aios-cli hive select-tier 3
    sleep 5
    aios-cli status
    
    log_message "Процедура перезапуска завершена"
    sleep 60  # Увеличиваем время ожидания после перезапуска
}

check_node_health() {
    # Проверяем, запущен ли процесс aios
    if ! pgrep -f "aios" > /dev/null; then
        log_message "Процесс aios не найден, требуется перезапуск"
        return 1
    fi
    
    # Проверяем порт 50051
    if ! lsof -i :50051 | grep LISTEN > /dev/null; then
        log_message "Порт 50051 не прослушивается, требуется перезапуск"
        return 1
    fi
    
    # Проверяем доступность aios-cli
    if ! command -v aios-cli &> /dev/null; then
        log_message "aios-cli не найден в PATH"
        return 1
    fi
    
    # Проверяем подключение к Hive
    HIVE_STATUS=$($HOME/.aios/aios-cli hive connect 2>&1)
    if echo "$HIVE_STATUS" | grep -q "error"; then
        log_message "Проблема с подключением к Hive: $HIVE_STATUS"
        return 1
    fi
    
    return 0
}

while true; do
    # Проверяем здоровье ноды
    if ! check_node_health; then
        restart_node
        LAST_POINTS="0"
        NAN_COUNT=0
        FAIL_COUNT=0
        sleep 300  # Ждем 5 минут после перезапуска
        continue
    fi
    
    # Получаем текущие поинты
    POINTS_OUTPUT=$($HOME/.aios/aios-cli hive points 2>&1)
    
    # Проверяем наличие ошибок в выводе команды
    if echo "$POINTS_OUTPUT" | grep -q "Failed to fetch points" || echo "$POINTS_OUTPUT" | grep -q "error"; then
        FAIL_COUNT=$((FAIL_COUNT + 1))
        log_message "Ошибка при получении поинтов: $POINTS_OUTPUT (Попытка $FAIL_COUNT/$MAX_FAIL_RETRIES)"
        
        if [ $FAIL_COUNT -ge $MAX_FAIL_RETRIES ]; then
            log_message "Достигнуто максимальное количество ошибок подряд, перезапускаем ноду"
            restart_node
            FAIL_COUNT=0
            NAN_COUNT=0
            LAST_POINTS="0"
        else
            # Уменьшаем интервал проверки при ошибке
            sleep 300  # Проверяем через 5 минут
            continue
        fi
    else
        # Сбрасываем счетчик ошибок если получили нормальный ответ
        FAIL_COUNT=0
    fi
    
    # Извлекаем значение поинтов
    CURRENT_POINTS=$(echo "$POINTS_OUTPUT" | grep "Points:" | awk '{print $2}')
    
    # Проверяем, получили ли мы значение поинтов
    if [ -z "$CURRENT_POINTS" ]; then
        log_message "Не удалось получить значение поинтов, пропускаем итерацию"
        sleep 300
        continue
    fi
    
    # Логируем текущее состояние
    log_message "Проверка поинтов: Текущие: $CURRENT_POINTS, Предыдущие: $LAST_POINTS"
    
    # Обработка случая с NaN
    if [ "$CURRENT_POINTS" = "NaN" ]; then
        NAN_COUNT=$((NAN_COUNT + 1))
        log_message "Получено значение NaN ($NAN_COUNT/$MAX_NAN_RETRIES)"
        
        if [ $NAN_COUNT -ge $MAX_NAN_RETRIES ]; then
            log_message "Достигнуто максимальное количество NaN подряд, перезапускаем ноду"
            restart_node
            NAN_COUNT=0
            FAIL_COUNT=0
            LAST_POINTS="0"
        else
            # Уменьшаем интервал проверки при NaN
            sleep 600  # Проверяем через 10 минут
            continue
        fi
    else
        # Сбрасываем счетчик NaN если получили нормальное значение
        NAN_COUNT=0
    fi
    
    # Проверяем, изменились ли поинты (только если не NaN)
    if [ "$CURRENT_POINTS" != "NaN" ] && [ "$LAST_POINTS" != "NaN" ] && [ "$LAST_POINTS" != "0" ]; then
        if [ "$CURRENT_POINTS" = "$LAST_POINTS" ]; then
            log_message "Поинты не изменились (Текущие: $CURRENT_POINTS, Предыдущие: $LAST_POINTS). Запускаем перезапуск..."
            restart_node
        else
            log_message "Поинты обновились (Текущие: $CURRENT_POINTS, Предыдущие: $LAST_POINTS)"
        fi
    else
        log_message "Пропускаем сравнение поинтов (первый запуск или NaN)"
    fi
    
    # Обновляем последнее значение поинтов
    if [ "$CURRENT_POINTS" != "NaN" ]; then
        LAST_POINTS="$CURRENT_POINTS"
    fi
    
    sleep $CHECK_INTERVAL
done
EOL

    chmod +x $HOME/points_monitor_hyperspace.sh
    
    # Останавливаем существующий процесс мониторинга, если есть
    PIDS=$(ps aux | grep "[p]oints_monitor_hyperspace.sh" | awk '{print $2}')
    for PID in $PIDS; do
        kill -9 $PID
        echo -e "${YELLOW}Остановлен старый процесс мониторинга с PID $PID${NC}"
    done
    
    # Запускаем новый процесс мониторинга
    nohup $HOME/points_monitor_hyperspace.sh > $HOME/points_monitor_hyperspace.log 2>&1 &
    
    echo -e "${GREEN}✅ Умный мониторинг успешно настроен!${NC}"
    echo -e "${YELLOW}Лог мониторинга: $HOME/smart_monitor.log${NC}"
    echo -e "${YELLOW}Лог процесса: $HOME/points_monitor_hyperspace.log${NC}"
}

stop_monitor() {
    echo -e "${YELLOW}Останавливаем умный мониторинг...${NC}"
    
    PIDS=$(ps aux | grep "[p]oints_monitor_hyperspace.sh" | awk '{print $2}')
    if [ -z "$PIDS" ]; then
        echo -e "${RED}Процесс мониторинга не найден${NC}"
        return
    fi
    
    for PID in $PIDS; do
        kill -9 $PID
        echo -e "${GREEN}Остановлен процесс мониторинга с PID $PID${NC}"
    done
    
    echo -e "${GREEN}✅ Умный мониторинг остановлен${NC}"
}

check_monitor_status() {
    echo -e "${GREEN}Проверка состояния умного мониторинга...${NC}"
    
    # Проверяем процесс мониторинга
    MONITOR_PID=$(ps aux | grep "[p]oints_monitor_hyperspace.sh" | awk '{print $2}')
    if [ -z "$MONITOR_PID" ]; then
        echo -e "${RED}❌ Процесс мониторинга не запущен${NC}"
    else
        echo -e "${GREEN}✅ Процесс мониторинга активен (PID: $MONITOR_PID)${NC}"
    fi
    
    # Проверяем существование и размер лог-файла
    if [ -f "$HOME/smart_monitor.log" ]; then
        LAST_LOGS=$(tail -n 10 $HOME/smart_monitor.log)
        CURRENT_DATE=$(date +%Y-%m-%d)
        LAST_CHECK=$(echo "$LAST_LOGS" | grep "$CURRENT_DATE" | tail -n 1)
        
        echo -e "\n${YELLOW}Последние записи в логе:${NC}"
        echo "$LAST_LOGS"
        
        if [ ! -z "$LAST_CHECK" ]; then
            echo -e "\n${GREEN}✅ Мониторинг активно ведет логи${NC}"
        else
            echo -e "\n${RED}❌ Нет свежих записей в логе за сегодня${NC}"
            echo -e "${YELLOW}Проверка системной даты: $(date)${NC}"
        fi
    else
        echo -e "${RED}❌ Лог-файл мониторинга не найден${NC}"
    fi
    
    # Проверяем статус ноды
    echo -e "\n${YELLOW}Текущий статус ноды:${NC}"
    if pgrep -f "aios" > /dev/null; then
        echo -e "${GREEN}✅ Процесс aios запущен${NC}"
    else
        echo -e "${RED}❌ Процесс aios не запущен${NC}"
    fi
    
    if lsof -i :50051 | grep LISTEN > /dev/null; then
        echo -e "${GREEN}✅ Порт 50051 прослушивается${NC}"
    else
        echo -e "${RED}❌ Порт 50051 не прослушивается${NC}"
    fi
    
    # Создаем и запускаем скрипт проверки поинтов
    create_check_script
    echo -e "${YELLOW}Запускаем отдельный скрипт проверки поинтов...${NC}"
    $HOME/check_hyperspace.sh
}

create_check_script() {
    # Создаем отдельный скрипт для проверки статуса
    cat > $HOME/check_hyperspace.sh << 'EOL'
#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Текущая дата и время: $(date)${NC}"
echo -e "${YELLOW}Проверка PATH: $PATH${NC}"

# Проверяем поинты
echo -e "${YELLOW}Выполняем команду: $HOME/.aios/aios-cli hive points${NC}"
POINTS_OUTPUT=$($HOME/.aios/aios-cli hive points 2>&1)
echo -e "${YELLOW}Полный вывод команды:${NC}\n$POINTS_OUTPUT"

if echo "$POINTS_OUTPUT" | grep -q "Points:"; then
    CURRENT_POINTS=$(echo "$POINTS_OUTPUT" | grep "Points:" | awk '{print $2}')
    MULTIPLIER=$(echo "$POINTS_OUTPUT" | grep "Multiplier:" | awk '{print $2}')
    TIER=$(echo "$POINTS_OUTPUT" | grep "Tier:" | awk '{print $2}')
    UPTIME=$(echo "$POINTS_OUTPUT" | grep "Uptime:" | awk '{print $2}')
    ALLOCATION=$(echo "$POINTS_OUTPUT" | grep "Allocation:" | awk '{print $2}')
    
    echo -e "${GREEN}✅ Текущие поинты: $CURRENT_POINTS${NC}"
    echo -e "${GREEN}✅ Множитель: $MULTIPLIER${NC}"
    echo -e "${GREEN}✅ Тир: $TIER${NC}"
    echo -e "${GREEN}✅ Аптайм: $UPTIME${NC}"
    echo -e "${GREEN}✅ Аллокация: $ALLOCATION${NC}"
else
    echo -e "${RED}❌ Не удалось получить значение поинтов${NC}"
    echo -e "${YELLOW}Проверка статуса подключения:${NC}"
    $HOME/.aios/aios-cli status
    echo -e "${YELLOW}Проверка подключения к Hive:${NC}"
    $HOME/.aios/aios-cli hive connect
    echo -e "${YELLOW}Проверка логина в Hive:${NC}"
    $HOME/.aios/aios-cli hive login
fi
EOL
    chmod +x $HOME/check_hyperspace.sh
}

while true; do
    print_header
    echo -e "${GREEN}Выберите действие:${NC}"
    echo "1) Установить ноду"
    echo "2) Проверить логи"
    echo "3) Проверить пойнты"
    echo "4) Проверить статус"
    echo "5) Удалить ноду"
    echo "6) Перезапустить ноду"
    echo "7) Включить умный мониторинг"
    echo "8) Выключить умный мониторинг"
    echo "9) Проверить состояние мониторинга"
    echo "0) Выход"
    
    read -p "Ваш выбор: " choice

    case $choice in
        1) install_node ;;
        2) check_logs ;;
        3) check_points ;;
        4) check_status ;;
        5) remove_node ;;
        6) restart_node ;;
        7) smart_monitor ;;
        8) stop_monitor ;;
        9) check_monitor_status ;;
        0) exit 0 ;;
        *) echo -e "${RED}Неверный выбор${NC}" ;;
    esac

    read -p "Нажмите Enter для продолжения..."
done
