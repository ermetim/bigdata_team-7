#!/bin/bash

# Запрашиваем SSH пароль
read -s -p "Введите SSH пароль: " SSH_PASS
echo

# Определяем переменные
NEW_USER="hadoop"

# Определяем IP-адреса целевых нод
IP_NODES=(
    "192.168.1.30"
    "192.168.1.31"
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

# Директория с конфигурационными файлами
CONFIG_DIR="bigdata_team-7/config_files"

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

# Подключаемся к первой ноде и скачиваем Hadoop, если его нет
USER_JN="${USER_NODES[0]}"
USER_NN="${USER_NODES[1]}"
echo "Подключаемся к $USER_JN и проверяем наличие архива $HADOOP_TAR..."

sshpass -p "$SSH_PASS" ssh "$USER_JN" bash << EOF
    if [[ ! -f "$HADOOP_TAR" ]]; then
        echo "Архив $HADOOP_TAR не найден. Скачиваем Hadoop..."
        wget "$HADOOP_URL"

        if [[ -f "$HADOOP_TAR" ]]; then
            echo "Hadoop успешно скачан на $USER_JN."
        else
            echo "Ошибка при скачивании Hadoop. Завершаем выполнение."
            exit 1
        fi
    else
        echo "Архив $HADOOP_TAR уже существует на $USER_JN, пропускаем скачивание."
    fi
EOF

# Копируем архив на остальные ноды только если файла еще нет
for NODE in "${USER_NODES[@]:1}"; do
    echo "Копируем Hadoop на $NODE..."
    sshpass -p "$SSH_PASS" scp "$USER_JN:$HADOOP_TAR" "$NODE:~"

    echo "Распаковываем Hadoop на $NODE..."
    sshpass -p "$SSH_PASS" ssh "$NODE" bash << EOF
        if [ -f ~/$HADOOP_TAR ]; then
            if [ -d "hadoop-$HADOOP_VERSION" ]; then
                echo "Папка hadoop-$HADOOP_VERSION уже существует. Удаляем..."
                rm -rf "hadoop-$HADOOP_VERSION"
            fi
            tar -xvzf ~/$HADOOP_TAR
            echo "Hadoop успешно установлен на $NODE."
            rm -f ~/$HADOOP_TAR  # Удаляем архив после распаковки
        else
            echo "Архив $HADOOP_TAR не найден на $NODE."
        fi
EOF

    # Копируем конфигурационные файлы
    echo "Копируем конфигурационные файлы на $NODE..."
    sshpass -p "$SSH_PASS" scp "$CONFIG_DIR/.profile" "$NODE:~/.profile"
    sshpass -p "$SSH_PASS" scp "$CONFIG_DIR/core-site.xml" "$NODE:~/hadoop-$HADOOP_VERSION/etc/hadoop/core-site.xml"
    sshpass -p "$SSH_PASS" scp "$CONFIG_DIR/hadoop-env.sh" "$NODE:~/hadoop-$HADOOP_VERSION/etc/hadoop/hadoop-env.sh"
    sshpass -p "$SSH_PASS" scp "$CONFIG_DIR/hdfs-site.xml" "$NODE:~/hadoop-$HADOOP_VERSION/etc/hadoop/hdfs-site.xml"
    sshpass -p "$SSH_PASS" scp "$CONFIG_DIR/nn" "$NODE:/etc/nginx/sites-enabled/nn"
    sshpass -p "$SSH_PASS" scp "$CONFIG_DIR/workers" "$NODE:~/hadoop-$HADOOP_VERSION/etc/hadoop/workers"

    echo "Конфигурационные файлы успешно скопированы на $NODE."
    echo "*****************************************************************************"
    echo
done

echo "Скрипт выполнен успешно."
