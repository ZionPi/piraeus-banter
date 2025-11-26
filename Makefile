# 项目配置
PROJECT_NAME := piraeus-banter
# 如果你想显式指定环境，可以解开下面这行，否则默认使用当前激活的 Shell 环境
# CONDA_ENV := base

# 默认 Shell
SHELL := /bin/bash

.PHONY: help install dev run-backend run-frontend clean

help: ## 显示此帮助信息
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## [初始化] 安装依赖 (使用当前 Python 环境)
	@echo ">>> 检查 Python 版本..."
	@python --version
	@echo ">>> 安装前端依赖 (pnpm)..."
	pnpm install
	@echo ">>> 安装后端依赖 (pip)..."
	pip install -r backend/requirements.txt

dev: ## [开发] 同时启动前端和后端 (推荐)
	@echo "正在启动开发环境..."
	@echo "提示：按 Ctrl+C 停止"
	@# 检查是否安装了 concurrently (通常在前端 devDependencies 中)
	@# 如果 npm run dev 能跑起来，这里就用 npx concurrently
	npx concurrently "make run-backend" "make run-frontend" --names "API,UI" --prefix-colors "blue,magenta"

run-backend: ## [开发] 单独启动 Python 后端服务
	@echo "启动 FastAPI 后端 (Port: 8000)..."
	@# 使用 uvicorn 启动，--reload 支持代码热更新
	uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000

run-frontend: ## [开发] 单独启动 Electron/React 前端
	@echo "启动 Vite 前端..."
	pnpm dev

clean: ## [清理] 清理缓存和构建文件
	@echo "清理临时文件..."
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	rm -rf dist dist-electron release
	@echo "清理完成"