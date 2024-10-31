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

# Функция для скачивания и установки Hadoop на ноду
install_hadoop() {
    local NODE="$1"
    echo "Подключаемся к $NODE и проверяем наличие архива $HADOOP_TAR..."

    sshpass -p "$SSH_PASS" ssh "$NODE" bash << EOF
        if [[ ! -f "$HADOOP_TAR" ]]; then
            echo "Архив $HADOOP_TAR не найден. Скачиваем Hadoop..."
            wget --progress=bar "$HADOOP_URL"

            if [[ -f "$HADOOP_TAR" ]]; then
                echo "Hadoop успешно скачан на $NODE."
            else
                echo "Ошибка при скачивании Hadoop. Завершаем выполнение."
                exit 1
            fi
        else
            echo "Архив $HADOOP_TAR уже существует на $NODE, пропускаем скачивание."
        fi

        # Распаковываем Hadoop
        if [ -f "$HADOOP_TAR" ]; then
            if [ -d "hadoop-$HADOOP_VERSION" ]; then
                echo "Папка hadoop-$HADOOP_VERSION уже существует. Удаляем..."
                rm -rf "hadoop-$HADOOP_VERSION"
            fi
            tar -xvzf "$HADOOP_TAR"
            echo "Hadoop успешно установлен на $NODE."
            rm -f "$HADOOP_TAR"  # Удаляем архив после распаковки
        else
            echo "Архив $HADOOP_TAR не найден на $NODE."
        fi
EOF
}

# Устанавливаем Hadoop на каждую ноду
for NODE in "${USER_NODES[@]}"; do
    install_hadoop "$NODE"

#    # Копируем конфигурационные файлы
#    echo "Копируем конфигурационные файлы на $NODE..."
#    sshpass -p "$SSH_PASS" scp "$CONFIG_DIR/.profile" "$NODE:~/.profile"
#    sshpass -p "$SSH_PASS" scp "$CONFIG_DIR/core-site.xml" "$NODE:~/hadoop-$HADOOP_VERSION/etc/hadoop/core-site.xml"
#    sshpass -p "$SSH_PASS" scp "$CONFIG_DIR/hadoop-env.sh" "$NODE:~/hadoop-$HADOOP_VERSION/etc/hadoop/hadoop-env.sh"
#    sshpass -p "$SSH_PASS" scp "$CONFIG_DIR/hdfs-site.xml" "$NODE:~/hadoop-$HADOOP_VERSION/etc/hadoop/hdfs-site.xml"
#    sshpass -p "$SSH_PASS" scp "$CONFIG_DIR/nn" "$NODE:/etc/nginx/sites-enabled/nn"
#    sshpass -p "$SSH_PASS" scp "$CONFIG_DIR/workers" "$NODE:~/hadoop-$HADOOP_VERSION/etc/hadoop/workers"

    # Копируем конфигурационные файлы на $NODE
    echo "Копируем конфигурационные файлы на $NODE..."
    sshpass -p "$SSH_PASS" scp "$CONFIG_DIR/.profile" "$NODE:~/.profile"
    sshpass -p "$SSH_PASS" scp "$CONFIG_DIR/core-site.xml" "$NODE:~/hadoop-$HADOOP_VERSION/etc/hadoop/core-site.xml"
    sshpass -p "$SSH_PASS" scp "$CONFIG_DIR/hadoop-env.sh" "$NODE:~/hadoop-$HADOOP_VERSION/etc/hadoop/hadoop-env.sh"
    sshpass -p "$SSH_PASS" scp "$CONFIG_DIR/hdfs-site.xml" "$NODE:~/hadoop-$HADOOP_VERSION/etc/hadoop/hdfs-site.xml"

    # Сначала копируем файл в домашнюю директорию
    sshpass -p "$SSH_PASS" scp "$CONFIG_DIR/nn" "$NODE:~/nn"
    # Затем перемещаем его с использованием sudo
    sshpass -p "$SSH_PASS" ssh "$NODE" "sudo mv ~/nn /etc/nginx/sites-enabled/nn"

    sshpass -p "$SSH_PASS" scp "$CONFIG_DIR/workers" "$NODE:~/hadoop-$HADOOP_VERSION/etc/hadoop/workers"

    echo "Конфигурационные файлы успешно скопированы на $NODE."
    echo "*****************************************************************************"
    echo
done

echo "Скрипт выполнен успешно."
