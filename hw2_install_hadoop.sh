#!/bin/bash

# Запрашиваем пароли
read -s -p "Введите SSH пароль: " SSH_PASS
echo
NEW_USER="hadoop"
echo

# Определяем переменные
JUMP_SERVER="team@176.109.91.41"
IP_NODES=(
    "192.168.1.30"
    "192.168.1.31"
    "192.168.1.32"
    "192.168.1.33"
)

PUBLIC_KEYS="# new keys for $NEW_USER"

# Формируем массив TARGET_NODES на основе IP_NODES
TARGET_NODES=()
for IP in "${IP_NODES[@]}"; do
    TARGET_NODES+=("team@$IP")
done

# Данные для записи в /etc/hosts (восстановление)
HOSTS_DATA="127.0.0.1 localhost
127.0.1.1 team-7-nn

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters"

# Функция для возврата системы в прежнее состояние
restore_system() {
    local NODE="$1"
    echo "Подключаемся к $NODE для восстановления..."

    sshpass -p "$SSH_PASS" ssh -J "$JUMP_SERVER" "$NODE" bash << EOF

    # Удаляем пользователя hadoop, если он существует
    if getent passwd "$NEW_USER" > /dev/null; then
        echo "$SSH_PASS" | sudo -S -p "" deluser --remove-home "$NEW_USER"
        echo "Пользователь $NEW_USER удален."
    fi

    # Удаляем папку hadoop-3.4.0, если она существует
    if [ -d "hadoop-3.4.0" ]; then
        echo "Удаляем папку hadoop-3.4.0..."
        rm -rf "hadoop-3.4.0"
    fi

    # Очищаем файл /etc/hosts
    echo "$SSH_PASS" | sudo -S bash -c 'echo -n "" > /etc/hosts'

    # Записываем данные хостов в /etc/hosts
    echo "$SSH_PASS" | sudo tee -a /etc/hosts > /dev/null << HOSTS
$HOSTS_DATA
HOSTS

    echo "Файл /etc/hosts восстановлен на $NODE."
EOF

    echo "*****************************************************************************"
    echo
}

# Копируем конфигурационные файлы и перемещаем их
copy_config_files() {
    local NODE="$1"

    echo "Копируем конфигурационные файлы на $NODE..."

    # Копируем файл nn
    sshpass -p "$SSH_PASS" scp bigdata_team-7/config_files/nn "$NODE:~/nn"
    # Перемещаем файл в /etc/nginx/sites-enabled с правами суперпользователя
    sshpass -p "$SSH_PASS" ssh "$NODE" bash << EOF
        echo "$SSH_PASS" | sudo -S mv ~/nn /etc/nginx/sites-enabled/
        echo "Файл nn перемещен в /etc/nginx/sites-enabled на $NODE."
EOF

    # Копируем и заменяем остальные конфигурационные файлы
    for file in .profile core-site.xml hadoop-env.sh hdfs-site.xml workers; do
        echo "Копируем и заменяем файл $file на $NODE..."
        sshpass -p "$SSH_PASS" scp "bigdata_team-7/config_files/$file" "$NODE:~/$file"
        sshpass -p "$SSH_PASS" ssh "$NODE" bash << EOF
            echo "$SSH_PASS" | sudo -S mv ~/$file ~/hadoop-3.4.0/etc/hadoop/$file
            echo "Файл $file перемещен в ~/hadoop-3.4.0/etc/hadoop/ на $NODE."
EOF
    done
}

# Цикл по всем целевым нодам для восстановления и копирования конфигурационных файлов
for NODE in "${TARGET_NODES[@]}"; do
    restore_system "$NODE"
    copy_config_files "$NODE"
done

echo "Скрипт выполнен успешно."
