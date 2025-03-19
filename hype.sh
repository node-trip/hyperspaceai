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
    sudo apt install -y nano screen curl wget
    cd $HOME
    rm -rf $HOME/.cache/hyperspace/models/*
    sleep 5

    echo -e "${GREEN}🚀 Установка AIOS...${NC}"
    
    # Создаем директорию .aios если её нет
    mkdir -p $HOME/.aios

    # Определяем архитектуру системы
    ARCH=$(uname -m)
    echo -e "${YELLOW}Определена архитектура: $ARCH${NC}"
    
    # Выбираем соответствующий URL в зависимости от архитектуры
    if [ "$ARCH" = "x86_64" ]; then
        # URL для x86_64 (стандартные Intel/AMD процессоры)
        AIOS_URL="https://github.com/second-state/aios/releases/download/v0.1.6/aios-cli-linux-amd64"
    elif [ "$ARCH" = "aarch64" ]; then
        # URL для ARM64 (например, AWS Graviton)
        AIOS_URL="https://github.com/second-state/aios/releases/download/v0.1.6/aios-cli-linux-arm64"
    else
        echo -e "${RED}❌ Неподдерживаемая архитектура: $ARCH${NC}"
        return 1
    fi
    
    # Загружаем aios-cli напрямую из репозитория с явным указанием версии
    echo -e "${YELLOW}Загрузка aios-cli с URL: $AIOS_URL${NC}"
    curl -L $AIOS_URL -o $HOME/.aios/aios-cli || wget -O $HOME/.aios/aios-cli $AIOS_URL
    
    # Проверяем размер файла
    FILE_SIZE=$(stat -c%s "$HOME/.aios/aios-cli")
    echo -e "${YELLOW}Размер загруженного файла: $FILE_SIZE байт${NC}"
    
    # Если файл слишком маленький, вероятно произошла ошибка
    if [ $FILE_SIZE -lt 1000000 ]; then  # Ожидаем файл размером более 1MB
        echo -e "${RED}❌ Подозрительно маленький размер файла. Проверка содержимого:${NC}"
        cat $HOME/.aios/aios-cli
        echo ""
        echo -e "${RED}❌ Попробуем другой метод установки...${NC}"
        
        # Пробуем использовать официальный установщик
        echo -e "${YELLOW}Пробуем официальный установщик...${NC}"
        curl -s https://download.hyper.space/api/install | bash
        
        # Проверяем, создался ли aios-cli после запуска установщика
        if [ -f "$HOME/.aios/aios-cli" ]; then
            FILE_SIZE=$(stat -c%s "$HOME/.aios/aios-cli")
            echo -e "${YELLOW}Размер файла после официального установщика: $FILE_SIZE байт${NC}"
            
            if [ $FILE_SIZE -lt 1000000 ]; then
                echo -e "${RED}❌ Установка не удалась. Файл слишком маленький.${NC}"
                return 1
            fi
        else
            echo -e "${RED}❌ Файл aios-cli не найден после запуска установщика.${NC}"
            return 1
        fi
    fi

    # Делаем файл исполняемым
    chmod +x $HOME/.aios/aios-cli

    # Проверяем исполняемость файла
    echo -e "${YELLOW}Проверка типа файла:${NC}"
    file $HOME/.aios/aios-cli

    # Добавляем путь в .bashrc
    if ! grep -q "export PATH=\$PATH:\$HOME/.aios" ~/.bashrc; then
        echo 'export PATH=$PATH:$HOME/.aios' >> ~/.bashrc
    fi

    # Обновляем PATH в текущей сессии
    export PATH=$PATH:$HOME/.aios
    source ~/.bashrc

    # Проверяем, что aios-cli доступен
    if ! $HOME/.aios/aios-cli --version &> /dev/null; then
        echo -e "${RED}❌ aios-cli не работает. Проверяем состояние...${NC}"
        echo -e "${YELLOW}Текущий PATH: $PATH${NC}"
        echo -e "${YELLOW}Содержимое директории .aios:${NC}"
        ls -la $HOME/.aios
        echo -e "${YELLOW}Проверяем права доступа:${NC}"
        ls -l $HOME/.aios/aios-cli
        return 1
    else
        echo -e "${GREEN}✅ aios-cli работает корректно${NC}"
    fi

    echo -e "${GREEN}Запуск демона...${NC}"
    screen -S hyperspace -dm
    screen -S hyperspace -p 0 -X stuff $'$HOME/.aios/aios-cli start\n'
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

    $HOME/.aios/aios-cli hive import-keys ./hyperspace.pem

    echo -e "${GREEN}🔑 Вход в систему...${NC}"
    $HOME/.aios/aios-cli hive login
    sleep 5

    echo -e "${GREEN}Загрузка модели...${NC}"
    $HOME/.aios/aios-cli models add hf:second-state/Qwen1.5-1.8B-Chat-GGUF:Qwen1.5-1.8B-Chat-Q4_K_M.gguf

    echo -e "${GREEN}Подключение к системе...${NC}"
    $HOME/.aios/aios-cli hive connect
    $HOME/.aios/aios-cli hive select-tier 3

    echo -e "${GREEN}🔍 Проверка статуса ноды...${NC}"
    $HOME/.aios/aios-cli status

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
    
    # Максимальное количество попыток подключения к Hive
    local MAX_HIVE_RETRIES=5
    local hive_retry=0
    local success=false
    
    # Останавливаем процессы и удаляем файлы демона
    echo -e "${BLUE}Останавливаем процессы и очищаем временные файлы...${NC}"
    pkill -f aios-cli
    pkill -f aios
    lsof -i :50051 | grep LISTEN | awk '{print $2}' | xargs -r kill -9
    
    # Принудительно останавливаем ВСЕ сессии с именем hyperspace
    echo -e "${BLUE}Закрываем все существующие сессии screen...${NC}"
    screen -wipe >/dev/null 2>&1
    screen -ls | grep hyperspace | cut -d. -f1 | xargs -r kill -9
    screen -X -S hyperspace quit >/dev/null 2>&1
    
    rm -rf /tmp/aios*
    rm -rf $HOME/.aios/daemon*
    sleep 5
    
    # Проверка и восстановление файла ключа
    if [ ! -f "$HOME/hyperspace.pem" ] && [ -f "$HOME/hyperspace.pem.backup" ]; then
        echo -e "${YELLOW}Основной файл ключа не найден. Восстанавливаем из резервной копии...${NC}"
        cp $HOME/hyperspace.pem.backup $HOME/hyperspace.pem
        chmod 644 $HOME/hyperspace.pem
    fi
    
    # Цикл попыток запуска и подключения
    while [ $hive_retry -lt $MAX_HIVE_RETRIES ] && [ "$success" = false ]; do
        hive_retry=$((hive_retry + 1))
        echo -e "${BLUE}Попытка запуска и подключения ($hive_retry из $MAX_HIVE_RETRIES)...${NC}"
        
        # Проверяем, что нет активных сессий hyperspace перед созданием новой
        echo -e "${BLUE}Проверка наличия существующих сессий screen...${NC}"
        if screen -ls | grep -q hyperspace; then
            echo -e "${YELLOW}Обнаружены существующие сессии. Закрываем их...${NC}"
            screen -ls | grep hyperspace | cut -d. -f1 | xargs -r kill -9
            sleep 2
        fi
        
        # Создаём screen сессию для запуска ноды
        echo -e "${BLUE}Создаём новую сессию screen...${NC}"
        screen -dmS hyperspace
        sleep 2
        
        # Проверяем, что сессия успешно создана
        if ! screen -ls | grep -q hyperspace; then
            echo -e "${RED}Не удалось создать сессию screen. Повторная попытка...${NC}"
            sleep 3
            continue
        fi
        
        # Отправляем команды в screen
        screen -S hyperspace -p 0 -X stuff $'export PATH=$PATH:$HOME/.aios\naios-cli start\n'
        sleep 15
        
        # Проверяем, запустился ли демон
        if ! pgrep -f "aios" > /dev/null; then
            echo -e "${RED}Демон не запустился. Повторная попытка...${NC}"
            screen -X -S hyperspace quit
            sleep 5
            continue
        fi
        
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
        LOGIN_RESULT=$(aios-cli hive login 2>&1)
        if echo "$LOGIN_RESULT" | grep -q "Failed to authenticate"; then
            echo -e "${YELLOW}Ошибка аутентификации. Ожидаем 15 секунд перед повторной попыткой...${NC}"
            screen -X -S hyperspace quit
            sleep 15
            continue
        fi
        sleep 10
        
        echo -e "${BLUE}Подключаемся к Hive...${NC}"
        CONNECT_RESULT=$(aios-cli hive connect 2>&1)
        if echo "$CONNECT_RESULT" | grep -q "Failed to connect"; then
            echo -e "${YELLOW}Ошибка подключения к Hive. Ожидаем 15 секунд перед повторной попыткой...${NC}"
            sleep 15
            continue
        fi
        sleep 10
        
        # Выбираем тир
        echo -e "${BLUE}Выбираем тир...${NC}"
        TIER_RESULT=$(aios-cli hive select-tier 3 2>&1)
        if echo "$TIER_RESULT" | grep -q "Failed to select tier"; then
            echo -e "${YELLOW}Ошибка выбора тира. Пробуем еще раз...${NC}"
            sleep 5
            aios-cli hive select-tier 3
        fi
        sleep 5
        
        # Проверяем статус
        echo -e "${GREEN}Проверка статуса ноды после перезапуска:${NC}"
        STATUS_RESULT=$(aios-cli status 2>&1)
        echo "$STATUS_RESULT"
        
        # Проверяем, что демон запущен
        if echo "$STATUS_RESULT" | grep -q "Daemon running"; then
            # Проверяем, что можем получить поинты (признак успешного подключения)
            POINTS_RESULT=$(aios-cli hive points 2>&1)
            if ! echo "$POINTS_RESULT" | grep -q "Failed"; then
                success=true
                echo -e "${GREEN}✅ Подключение к Hive успешно установлено!${NC}"
            else
                echo -e "${YELLOW}Не удалось получить поинты. Будет выполнена еще одна попытка...${NC}"
            fi
        fi
        
        if [ "$success" = false ]; then
            # Если попытка неудачна, закрываем текущую сессию screen перед следующей попыткой
            echo -e "${YELLOW}Закрываем неудачную сессию screen...${NC}"
            screen -X -S hyperspace quit >/dev/null 2>&1
            
            echo -e "${YELLOW}Попытка $hive_retry не удалась. Ожидаем 20 секунд...${NC}"
            sleep 20
        fi
    done
    
    if [ "$success" = true ]; then
        echo -e "${GREEN}✅ Нода успешно перезапущена!${NC}"
    else
        # Окончательная очистка в случае неудачи
        echo -e "${RED}⚠️ Нода перезапущена, но есть проблемы с подключением к Hive.${NC}"
        echo -e "${YELLOW}Рекомендуется проверить состояние ноды через некоторое время.${NC}"
    fi
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
RESTART_COUNT=0
MAX_RESTART_COUNT=5  # Максимальное количество перезапусков в течение дня
RESTART_TIME=$(date +%s)  # Время последнего перезапуска
HIVE_DOWN_COUNT=0
MAX_HIVE_DOWN=3  # Максимальное количество ошибок Hive, прежде чем перезапустить

# Добавляем правильный PATH
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$HOME/.aios"

log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S"): $1" >> $LOG_FILE
}

# Функция для закрытия всех сессий screen с именем hyperspace
kill_all_screens() {
    log_message "Закрываем все существующие сессии screen hyperspace..."
    screen -wipe >/dev/null 2>&1
    screen -ls | grep hyperspace | cut -d. -f1 | xargs -r kill -9 >/dev/null 2>&1
    screen -X -S hyperspace quit >/dev/null 2>&1
    sleep 2
}

wait_for_daemon() {
    local tries=0
    local max_tries=30
    
    while [ $tries -lt $max_tries ]; do
        if $HOME/.aios/aios-cli --version &>/dev/null; then
            log_message "Демон успешно запущен после $tries попыток"
            return 0
        fi
        log_message "Ожидание запуска демона (попытка $tries/$max_tries)..."
        sleep 10
        tries=$((tries + 1))
    done
    
    log_message "Не удалось дождаться запуска демона после $max_tries попыток"
    return 1
}

ensure_hive_connection() {
    local retry=0
    local max_retries=3
    
    while [ $retry -lt $max_retries ]; do
        # Проверяем подключение к Hive
        log_message "Проверка подключения к Hive (попытка $((retry+1))/$max_retries)..."
        
        # Пробуем получить статус точек
        local connect_result=$($HOME/.aios/aios-cli hive connect 2>&1)
        local points_result=$($HOME/.aios/aios-cli hive points 2>&1)
        
        if ! echo "$points_result" | grep -q "Failed"; then
            log_message "Успешное подключение к Hive"
            return 0
        fi
        
        log_message "Проблема подключения к Hive. Попытка переподключения..."
        $HOME/.aios/aios-cli hive login
        sleep 5
        $HOME/.aios/aios-cli hive connect
        sleep 5
        
        retry=$((retry+1))
        if [ $retry -lt $max_retries ]; then
            log_message "Ожидание перед повторной попыткой ($retry/$max_retries)..."
            sleep 30
        fi
    done
    
    log_message "Не удалось установить подключение к Hive после $max_retries попыток"
    return 1
}

restart_node() {
    log_message "Начинаем процедуру перезапуска ноды..."
    
    # Проверяем, не слишком ли часто перезапускаем
    current_time=$(date +%s)
    time_diff=$((current_time - RESTART_TIME))
    
    # Если прошло менее 24 часов с последнего перезапуска
    if [ $time_diff -lt 86400 ]; then
        RESTART_COUNT=$((RESTART_COUNT + 1))
        if [ $RESTART_COUNT -gt $MAX_RESTART_COUNT ]; then
            log_message "ВНИМАНИЕ: Слишком много перезапусков за день ($RESTART_COUNT). Ожидаем 1 час перед следующей попыткой."
            sleep 3600
            RESTART_COUNT=0
        fi
    else
        # Сбрасываем счетчик раз в день
        RESTART_COUNT=1
    fi
    
    RESTART_TIME=$(date +%s)
    
    # Максимальное количество попыток подключения к Hive
    local MAX_HIVE_RETRIES=3
    local hive_retry=0
    local success=false
    
    # Полная остановка
    log_message "Остановка всех процессов..."
    pkill -f aios-cli
    pkill -f aios
    lsof -i :50051 | grep LISTEN | awk '{print $2}' | xargs -r kill -9
    kill_all_screens
    sleep 5
    
    # Очистка временных файлов и демона
    log_message "Очистка временных файлов..."
    rm -rf /tmp/aios*
    rm -rf $HOME/.aios/daemon*
    sleep 3
    
    # Проверяем и восстанавливаем ключ если нужно
    if [ ! -f "$HOME/hyperspace.pem" ] && [ -f "$HOME/hyperspace.pem.backup" ]; then
        log_message "Восстановление ключа из резервной копии..."
        cp $HOME/hyperspace.pem.backup $HOME/hyperspace.pem
        chmod 644 $HOME/hyperspace.pem
    fi
    
    # Проверяем наличие ключа
    if [ ! -f "$HOME/hyperspace.pem" ]; then
        log_message "ОШИБКА: Файл ключа не найден! Перезапуск невозможен."
        return 1
    fi
    
    # Цикл попыток запуска и подключения
    while [ $hive_retry -lt $MAX_HIVE_RETRIES ] && [ "$success" = false ]; do
        hive_retry=$((hive_retry + 1))
        log_message "Попытка запуска и подключения ($hive_retry из $MAX_HIVE_RETRIES)..."
        
        # Проверяем, нет ли уже запущенных screen-сессий
        if screen -ls | grep -q hyperspace; then
            log_message "Удаление существующих screen-сессий hyperspace..."
            kill_all_screens
        fi
        
        # Создаем новую сессию и запускаем ноду
        log_message "Запуск новой сессии screen..."
        screen -dmS hyperspace
        sleep 2
        
        # Проверяем, создана ли сессия
        if ! screen -ls | grep -q hyperspace; then
            log_message "Не удалось создать screen-сессию. Повторная попытка..."
            sleep 3
            continue
        fi
        
        screen -S hyperspace -p 0 -X stuff "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$HOME/.aios\necho 'Запуск AIOS...'\n$HOME/.aios/aios-cli start\n"
        sleep 20
        
        # Ждем запуска демона
        log_message "Ожидаем запуск демона..."
        if ! wait_for_daemon; then
            log_message "ОШИБКА: Демон не запустился, пробуем еще раз..."
            kill_all_screens
            continue
        fi
        
        # Проверяем статус демона
        DAEMON_STATUS=$($HOME/.aios/aios-cli status 2>&1)
        log_message "Статус демона: $DAEMON_STATUS"
        
        if ! echo "$DAEMON_STATUS" | grep -q "Daemon running"; then
            log_message "Демон не запущен, повторная попытка..."
            kill_all_screens
            continue
        fi
        
        # Импортируем ключи и подключаемся
        log_message "Импорт ключей..."
        $HOME/.aios/aios-cli hive import-keys ./hyperspace.pem
        
        log_message "Вход в аккаунт Hive..."
        LOGIN_OUTPUT=$($HOME/.aios/aios-cli hive login 2>&1)
        log_message "Результат входа: $LOGIN_OUTPUT"
        sleep 10
        
        log_message "Подключение к Hive..."
        CONNECT_OUTPUT=$($HOME/.aios/aios-cli hive connect 2>&1)
        log_message "Результат подключения: $CONNECT_OUTPUT"
        
        if echo "$CONNECT_OUTPUT" | grep -q "Failed to connect"; then
            log_message "Не удалось подключиться к Hive, возможно сервис временно недоступен. Ожидаем 30 секунд..."
            sleep 30
            continue
        fi
        
        sleep 5
        
        log_message "Установка тира..."
        TIER_OUTPUT=$($HOME/.aios/aios-cli hive select-tier 3 2>&1)
        log_message "Результат установки тира: $TIER_OUTPUT"
        sleep 5
        
        # Проверяем поинты, чтобы убедиться в успешном подключении
        POINTS_OUTPUT=$($HOME/.aios/aios-cli hive points 2>&1)
        if ! echo "$POINTS_OUTPUT" | grep -q "Failed"; then
            log_message "Успешное подключение к Hive, поинты получены"
            success=true
        else
            log_message "Не удалось получить поинты. Попытка $hive_retry не удалась."
            
            if [ $hive_retry -lt $MAX_HIVE_RETRIES ]; then
                log_message "Ожидаем 30 секунд перед следующей попыткой..."
                kill_all_screens
                sleep 30
            fi
        fi
    done
    
    if [ "$success" = true ]; then
        log_message "Нода успешно перезапущена и подключена к Hive!"
        HIVE_DOWN_COUNT=0  # Сбрасываем счетчик проблем с Hive
    else
        log_message "⚠️ Нода перезапущена, но есть проблемы с подключением к Hive"
        log_message "Проверьте состояние ноды позже"
    fi
    
    log_message "Процедура перезапуска завершена"
    sleep 120  # Увеличиваем время ожидания после перезапуска до 2 минут
}

check_node_health() {
    # Проверяем, запущен ли процесс aios
    if ! pgrep -f "aios-cli start" > /dev/null && ! pgrep -f "aios" > /dev/null; then
        log_message "Процесс aios не найден, требуется перезапуск"
        return 1
    fi
    
    # Проверяем порт 50051
    if ! lsof -i :50051 | grep LISTEN > /dev/null; then
        log_message "Порт 50051 не прослушивается, требуется перезапуск"
        return 1
    fi
    
    # Проверяем доступность aios-cli и его версию
    AIOS_VERSION=$($HOME/.aios/aios-cli --version 2>&1)
    if [ $? -ne 0 ]; then
        log_message "Не удалось получить версию aios-cli: $AIOS_VERSION"
        return 1
    fi
    
    # Проверяем статус демона
    DAEMON_STATUS=$($HOME/.aios/aios-cli status 2>&1)
    if echo "$DAEMON_STATUS" | grep -q "Daemon not running"; then
        log_message "Демон не запущен: $DAEMON_STATUS"
        return 1
    fi
    
    # Все проверки пройдены успешно
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
    log_message "Вывод команды points: $POINTS_OUTPUT"
    
    # Проверяем наличие ошибок в выводе команды
    if echo "$POINTS_OUTPUT" | grep -q "Failed to fetch points" || echo "$POINTS_OUTPUT" | grep -q "error"; then
        FAIL_COUNT=$((FAIL_COUNT + 1))
        HIVE_DOWN_COUNT=$((HIVE_DOWN_COUNT + 1))
        
        log_message "Ошибка при получении поинтов: $POINTS_OUTPUT (Попытка $FAIL_COUNT/$MAX_FAIL_RETRIES, Hive Down: $HIVE_DOWN_COUNT/$MAX_HIVE_DOWN)"
        
        # Если Hive сервис недоступен много раз подряд, считаем это серьезной проблемой
        if [ $HIVE_DOWN_COUNT -ge $MAX_HIVE_DOWN ]; then
            log_message "Серьезные проблемы с подключением к Hive, выполняем полный перезапуск..."
            restart_node
            FAIL_COUNT=0
            NAN_COUNT=0
            HIVE_DOWN_COUNT=0
            LAST_POINTS="0"
            sleep 300
            continue
        fi
        
        if [ $FAIL_COUNT -ge $MAX_FAIL_RETRIES ]; then
            log_message "Достигнуто максимальное количество ошибок подряд, перезапускаем ноду"
            restart_node
            FAIL_COUNT=0
            NAN_COUNT=0
            LAST_POINTS="0"
        else
            # Пробуем переподключиться к Hive без полного перезапуска
            log_message "Пробуем переподключиться к Hive без полного перезапуска..."
            $HOME/.aios/aios-cli hive connect
            sleep 5
            
            # Проверяем, помогло ли переподключение
            RECONNECT_POINTS=$($HOME/.aios/aios-cli hive points 2>&1)
            if ! echo "$RECONNECT_POINTS" | grep -q "Failed"; then
                log_message "Переподключение помогло, поинты получены"
                POINTS_OUTPUT=$RECONNECT_POINTS
                FAIL_COUNT=0
                HIVE_DOWN_COUNT=0
            else
                log_message "Переподключение не помогло, ожидаем следующей проверки"
                # Уменьшаем интервал проверки при ошибке
                sleep 300  # Проверяем через 5 минут
                continue
            fi
        fi
    else
        # Сбрасываем счетчики ошибок если получили нормальный ответ
        FAIL_COUNT=0
        HIVE_DOWN_COUNT=0
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
    
    # Перезапускаем ноду перед запуском мониторинга
    echo -e "${YELLOW}Выполняем перезапуск ноды перед запуском мониторинга...${NC}"
    restart_node
    
    # Запускаем новый процесс мониторинга
    nohup $HOME/points_monitor_hyperspace.sh > $HOME/points_monitor_hyperspace.log 2>&1 &
    NEW_PID=$!
    
    echo -e "${GREEN}✅ Умный мониторинг успешно настроен! (PID: $NEW_PID)${NC}"
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
