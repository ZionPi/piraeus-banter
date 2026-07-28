# 项目配置
PROJECT_NAME := piraeus-banter
# ▼▼▼ 指定新环境名称 ▼▼▼
CONDA_ENV := piraeus-banter

# 默认 Shell
SHELL := /bin/bash

.PHONY: help install dev run-backend run-frontend mobile-deps mobile-analyze mobile-release-apk mobile-clean clean

help: ## 显示此帮助信息
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## [初始化] 安装依赖 (安装到 piraeus-banter 环境)
	@echo ">>> 正在为环境 $(CONDA_ENV) 安装依赖..."
	@# 这里的逻辑是：如果环境没激活，尝试用 conda run 执行 pip
	pnpm install
	conda run -n $(CONDA_ENV) pip install -r backend/requirements.txt

dev: ## [开发] 同时启动前端和后端
	@echo "正在启动开发环境..."
	npx concurrently "make run-backend" "make run-frontend" --names "API,UI" --prefix-colors "blue,magenta"

run-backend: ## [开发] 启动 Python 后端
	@echo "启动 FastAPI 后端..."
	@# 加上 --no-capture-output 让日志实时吐出来
	conda run --no-capture-output -n $(CONDA_ENV) uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000

run-frontend: ## [开发] 启动 Electron/React 前端
	@echo "启动 Vite 前端..."
# 	pnpm dev
	npm run electron:dev

mobile-deps: ## [Mobile] 安装 Flutter 依赖
	$(MAKE) -C mobile deps

mobile-analyze: ## [Mobile] 静态检查 Android/Flutter 代码
	cd mobile && flutter analyze

mobile-release-apk: ## [Mobile] 构建 Android release APK
	$(MAKE) -C mobile release-apk

mobile-clean: ## [Mobile] 清理 Flutter 构建产物
	$(MAKE) -C mobile clean

clean: ## [清理]
	find . -type d -name "__pycache__" -exec rm -rf {} +
	rm -rf dist dist-electron release