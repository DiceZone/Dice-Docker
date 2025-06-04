# Dice-Docker-Napcat

用于在linux上使用docker-compose快速组装Dice+Napcat

支援amd64

[Docker Hub](https://hub.docker.com/r/shiaworkshop/dice)

## 一键启动并安装MCSManager面板

通过脚本的方式一键安装docker和mcsmanager和自动配置骰娘实例

```shell
wget -qO- https://shia.loli.band/upload/dice_onekey.sh | bash -s -- -q 123456789 # 最后的数字改成骰娘QQ
```

安装完成后根据提示前往面板检查和登录骰娘

## 手动使用方法

### 准备工作

#### 确保已安装 Docker 和 Docker Compose
- Docker 安装​​：参考 [官方文档](https://docs.docker.com/engine/install/)

- ​​Docker Compose 安装​​：通常随 Docker Desktop 自动安装，独立安装可参考 [官方指南](https://docs.docker.com/compose/install/)

#### 创建数据目录

  创建存储 Dice 和 napcat 数据的本地目录，用于持久化数据。

  我们以默认位置为例：

  ```shell
  mkdir -p -m 755 /opt/Dice-Docker
  cd /opt/Dice-Docker
  ```

#### 配置环境变量

  下载 `docker-compose.yml` ，在同一级创建 `.env` 文件。
  
  ```shell
  wget https://raw.githubusercontent.com/ShiaBox/Dice-Docker-Napcat/refs/heads/main/docker-compose.yml
  echo 'ACCOUNT=123456' > .env
  ```

  在 `.env` 内，变量 `ACCOUNT` 是键入骰娘账号，所以要替换`123456`为你实际的骰娘账号。

### 运行服务
1. 启动所有服务
```shell
docker compose up -d
```
2. 查看容器状态
```shell
docker compose ps
```
3. 停止服务
```shell
docker compose down
```
4. 更新服务
```shell
# 拉取最新镜像
docker compose pull
# 重新创建容器
docker compose up -d --force-recreate
```
注意，旧版本 docker compose 使用 `docker-compose up -d` 这样的指令格式，请根据你系统的docker版本来选用。

### 登录

容器日志能看到二维码，同时也推荐你使用NapCat的webUI去扫码登录，比如 `IP:6099` 或者你启动容器时映射的其他端口号。

