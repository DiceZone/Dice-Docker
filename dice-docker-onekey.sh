#!/bin/bash

# 检测 Docker 是否已安装
check_docker_installed() {
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 要求输入QQ号
QQ_CONFIG_FILE="/opt/Dice-Docker/.env"
if [ -f "$QQ_CONFIG_FILE" ]; then
    if grep -q '^ACCOUNT=' "$QQ_CONFIG_FILE"; then
        QQ_NUMBER=$(grep '^ACCOUNT=' "$QQ_CONFIG_FILE" | cut -d'=' -f2)
        echo "检测到已有骰娘QQ号配置: $QQ_NUMBER"
    else
        echo "环境变量文件中没有找到QQ号配置，需要输入QQ号"
        exit 1
    fi
else
    read -p "请输入骰娘QQ号（必须输入）: " QQ_INPUT
    
    if [ -z "$QQ_INPUT" ]; then
        echo "错误：QQ号不能为空"
        exit 1
    else
        if [[ $QQ_INPUT =~ ^[0-9]+$ ]]; then
            echo "设置QQ号: $QQ_INPUT"
            sudo mkdir -p /opt/Dice-Docker
            sudo sh -c "echo 'ACCOUNT=$QQ_INPUT' > $QQ_CONFIG_FILE"
        else
            echo "错误：QQ号必须是纯数字"
            exit 1
        fi
    fi
fi

generate_mac() {
    random_bytes=$(openssl rand -hex 4)
    formatted_bytes=$(echo "$random_bytes" | sed -E 's/(..)(..)(..)(..)/\1:\2:\3:\4/')
    echo "02:42:$formatted_bytes"
}
MAC_ADDRESS=$(generate_mac)
echo "已生成随机MAC地址: $MAC_ADDRESS"

# 检测并安装 Docker
if check_docker_installed; then
    echo "Docker 和 Docker Compose 已安装，跳过安装步骤"
else
    echo "正在安装 Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
fi

# 修改 Docker 镜像源
echo "配置 毫秒镜像 作为 Docker 镜像源加速..."
sudo mkdir -p /etc/docker
sudo sh -c 'cat <<EOF > /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://docker.1ms.run"
  ]
}
EOF'

sudo systemctl restart docker

# 安装 MCSM
echo "正在安装 MCSManager..."
sudo su -c "wget -qO- https://script.mcsmanager.com/setup_cn.sh | bash"

# 创建 Dice-Docker 目录
echo "设置 Dice-Docker 环境..."
sudo mkdir -p -m 755 /opt/Dice-Docker
cd /opt/Dice-Docker

# 生成带随机MAC地址的docker-compose.yml
sudo sh -c "cat <<EOF > docker-compose.yml
services:
  dice:
    image: shiaworkshop/dice:latest
    container_name: dice-main
    stdin_open: true
    tty: true
    ports:
      - \"20000:20000\"
    working_dir: /app/Dice
    volumes:
      - \"./Dice:/app/Dice\"
      - \"./napcat/config:/app/napcat/config\"
    environment:
      - ACCOUNT=\${ACCOUNT}
    networks:
      - dice
    depends_on:
      - napcat

  napcat:
    image: mlikiowa/napcat-docker:latest
    container_name: napcat
    hostname: DiceCiallo
    ports:
      - \"22000:6099\"
    volumes:
      - \"./napcat/config:/app/napcat/config\"
      - \"./napcat/QQ_DATA:/app/.config/QQ\"
      - \"./Dice:/app/Dice\"
    environment:
      - NAPCAT_UID=\${NAPCAT_UID:-1000}
      - NAPCAT_GID=\${NAPCAT_GID:-1000}
      - ACCOUNT=\${ACCOUNT}
    networks:
      - dice
    mac_address: \"$MAC_ADDRESS\"

networks:
  dice:
    driver: bridge
EOF"

# 创建目录结构
sudo mkdir -p Dice napcat/config napcat/QQ_DATA

echo "安装完成！"
