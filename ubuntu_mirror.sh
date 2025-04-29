#!/bin/bash

set -e

# 颜色输出
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

# 镜像源HOST常量
ALIYUN_MIRROR="mirrors.aliyun.com"
TSINGHUA_MIRROR="mirrors.tuna.tsinghua.edu.cn"
USTC_MIRROR="mirrors.ustc.edu.cn"
DOCKER_OFFICIAL_MIRROR="download.docker.com"

# 检测系统版本和架构
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$NAME
    OS_VERSION=$VERSION_ID
else
    echo -e "${RED}无法检测到系统版本，退出。${RESET}"
    exit 1
fi

ARCH=$(dpkg --print-architecture)

echo -e "${GREEN}检测到系统信息：${RESET}"
echo -e "  系统: ${YELLOW}$OS_NAME $OS_VERSION${RESET}"
echo -e "  架构: ${YELLOW}$ARCH${RESET}"

# 检查是否是Ubuntu且版本是20.04、22.04或24.04
if [[ "$OS_NAME" != "Ubuntu" ]]; then
    echo -e "${RED}当前系统不是Ubuntu，脚本中止。${RESET}"
    exit 1
fi

if [[ "$OS_VERSION" != "20.04" && "$OS_VERSION" != "22.04" && "$OS_VERSION" != "24.04" ]]; then
    echo -e "${RED}只支持Ubuntu 20.04、22.04或24.04，脚本中止。${RESET}"
    exit 1
fi

# 选择镜像源
echo -e "\n请选择要使用的镜像源："
echo "1) 阿里云"
echo "2) 清华大学"
echo "3) 中科大"
read -rp "请输入数字 (1-3): " mirror_choice

case $mirror_choice in
  1)
    MIRROR_HOST="$ALIYUN_MIRROR"
    ;;
  2)
    MIRROR_HOST="$TSINGHUA_MIRROR"
    ;;
  3)
    MIRROR_HOST="$USTC_MIRROR"
    ;;
  *)
    echo -e "${RED}无效选择，脚本退出。${RESET}"
    exit 1
    ;;
esac

UBUNTU_MIRROR_URL="https://$MIRROR_HOST/ubuntu/"
DOCKER_MIRROR_URL="https://$MIRROR_HOST/docker-ce/linux/ubuntu"

# 备份原来的sources.list
BACKUP_FILE="/etc/apt/sources.list.bak.$(date +%Y%m%d%H%M%S)"
echo -e "\n${GREEN}备份原始 sources.list 为: $BACKUP_FILE${RESET}"
sudo cp /etc/apt/sources.list "$BACKUP_FILE"

# 写入新的sources.list
echo -e "${GREEN}正在配置新的Ubuntu镜像源...${RESET}"

cat <<EOF | sudo tee /etc/apt/sources.list > /dev/null
deb $UBUNTU_MIRROR_URL ${VERSION_CODENAME:-$(lsb_release -sc)} main restricted universe multiverse
deb $UBUNTU_MIRROR_URL ${VERSION_CODENAME:-$(lsb_release -sc)}-updates main restricted universe multiverse
deb $UBUNTU_MIRROR_URL ${VERSION_CODENAME:-$(lsb_release -sc)}-backports main restricted universe multiverse
deb $UBUNTU_MIRROR_URL ${VERSION_CODENAME:-$(lsb_release -sc)}-security main restricted universe multiverse
EOF

# 询问是否配置Docker软件源
echo -e "\nDocker软件源配置选项："
echo "1) 使用选择的镜像源"
echo "2) 使用官方镜像源"
echo "3) 不配置"
read -rp "请输入数字 (1-3): " docker_choice

if [[ "$docker_choice" == "1" || "$docker_choice" == "2" ]]; then
  echo -e "${GREEN}正在配置Docker软件源...${RESET}"
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

  # 添加Docker GPG Key
  sudo mkdir -p /etc/apt/keyrings

  if [[ "$docker_choice" == "1" ]]; then
    curl -fsSL https://$MIRROR_HOST/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] $DOCKER_MIRROR_URL $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  else
    curl -fsSL https://$DOCKER_OFFICIAL_MIRROR/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://$DOCKER_OFFICIAL_MIRROR/linux/ubuntu $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  fi

  echo -e "${GREEN}Docker软件源配置完成。${RESET}"
else
  echo -e "${YELLOW}跳过Docker软件源配置。${RESET}"
fi

# 询问是否更新apt索引
echo -e "\n是否执行 apt update 更新软件包索引？"
echo "1) 是"
echo "2) 否"
read -rp "请输入数字 (1-2): " update_choice

if [[ "$update_choice" == "1" ]]; then
  echo -e "${GREEN}正在更新软件包索引...${RESET}"
  sudo apt update
  echo -e "${GREEN}软件包索引更新完成。${RESET}"
else
  echo -e "${YELLOW}跳过apt update。${RESET}"
fi

echo -e "\n${GREEN}全部操作完成！${RESET}"

