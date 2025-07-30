FROM ubuntu:22.04

# 设置中国时区
ENV TZ=Asia/Shanghai
RUN apt-get update && \
    apt-get install -y tzdata ca-certificates && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    rm -rf /var/lib/apt/lists/*

# 创建应用目录结构
RUN mkdir -p /app/Dice /app/napcat/config

# 复制程序文件和配置文件
COPY ./Dice /app/Dice
COPY ./config-example.json /app/napcat/config/

# 设置文件权限
RUN chmod +x /app/Dice/DiceDriver.OneBot

# 创建备份目录
RUN cp -a /app /opt/backup

# 启动脚本
RUN echo '#!/bin/bash\n\
# 主程序文件修复\n\
if [ ! -f "/app/Dice/DiceDriver.OneBot" ]; then\n\
    echo "从备份恢复主程序..."\n\
    cp -af /opt/backup/Dice /app/\n\
fi\n\
\n\
# NapCat配置文件不存在时从备份复制\n\
    NAPCAT_CONF="/app/napcat/config/onebot11_${ACCOUNT:-123456}.json"\n\
    if [ ! -f "${NAPCAT_CONF}" ]; then\n\
        mkdir -p /app/napcat/config\n\
        cp "/opt/backup/napcat/config/config-example.json" "${NAPCAT_CONF}"\n\
        echo "已生成 NapCat 配置文件：${NAPCAT_CONF}"\n\
    else\n\
        echo "检测到已有 NapCat 配置文件，保留用户修改：${NAPCAT_CONF}"\n\
    fi\n\
\n\
# 强制复制webui.html并且锁定权限解决webui404错误\n\
WEBUI_TARGET="/app/Dice/Dice${ACCOUNT:-123456}/webui/index.html"\n\
WEBUI_BACKUP="/opt/backup/Dice/webui.html"\n\
\n\
echo "正在修复 WebUI ..."\n\
mkdir -p "$(dirname "${WEBUI_TARGET}")"\n\
\n\
if [ -f "${WEBUI_TARGET}" ] && lsattr "${WEBUI_TARGET}" | grep -q "i"; then\n\
    chattr -i "${WEBUI_TARGET}" 2>/dev/null\n\
fi\n\
\n\
echo "正在强制复制webui.html到 ${WEBUI_TARGET} 并锁定"\n\
    mkdir -p "$(dirname "${WEBUI_TARGET}")" \n\
    cp -f "${WEBUI_BACKUP}" "${WEBUI_TARGET}"\n\
    chmod 444 "${WEBUI_TARGET}"\n\
    chattr +i "${WEBUI_TARGET}"\n\
    echo "锁定 WebUI 文件"\n\
\n\
# 执行主程序\n\
exec /app/Dice/DiceDriver.OneBot "$@"' > /usr/local/bin/dice-entrypoint && \
    chmod +x /usr/local/bin/dice-entrypoint

# 设置工作目录和入口点
WORKDIR /app/Dice
ENTRYPOINT ["dice-entrypoint"]
