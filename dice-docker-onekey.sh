#!/bin/bash

generate_mac() {
    # 生成后4个字节的随机十六进制数
    random_bytes=$(openssl rand -hex 3 | sed 's/$..$/\1:/g; s/.$//')
    # 格式化为02:42:xx:xx:xx:xx
    echo "02:42:$random_bytes"
}
MAC_ADDRESS=$(generate_mac)
echo "已生成随机MAC地址: $MAC_ADDRESS"

# 安装 Docker
echo "正在安装 Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm get-docker.sh

# 修改 Docker 镜像源（使用1ms源加速）
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

# 检查并设置骰娘QQ号
QQ_CONFIG_FILE="/opt/Dice-Docker/.env"
DEFAULT_QQ="123456"

# 检查是否已经有账号配置
if [ -f "$QQ_CONFIG_FILE" ]; then
    # 检查文件中是否有ACCOUNT设置
    if grep -q '^ACCOUNT=' "$QQ_CONFIG_FILE"; then
        QQ_NUMBER=$(grep '^ACCOUNT=' "$QQ_CONFIG_FILE" | cut -d'=' -f2)
        echo "检测到已有骰娘QQ号配置: $QQ_NUMBER"
    else
        # 没有ACCOUNT设置，添加默认值
        echo "没有检测到ACCOUNT设置，使用默认值: $DEFAULT_QQ"
        sudo sh -c "echo 'ACCOUNT=$DEFAULT_QQ' >> $QQ_CONFIG_FILE"
    fi
else
    # 文件不存在，询问用户输入
    echo "没有找到骰娘QQ号配置文件"
    read -p "请输入骰娘QQ号(按回车使用默认值 $DEFAULT_QQ): " QQ_INPUT
    
    if [ -z "$QQ_INPUT" ]; then
        echo "使用默认QQ号: $DEFAULT_QQ"
        sudo sh -c "echo 'ACCOUNT=$DEFAULT_QQ' > $QQ_CONFIG_FILE"
    else
        # 验证输入是否为数字
        if [[ $QQ_INPUT =~ ^[0-9]+$ ]]; then
            echo "设置QQ号: $QQ_INPUT"
            sudo sh -c "echo 'ACCOUNT=$QQ_INPUT' > $QQ_CONFIG_FILE"
        else
            echo "错误：请输入有效的QQ号码"
            exit 1
        fi
    fi
fi

# 安装 MCSM
echo "正在安装 MCSManager..."
sudo su -c "wget -qO- https://script.mcsmanager.com/setup_cn.sh | bash"

# 完成提示
echo "安装完成！"
