#!/bin/bash

# Запрашиваем SSH пароль
read -s -p "Введите SSH пароль: " SSH_PASS
echo

# Определяем переменные
NEW_USER="hadoop"

# Определяем IP-адреса целевых нод
IP_NODES=(
    # "192.168.1.30"
    # "192.168.1.31"
    "192.168.1.32"
    "192.168.1.33"
)

# Формируем массив USER_NODES на основе IP_NODES
USER_NODES=()
for IP in "${IP_NODES[@]}"; do
    USER_NODES+=("$NEW_USER@$IP")
done

HADOOP_VERSION="3.4.0"
HADOOP_TAR="hadoop-$HADOOP_VERSION.tar.gz"
HADOOP_URL="https://dlcdn.apache.org/hadoop/common/hadoop-$HADOOP_VERSION/$HADOOP_TAR"

# Функция для установки утилит
install_utilities() {
    for utility in "$@"; do
        if ! command -v "$utility" &> /dev/null; then
            echo "$utility не установлен. Устанавливаем..."
            echo "$SSH_PASS" | sudo -S apt update -y
            echo "$SSH_PASS" | sudo -S apt install -y "$utility"
        else
            echo "$utility уже установлен."
        fi
    done
}

# Установка необходимых утилит
install_utilities sshpass wget tar

# Подключаемся к первой ноде и скачиваем Hadoop
FIRST_NODE="${USER_NODES[0]}"
echo "Подключаемся к $FIRST_NODE и скачиваем Hadoop..."

sshpass -p "$SSH_PASS" ssh "$FIRST_NODE" bash << EOF
    echo "Скачиваем Hadoop..."
    wget "$HADOOP_URL"

    # Проверяем, успешно ли скачан архив
    if [[ -f "$HADOOP_TAR" ]]; then
        echo "Hadoop успешно скачан на $FIRST_NODE."
    else
        echo "Ошибка при скачивании Hadoop. Завершаем выполнение."
        exit 1
    fi
EOF

# Копируем архив на остальные ноды
for NODE in "${USER_NODES[@]:1}"; do
    echo "Копируем Hadoop на $NODE..."
    sshpass -p "$SSH_PASS" scp "$FIRST_NODE:$HADOOP_TAR" "$NODE:~"

    echo "Распаковываем Hadoop на $NODE..."
    sshpass -p "$SSH_PASS" ssh "$NODE" bash << EOF
        tar -xvzf ~/$HADOOP_TAR
        echo "Hadoop успешно установлен на $NODE."
        echo "*****************************************************************************"
        echo
EOF
done

echo "Скрипт выполнен успешно."