# Dice-Docker-Napcat

> 🥳壮举！
> 
> 官方释出了全新的可用的Linux下DiceCore和Driver
> 
> 所以本项目更新了dev通道采用了 `Core 2.7.0hotfix(666)` / `Driver 1.0.2(13)` 版本
>
> 默认latest通道采用了 `Core 2.6.6rc(638)` / `Driver 0.4.0(8)` 版本
> 
> 638核心较为古早，部分新特性扩展文件可能无法使用
> 
> 请根据实际需求选择安装时采用的版本
>
> ⚠️但是注意，666版本的骰子核心配置文件不再兼容旧版，无法降级使用

用于在linux上使用docker-compose快速组装Dice+Napcat

支援amd64

[Docker Hub](https://hub.docker.com/r/shiaworkshop/dice)

## 一键启动

通过脚本的方式一键安装Docker、MCSManager面板和自动配置骰娘实例，仅通过腾讯云Ubuntu24测试，理论上Debian系通用。

新版核心启动

```shell
wget -qO- https://dice.zone/bash/dice_onekey.sh | bash -s -- -c dev -q 123456789 # 最后的数字改成骰娘QQ
```

旧版核心（638）启动

```shell
wget -qO- https://dice.zone/bash/dice_onekey.sh | bash -s -- -v 638 -q 123456789 # 最后的数字改成骰娘QQ
```

可选参数说明：

`-q` 在启动时指定骰娘QQ，如 `-q 123456789`

`-c` 指定 Dice 的通道，可选通道为 `latest` / `dev` ，其中 `latest` 目前为 638 ，之后可能会更新到 666 ，`dev` 版本目前为 666 。

`-v` 指定 Dice 的核心版本号，目前可选版本号为 `638` / `666` 。

安装完成后根据提示前往面板检查和登录骰娘

## 手动使用

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

### 关于图片发送

容器的运行文件已经映射出来，以默认设置（一键安装相同）为例：

我们的 `/opt/Dice-Docker/Dice` 文件夹映射到了 `Dice` 和 `NapCat` 容器的 `/app/Dice` 目录里

所以我们只要把图片上传到 `/opt/Dice-Docker/Dice` 文件夹的任意子目录里

然后就可以在骰娘里正常引用了

例如我们新建一个 `/opt/Dice-Docker/Dice/img` 文件夹（一键方式直接在面板-实例-文件管理里创建 `img` 文件夹即可），然后我把图片 `jrrp.jpg` 上传到这个文件夹里

通过 CQ 码引用 `[CQ:image,file=file:///app/Dice/img/jrrp.jpg]`

