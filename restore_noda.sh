#!/bin/bash

# Запрашиваем пароли
read -s -p "Введите SSH пароль: " SSH_PASS
echo
#read -p "Введите имя пользователя на удаление: " NEW_USER
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

# Формируем массив TARGET_NODES и USER_NODES на основе IP_NODES
TARGET_NODES=()
#USER_NODES=()
for IP in "${IP_NODES[@]}"; do
    TARGET_NODES+=("team@$IP")
#    USER_NODES+=("$NEW_USER@$IP")
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

#    sshpass -p "$SSH_PASS" ssh -J "$JUMP_SERVER" "$NODE" bash << EOF
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$NODE" bash << EOF

    # Удаляем пользователя hadoop, если он существует
    if getent passwd "$NEW_USER" > /dev/null; then
        echo "Завершаем все процессы пользователя $NEW_USER..."
        echo "$SSH_PASS" | sudo -S -p "" pkill -u "$NEW_USER"

        echo "$SSH_PASS" | sudo -S -p "" deluser --remove-home "$NEW_USER"
        echo "Пользователь $NEW_USER удален."
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

# Цикл по всем целевым нодам для восстановления
for NODE in "${TARGET_NODES[@]}"; do
    restore_system "$NODE"
done
