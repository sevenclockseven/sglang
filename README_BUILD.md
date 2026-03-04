# SGLang GTX 3090 Docker 构建指南

## 环境要求

| 组件 | 版本 |
|------|------|
| 宿主机系统 | CentOS 7.9 |
| NVIDIA 驱动 | 535+ |
| GPU | GTX 3090 x 2 (Ampere, sm_86) |
| CUDA | 12.2 |

## 文件结构

```
sglang/
├── docker/
│   └── Dockerfile.gtx3090          # 镜像构建文件
├── .github/
│   └── workflows/
│       └── build-sglang-gtx3090.yml # GitHub Actions 工作流
└── README_BUILD.md                  # 本文档
```

## 本地构建

### 1. 基础构建

```bash
# 克隆或进入 sglang 仓库
cd sglang

# 构建镜像
docker build \
  --build-arg CUDA_VERSION=12.2 \
  --build-arg USE_LATEST_SGLANG=1 \
  -t sglang:gtx3090-cuda12.2 \
  -f docker/Dockerfile.gtx3090 .
```

### 2. 指定版本构建

```bash
# 构建指定版本
docker build \
  --build-arg CUDA_VERSION=12.2 \
  --build-arg SGL_VERSION=v0.5.0 \
  --build-arg BUILD_TYPE=all \
  -t sglang:gtx3090-v0.5.0 \
  -f docker/Dockerfile.gtx3090 .
```

### 3. 构建参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `CUDA_VERSION` | CUDA 版本 | 12.2 |
| `SGL_VERSION` | SGLang 版本 (如 v0.5.0) | - |
| `USE_Latest_SGLANG` | 使用最新版本 | 0 |
| `BUILD_TYPE` | 构建类型: all, astral, falcon, gptq, awq, fp8 | all |
| `BUILD_AND_DOWNLOAD_PARALLEL` | 并行构建任务数 | 8 |
| `SGL_KERNEL_VERSION` | SGLang kernel 版本 | 0.3.21 |

### 4. 多阶段构建

Dockerfile 包含两个阶段：
- `framework`: 完整开发环境，包含所有构建工具
- `runtime`: 生产运行时镜像，更轻量

```bash
# 只构建运行时镜像
docker build --target runtime \
  --build-arg CUDA_VERSION=12.2 \
  -t sglang:gtx3090-runtime \
  -f docker/Dockerfile.gtx3090 .
```

## GitHub Actions 构建

### 触发构建

1. 进入仓库的 **Actions** 页面
2. 选择 **Build SGLang GTX3090 Docker Image**
3. 点击 **Run workflow**
4. 填写参数：
   - `sgl_version`: SGLang 版本 (如 `v0.5.0`) 或 `latest`
   - `build_type`: 构建类型 (默认 `all`)
   - `push_to_registry`: 是否推送到仓库

### 自动构建

推送到 `main` 分支时会自动构建并推送 latest 标签。

### 镜像标签

构建完成后镜像会生成以下标签：
- `sglang-gtx3090:{version}`
- `sglang-gtx3090:cuda12.2-{version}`
- `sglang-gtx3090:latest` (仅 main 分支)

## 宿主机配置 (CentOS 7.9)

### 1. 安装 NVIDIA 驱动 535

```bash
# 禁用 nouveau
sudo bash -c 'echo -e "blacklist nouveau\noptions nouveau modeset=0" > /etc/modprobe.d/blacklist-nouveau.conf'
sudo dracut --force
sudo reboot

# 安装驱动 (从 NVIDIA 官网下载 .run 文件)
sudo systemctl stop multi-user.target
sudo init 3
sudo sh NVIDIA-Linux-x86_64-535.154.05.run
```

### 2. 安装 Docker

```bash
# 安装 Docker
curl -fsSL https://get.docker.com | sh
sudo systemctl enable --now docker

# 添加用户到 docker 组
sudo usermod -aG docker $USER

# 配置 Docker 使用 NVIDIA 运行时
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### 3. 配置 Docker 镜像源加速

```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ],
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  }
}
EOF
sudo systemctl restart docker
```

## 运行 SGLang 容器

### 1. 基础运行

```bash
# 交互式运行
docker run --gpus all --shm-size=32g -it \
  -v /data:/data \
  sglang:gtx3090-cuda12.2 \
  bash
```

### 2. 启动 SGLang 服务

```bash
docker run --gpus all --shm-size=32g -it \
  -p 30000:30000 \
  -v /data:/data \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  sglang:gtx3090-cuda12.2 \
  python -m sglang.launch_server \
    --model-path meta-llama/Llama-2-70b-hf \
    --host 0.0.0.0 \
    --port 30000
```

### 3. 双卡运行

```bash
docker run --gpus '"device=0,1"' --shm-size=64g \
  -p 30000:30000 \
  sglang:gtx3090-cuda12.2 \
  python -m sglang.launch_server \
    --model-path meta-llama/Llama-2-70b-chat-hf \
    --tp 2 \
    --host 0.0.0.0 \
    --port 30000
```

## 验证

### 检查 GPU 访问

```bash
docker run --rm --gpus all sglang:gtx3090-cuda12.2 nvidia-smi
```

### 检查 SGLang

```bash
docker run --rm --gpus all sglang:gtx3090-cuda12.2 \
  python -c "import sglang; print(sglang.__version__)"
```

### 快速推理测试

```bash
docker run --gpus all --shm-size=32g \
  -p 30000:30000 \
  sglang:gtx3090-cuda12.2 \
  python -m sglang.launch_server \
    --model-path meta-llama/Llama-2-7b-hf

# 测试请求
curl http://localhost:30000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-2-7b-hf",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 32
  }'
```

## 注意事项

1. **驱动兼容性**: 535 驱动支持 CUDA 12.2，确保宿主机驱动版本 ≥ 535
2. **共享内存**: 大模型需要足够共享内存，建议 32GB+
3. **双卡配置**: 使用 `--tp 2` 启用张量并行
4. **模型缓存**: 挂载 HuggingFace 缓存目录避免重复下载

## 故障排查

### 问题: nvidia-smi 不可用

```bash
# 检查驱动
nvidia-smi

# 检查 Docker GPU 支持
docker run --rm --gpus all nvidia-smi
```

### 问题: 内存不足

```bash
# 增加共享内存
docker run --gpus all --shm-size=64g ...
```

### 问题: 构建失败

```bash
# 清理 Docker 构建缓存
docker builder prune -a

# 重新构建
docker build --no-cache ...
```
