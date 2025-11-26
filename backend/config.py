import os
from dotenv import load_dotenv

# 加载 .env 文件
# override=True 表示 .env 里的值会覆盖系统环境变量
load_dotenv(override=True)

class Config:
    # 字节跳动配置
    BYTEDANCE_APPKEY = os.getenv("BYTEDANCE_APPKEY", "")
    BYTEDANCE_ACCESS_TOKEN = os.getenv("BYTEDANCE_ACCESS_TOKEN", "")
    
    # Google 配置
    GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY", "")
    
    # 服务配置
    HOST = os.getenv("HOST", "127.0.0.1")
    PORT = int(os.getenv("PORT", 8000))
    
    # 项目存储路径 (默认在用户目录下，也可以通过环境变量改)
    # 注意：这个路径主要用于 Python 本地测试，Electron 运行时会传入它自己的路径
    DEFAULT_PROJECT_DIR = os.path.join(os.path.expanduser("~"), "Piraeus Banter Projects")

config = Config()