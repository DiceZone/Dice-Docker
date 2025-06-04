#!/bin/bash

# 处理命令行参数
while getopts ":q:" opt; do
  case $opt in
    q)
      QQ_ARG="$OPTARG"
      ;;
    \?)
      echo "无效选项: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "选项 -$OPTARG 需要参数." >&2
      exit 1
      ;;
  esac
done

# 检测 Docker 是否已安装
check_docker_installed() {
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 配置目录和文件路径
DICE_DIR="/opt/Dice-Docker"
QQ_CONFIG_FILE="$DICE_DIR/.env"
COMPOSE_FILE="$DICE_DIR/docker-compose.yml"

# 检查QQ参数并处理
if [ -n "$QQ_ARG" ]; then
    if [[ $QQ_ARG =~ ^[0-9]+$ ]]; then
        QQ_INPUT="$QQ_ARG"
    else
        echo "错误：-q 参数必须是纯数字"
        exit 1
    fi
fi

# 配置QQ号
sudo mkdir -p "$DICE_DIR"
if [ -f "$QQ_CONFIG_FILE" ]; then
    if grep -q '^ACCOUNT=' "$QQ_CONFIG_FILE"; then
        QQ_NUMBER=$(grep '^ACCOUNT=' "$QQ_CONFIG_FILE" | cut -d'=' -f2)
        echo "检测到已有骰娘QQ号配置: $QQ_NUMBER"
        QQ_INPUT="$QQ_NUMBER"  # 优先使用现有配置
    elif [ -z "$QQ_INPUT" ]; then
        echo "环境变量文件中没有找到QQ号配置，需要输入QQ号"
        read -p "请输入骰娘QQ号（必须输入）: " QQ_INPUT
        
        if [ -z "$QQ_INPUT" ]; then
            echo "错误：QQ号不能为空"
            exit 1
        elif [[ ! $QQ_INPUT =~ ^[0-9]+$ ]]; then
            echo "错误：QQ号必须是纯数字"
            exit 1
        fi
    fi
else
    if [ -z "$QQ_INPUT" ]; then
        read -p "请输入骰娘QQ号（必须输入）: " QQ_INPUT
        
        if [ -z "$QQ_INPUT" ]; then
            echo "错误：QQ号不能为空"
            exit 1
        elif [[ ! $QQ_INPUT =~ ^[0-9]+$ ]]; then
            echo "错误：QQ号必须是纯数字"
            exit 1
        fi
    fi
fi

# 创建或更新.env文件
if [ ! -f "$QQ_CONFIG_FILE" ] || ! grep -q '^ACCOUNT=' "$QQ_CONFIG_FILE"; then
    echo "设置QQ号: $QQ_INPUT"
    sudo tee "$QQ_CONFIG_FILE" > /dev/null <<EOF
ACCOUNT=$QQ_INPUT
NAPCAT_UID=1000
NAPCAT_GID=1000
EOF
fi

# 生成随机MAC地址
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
    
    max_retries=3
    retry_count=0
    install_success=false
    
    while [ $retry_count -lt $max_retries ]; do
        echo "尝试 #$((retry_count+1)) 安装 Docker..."
        
        # 使用自维护安装脚本镜像源解决国内网络问题
        curl --retry 3 --retry-delay 5 --connect-timeout 20 --max-time 60 \
             -fsSL https://shia.loli.band/upload/docker_install.sh -o get-docker.sh
             
        # 替换为腾讯云镜像源
        sed -i 's|https://download.docker.com|https://mirrors.tencent.com/docker-ce|g' get-docker.sh
        
        sudo sh get-docker.sh
        
        # 验证安装
        if command -v docker &> /dev/null && docker compose version &> /dev/null; then
            install_success=true
            break
        else
            echo "部分安装步骤失败，正在重试..."
            retry_count=$((retry_count+1))
            sleep 5
        fi
    done
    
    # 清理临时文件
    sudo rm -f get-docker.sh
    
    # 最终验证安装
    if ! $install_success; then
        echo ""
        echo "============================================================"
        echo "错误：Docker 安装失败！可能原因："
        echo "1. 网络连接不稳定或被限制"
        echo "2. 系统软件源配置问题"
        echo "3. 安装源被阻止"
        echo ""
        echo "建议解决方案："
        echo "1. 检查网络连接并重试"
        echo "2. 手动安装 Docker：https://docs.docker.com/engine/install/"
        echo "============================================================"
        exit 1
    fi
    
    # 添加当前用户到docker组
    sudo usermod -aG docker $USER
    
    echo "Docker 安装成功！"
fi

# 使用毫秒镜像服务加速
echo "配置毫秒镜像服务加速..."
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json >/dev/null <<EOF
{
  "registry-mirrors": [
    "https://docker.1ms.run"
  ]
}
EOF

sudo systemctl restart docker
sudo systemctl enable docker

# 验证 Docker 服务状态
if ! sudo systemctl is-active --quiet docker; then
    echo "警告：Docker 服务未运行，正在尝试启动..."
    sudo systemctl start docker
    sleep 2
    if ! sudo systemctl is-active --quiet docker; then
        echo "错误：无法启动 Docker 服务"
        exit 1
    fi
fi

# 创建 MCSManager 实例配置文件
MCS_CONFIG_DIR="/opt/mcsmanager/daemon/data/InstanceConfig"
MCS_CONFIG_FILE="$MCS_CONFIG_DIR/dice.json"

echo "配置 MCSManager 实例..."
sudo mkdir -p "$MCS_CONFIG_DIR"

# 从环境变量文件获取QQ号
ACCOUNT=$(grep '^ACCOUNT=' "$QQ_CONFIG_FILE" | cut -d'=' -f2)

sudo tee "$MCS_CONFIG_FILE" > /dev/null <<EOF
{
    "nickname": "Dice-$ACCOUNT",
    "startCommand": "docker compose up",
    "stopCommand": "^c",
    "cwd": "/opt/Dice-Docker",
    "ie": "utf8",
    "oe": "utf8",
    "createDatetime": $(date +%s)000,
    "lastDatetime": $(date +%s)000,
    "type": "universal",
    "tag": [],
    "endTime": 0,
    "fileCode": "utf8",
    "processType": "general",
    "updateCommand": "",
    "crlf": 1,
    "category": 0,
    "enableRcon": false,
    "rconPassword": "",
    "rconPort": 0,
    "rconIp": "",
    "actionCommandList": [],
    "terminalOption": {
        "haveColor": false,
        "pty": false,
        "ptyWindowCol": 164,
        "ptyWindowRow": 40
    },
    "eventTask": {
        "autoStart": true,
        "autoRestart": true,
        "ignore": false
    },
    "docker": {
        "containerName": "",
        "image": "",
        "ports": [],
        "extraVolumes": [],
        "memory": 0,
        "networkMode": "bridge",
        "networkAliases": [],
        "cpusetCpus": "",
        "cpuUsage": 0,
        "maxSpace": 0,
        "io": 0,
        "network": 0,
        "workingDir": "/data",
        "env": [],
        "changeWorkdir": true
    },
    "pingConfig": {
        "ip": "",
        "port": 25565,
        "type": 1
    },
    "extraServiceConfig": {
        "openFrpTunnelId": "",
        "openFrpToken": "",
        "isOpenFrp": false
    }
}
EOF

echo "MCSManager 实例配置已创建: $MCS_CONFIG_FILE"

# 创建 Dice-Docker 目录
echo "设置 Dice-Docker 环境..."
sudo mkdir -p -m 755 /opt/Dice-Docker
cd /opt/Dice-Docker

# 生成带随机MAC地址的docker-compose.yml
sudo tee "$COMPOSE_FILE" > /dev/null <<'EOF'
services:
  dice:
    image: shiaworkshop/dice:latest
    container_name: dice-main
    stdin_open: true
    tty: true
    ports:
      - "20000:20000"
    working_dir: /app/Dice
    volumes:
      - "./Dice:/app/Dice"
      - "./napcat/config:/app/napcat/config"
    environment:
      - ACCOUNT
    networks:
      - dice
    depends_on:
      - napcat

  napcat:
    image: mlikiowa/napcat-docker:latest
    container_name: napcat
    hostname: DiceCiallo
    ports:
      - "22000:6099"
    volumes:
      - "./napcat/config:/app/napcat/config"
      - "./napcat/QQ_DATA:/app/.config/QQ"
      - "./Dice:/app/Dice"
    environment:
      - NAPCAT_UID
      - NAPCAT_GID
      - ACCOUNT
    networks:
      - dice
    mac_address: "${MAC_ADDRESS}"

networks:
  dice:
    driver: bridge
EOF


# 使用sed替换MAC地址占位符
sudo sed -i "s/\${MAC_ADDRESS}/$MAC_ADDRESS/" "$COMPOSE_FILE"

# 创建目录结构
sudo mkdir -p "$DICE_DIR/Dice" "$DICE_DIR/napcat/config" "$DICE_DIR/napcat/QQ_DATA"

# 安装 MCSM
echo "正在安装 MCSManager..."
sudo su -c "wget -qO- https://script.mcsmanager.com/setup_cn.sh | bash"

# 检测内网IP
get_internal_ip() {
    # 尝试多种方法获取内网IP
    internal_ip=$(ip route get 1 | grep -Eo 'src ([0-9\.]{7,15})' | awk '{print $2}' 2>/dev/null)
    if [ -z "$internal_ip" ]; then
        internal_ip=$(hostname -I | awk '{print $1}' 2>/dev/null)
    fi
    if [ -z "$internal_ip" ]; then
        internal_ip=$(ip addr show | grep -E 'inet (192\.168|10\.|172\.16)' | head -1 | awk '{print $2}' | cut -d'/' -f1)
    fi
    echo "$internal_ip"
}

# 检测公网IP
get_external_ip() {
    # 使用多个不同提供商的API检测公网IP
    if ! external_ip=$(curl -s --connect-timeout 3 https://ipinfo.io/ip 2>/dev/null); then
        external_ip=$(curl -s --connect-timeout 3 https://ifconfig.me 2>/dev/null)
    fi
    
    # 验证IP格式
    if ! echo "$external_ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
        external_ip="无法自动获取公网IP"
    fi
    echo "$external_ip"
}

# 获取IP地址
INTERNAL_IP=$(get_internal_ip)
EXTERNAL_IP=$(get_external_ip)

# 输出信息
echo ""
echo "============================================================"
echo "安装完成！以下是重要信息："
echo ""
echo "Dice容器工作目录: $DICE_DIR"
echo ""
echo "MCSManager面板访问地址:"
echo "  公网访问: http://${EXTERNAL_IP}:23333"
echo "  内网访问: http://${INTERNAL_IP}:23333"
echo ""
echo "MCSManager面板账号密码请在登录后自行设置"
echo "已创建骰子实例并开始拉取镜像，请访问面板页面查看"
echo ""
echo "注意:"
echo "云服务器必须在控制台安全组（防火墙）中开放23333、24444、20000、22000端口"
echo "推荐开放20000-30000端口范围"
echo "============================================================"
