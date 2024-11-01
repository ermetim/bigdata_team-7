#!/bin/bash

# Запрашиваем пароли
read -s -p "Введите SSH пароль: " SSH_PASS
echo
#read -p "Введите имя нового пользователя: " NEW_USER
NEW_USER="hadoop"
read -s -p "Введите пароль для нового пользователя $NEW_USER: " USER_PASS
echo

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
install_utilities sshpass wget tar rsync

# Определяем переменные
JUMP_SERVER="team@176.109.91.41"

# Определяем IP-адреса целевых нод
IP_NODES=(
    "192.168.1.30"
    "192.168.1.31"
    "192.168.1.32"
    "192.168.1.33"
)

PUBLIC_KEYS="# new keys for $NEW_USER"

# Формируем массив TARGET_NODES и USER_NODES на основе IP_NODES
TARGET_NODES=()
USER_NODES=()
for IP in "${IP_NODES[@]}"; do
    TARGET_NODES+=("team@$IP")
    USER_NODES+=("$NEW_USER@$IP")
done

# Данные для записи в /etc/hosts
HOSTS_DATA="
192.168.1.30 team-7-jn
192.168.1.31 team-7-nn
192.168.1.32 team-7-dn-00
192.168.1.33 team-7-dn-01
"

# Функция для выполнения команд на целевой ноде
create_user_on_node() {
    local NODE="$1"
    echo "Подключаемся к $NODE..."

#    sshpass -p "$SSH_PASS" ssh -J "$JUMP_SERVER" "$NODE" bash << EOF
#    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -J "$JUMP_SERVER" "$NODE" bash << EOF
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$NODE" bash << EOF

    # Очищаем файл /etc/hosts
    echo "$SSH_PASS" | sudo -p "" -S truncate -s 0 /etc/hosts

    # Записываем данные хостов в /etc/hosts
    echo "$SSH_PASS" | sudo -S bash -c 'echo -e "$HOSTS_DATA" >> /etc/hosts'


    # Проверяем, существует ли пользователь hadoop
    if getent passwd "$NEW_USER" > /dev/null; then

        echo "Пользователь $NEW_USER уже существует. Удаляем..."
        echo "$SSH_PASS" | sudo -S -p "" deluser --remove-home "$NEW_USER" > /dev/null
    fi

    # Создаем нового пользователя hadoop
    echo "$SSH_PASS" | sudo -S adduser "$NEW_USER" --gecos "" --disabled-password > /dev/null

    # Устанавливаем пароль для пользователя hadoop
    echo "$NEW_USER:$USER_PASS" | sudo chpasswd

    # Переключаемся на пользователя hadoop и создаем SSH-ключи
    sudo -i -u "$NEW_USER" bash << USER_SHELL

    # Создаем SSH-ключи
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q

    # Устанавливаем права на закрытый ключ
    chmod 600 ~/.ssh/id_ed25519

    # Устанавливаем права на открытый ключ
    chmod 644 ~/.ssh/id_ed25519.pub

USER_SHELL
EOF

    echo "Пользователь $NEW_USER создан, и SSH-ключи сгенерированы на $NODE."
    echo "*****************************************************************************"
    echo
}

# Цикл по всем целевым нодам
for NODE in "${TARGET_NODES[@]}"; do
    create_user_on_node "$NODE"
done

# Сбор публичных ключей с каждой ноды
echo "Собираем публичные ключи ..."
for NODE in "${USER_NODES[@]}"; do
#    PUBLIC_KEY=$(sshpass -p "$SSH_PASS" ssh -J "$JUMP_SERVER" "$NODE" "cat ~/.ssh/id_ed25519.pub")
    PUBLIC_KEY=$(sshpass -p "$SSH_PASS" ssh "$NODE" "cat ~/.ssh/id_ed25519.pub")
    PUBLIC_KEYS+="\n$PUBLIC_KEY"
done

# Вывод всех собранных ключей
# echo -e "$PUBLIC_KEYS" >> ./ssh_keys.txt
# echo -e "$PUBLIC_KEYS"

# Добавление ключей PUBLIC_KEYS в authorized_keys на каждой ноде
echo "Добавляем публичные ключи ..."
for NODE in "${USER_NODES[@]}"; do
#    sshpass -p "$SSH_PASS" ssh -J "$JUMP_SERVER" "$NODE" bash << EOF
    sshpass -p "$SSH_PASS" ssh "$NODE" bash << EOF

    # Добавляем собранные ключи в authorized_keys
    bash -c 'echo -e "$PUBLIC_KEYS" >> ~/.ssh/authorized_keys'
    # с командой sudo
    # echo "$SSH_PASS" | sudo -S bash -c 'echo -e "$PUBLIC_KEYS" >> ~/.ssh/authorized_keys'

    echo "Ключи добавлены в ~/.ssh/authorized_keys на $NODE."
EOF
done
