# CentOS 7.9 Docker GPU配置

# 1. 添加nvidia-container-runtime仓库
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-container-runtime/$distribution/nvidia-container-runtime.repo | \
  sudo tee /etc/yum.repos.d/nvidia-container-runtime.repo

# 2. 安装nvidia-container-runtime
sudo yum install -y nvidia-container-runtime

# 3. 配置Docker使用nvidia运行时
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<'EOF'
{
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  }
}
EOF

# 4. 重启Docker
sudo systemctl restart docker

# 5. 验证配置
docker info | grep -A 10 "Runtimes"
