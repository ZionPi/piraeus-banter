const { app, BrowserWindow, ipcMain, protocol, net } = require('electron');

const path = require("path");
const fs = require("fs").promises;
const fsSync = require("fs");
const os = require("os");
const url = require('url');
const { dialog } = require('electron');
// =================================================================
// 1. WSL2 / Linux 核心崩溃修复补丁 (必须放在最前面)
// =================================================================

// 强制重定向临时目录 (解决 /tmp No such process 报错)
const newTmpDir = path.join(os.homedir(), ".electron-tmp");
try {
  if (!fsSync.existsSync(newTmpDir)) {
    fsSync.mkdirSync(newTmpDir, { recursive: true });
  }
  process.env.TMPDIR = newTmpDir;
  process.env.TEMP = newTmpDir;
  process.env.TMP = newTmpDir;
} catch (e) {
  console.error("Failed to create custom temp dir:", e);
}

// 暴力禁用所有 GPU 和沙盒特性 (解决白屏/渲染进程崩溃)
if (process.platform === "linux") {
  app.disableHardwareAcceleration();
  app.commandLine.appendSwitch("disable-gpu");
  app.commandLine.appendSwitch("disable-gpu-compositing");
  app.commandLine.appendSwitch("no-sandbox");
  app.commandLine.appendSwitch("disable-setuid-sandbox");
  app.commandLine.appendSwitch("disable-dev-shm-usage");
  app.commandLine.appendSwitch("disable-software-rasterizer");
  app.commandLine.appendSwitch("in-process-gpu");
}

process.env["ELECTRON_DISABLE_SECURITY_WARNINGS"] = "true";

// =================================================================
// 2. 项目持久化配置
// =================================================================

// 定义项目存储根目录
const PROJECTS_DIR = path.join(app.getPath("userData"), "Projects");
console.log(">>> Project Directory:", PROJECTS_DIR);
const CONFIG_FILE = path.join(PROJECTS_DIR, 'app-config.json');

// 确保目录存在
try {
  if (!fsSync.existsSync(PROJECTS_DIR)) {
    fsSync.mkdirSync(PROJECTS_DIR, { recursive: true });
  }
} catch (err) {
  console.error(">>> CRITICAL ERROR: Failed to create project directory:", err);
}

// =================================================================
// 3. 窗口创建逻辑
// =================================================================

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 800,
    show: false, // 先隐藏，加载完再显示，防止白屏闪烁
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, "preload.js"), // 确保 preload.js 存在
      sandbox: false, // 配合 WSL2 禁用沙盒
      webSecurity: false
    },
  });

  const isDev = !app.isPackaged;
  const devUrl = "http://localhost:5173";
  const prodPath = path.join(__dirname, "../dist/index.html");

  if (isDev) {
    mainWindow.loadURL(devUrl);
    // 强制打开 DevTools (独立窗口模式)
    mainWindow.webContents.openDevTools({ mode: "detach" });
  } else {
    mainWindow.loadFile(prodPath);
  }

  // 优雅显示窗口
  mainWindow.once("ready-to-show", () => {
    mainWindow.show();
  });

  // 监听渲染进程崩溃
  mainWindow.webContents.on("render-process-gone", (event, details) => {
    console.error(">>> Renderer Process Gone:", details.reason);
  });
}


// =================================================================
// 4. IPC 通信接口 (文件读写)
// =================================================================

protocol.registerSchemesAsPrivileged([
  {
    scheme: 'media',
    privileges: {
      standard: true,    // 表现得像标准协议 (http)
      secure: true,      // 视为安全上下文 (https)
      supportFetchAPI: true,
      bypassCSP: true,   // 绕过内容安全策略
      stream: true       // 支持流式传输 (音频视频必须)
    }
  }
]);

app.whenReady().then(() => {
  // 使用 fs 直接读取，绕过 net.fetch 的潜在 Bug
  protocol.handle('media', async (req) => {
    try {
      let requestUrl = req.url;

      // 1. 去掉 query 参数 (?t=...)
      const queryIndex = requestUrl.indexOf('?');
      if (queryIndex !== -1) {
        requestUrl = requestUrl.slice(0, queryIndex);
      }

      // 2. 核心修复：使用正则去掉协议头和所有开头的斜杠
      // 无论前端传 media://Users 还是 media:///Users，这里都会变成 "Users/zhanngpenng/..."
      let pathToMedia = requestUrl.replace(/^media:\/*/, '');

      // 3. 解码 (处理中文和空格)
      pathToMedia = decodeURIComponent(pathToMedia);

      // 4. 重组绝对路径
      if (process.platform === 'win32') {
        // Windows: 如果没有盘符，可能需要处理，但通常路径里包含盘符
        // 这里保持原样或根据实际情况微调
      } else {
        // macOS/Linux: 必须以 / 开头
        // 现在的 pathToMedia 是 "Users/zhanngpenng/..."，我们补上开头的 "/"
        if (!pathToMedia.startsWith('/')) {
          pathToMedia = '/' + pathToMedia;
        }
      }

      // 5. 调试日志 (现在的路径应该是完美的 /Users/...)
      const fileExists = fsSync.existsSync(pathToMedia);
      console.log(`>>> [Media Load] Raw: "${req.url}"`);
      console.log(`>>> [Media Load] Final: "${pathToMedia}" | Exists: ${fileExists}`);

      if (!fileExists) {
        console.error('>>> [Media Error] File not found on disk.');
        return new Response('File not found', { status: 404 });
      }

      // 6. 读取文件
      const data = await fs.readFile(pathToMedia);
      const ext = path.extname(pathToMedia).toLowerCase();
      let mimeType = 'audio/mpeg';
      if (ext === '.wav') mimeType = 'audio/wav';
      if (ext === '.ogg') mimeType = 'audio/ogg';

      return new Response(data, {
        status: 200,
        headers: {
          'Content-Type': mimeType,
          'Content-Length': data.length.toString(),
          'Access-Control-Allow-Origin': '*',
          'Cache-Control': 'no-cache'
        }
      });

    } catch (error) {
      console.error('>>> [Media Error]:', error);
      return new Response('Internal Error', { status: 500 });
    }
  });

  createWindow();

  // 1. 获取项目列表
  ipcMain.handle("get-projects", async () => {
    try {
      const files = await fs.readdir(PROJECTS_DIR);
      const projects = [];
      for (const file of files) {
        if (file.endsWith(".json")) {
          const content = await fs.readFile(
            path.join(PROJECTS_DIR, file),
            "utf-8"
          );
          try {
            const data = JSON.parse(content);
            projects.push({
              filename: file,
              id: data.id,
              name: data.name || file.replace(".json", ""),
              updatedAt: data.updatedAt || Date.now(),
            });
          } catch (e) { }
        }
      }
      return projects.sort((a, b) => b.updatedAt - a.updatedAt);
    } catch (error) {
      console.error("Get projects failed:", error);
      return [];
    }
  });

  // 2. 保存项目
  ipcMain.handle("save-project", async (event, projectData) => {
    try {
      // 简单的文件名净化，防止非法字符
      const safeName = projectData.name.replace(/[^a-z0-9_\-]/gi, "_");
      const filename = `${safeName}.json`;
      const filePath = path.join(PROJECTS_DIR, filename);

      const dataToSave = { ...projectData, updatedAt: Date.now() };
      await fs.writeFile(
        filePath,
        JSON.stringify(dataToSave, null, 2),
        "utf-8"
      );
      return { success: true, filename };
    } catch (error) {
      console.error("Save failed:", error);
      return { success: false, error: error.message };
    }
  });

  ipcMain.handle('show-save-dialog', async (event, defaultName) => {
    const { filePath, canceled } = await dialog.showSaveDialog(mainWindow, {
      title: 'Export Audio',
      defaultPath: defaultName,
      filters: [
        { name: 'MP3 Audio', extensions: ['mp3'] }
      ]
    });

    if (canceled) return null;
    return filePath;
  });

  // 3. 加载项目
  ipcMain.handle("load-project", async (event, filename) => {
    try {
      const filePath = path.join(PROJECTS_DIR, filename);
      const content = await fs.readFile(filePath, "utf-8");
      return JSON.parse(content);
    } catch (error) {
      console.error("Load failed:", error);
      return null;
    }
  });

  ipcMain.handle("get-projects-dir", () => {
    return PROJECTS_DIR;
  });

  // 4. 删除项目
  ipcMain.handle("delete-project", async (event, filename) => {
    try {
      const filePath = path.join(PROJECTS_DIR, filename);
      await fs.unlink(filePath); // 删除文件
      return true;
    } catch (error) {
      console.error("Delete failed:", error);
      return false;
    }
  });

  // 5. 重命名项目
  ipcMain.handle("rename-project", async (event, { oldFilename, newName }) => {
    try {
      const safeName = newName.replace(/[^a-z0-9_\-]/gi, "_");
      const newFilename = `${safeName}.json`;

      const oldPath = path.join(PROJECTS_DIR, oldFilename);
      const newPath = path.join(PROJECTS_DIR, newFilename);

      // 如果新名字和旧名字不一样，且新名字文件不存在，则重命名
      if (oldPath !== newPath) {
        if (fsSync.existsSync(newPath)) {
          throw new Error("Filename already exists");
        }
        await fs.rename(oldPath, newPath);

        // 同时读取并更新文件内部的 "name" 字段
        const content = await fs.readFile(newPath, "utf-8");
        const data = JSON.parse(content);
        data.name = newName; // 更新内部名字
        await fs.writeFile(newPath, JSON.stringify(data, null, 2), "utf-8");
      }

      return { success: true, newFilename };
    } catch (error) {
      console.error("Rename failed:", error);
      return { success: false, error: error.message };
    }
  });

  ipcMain.handle('save-app-config', async (event, config) => {
    try {
      // 读取旧配置以支持增量更新
      let currentConfig = {};
      if (fsSync.existsSync(CONFIG_FILE)) {
        const content = await fs.readFile(CONFIG_FILE, 'utf-8');
        currentConfig = JSON.parse(content);
      }
      const newConfig = { ...currentConfig, ...config };
      await fs.writeFile(CONFIG_FILE, JSON.stringify(newConfig, null, 2), 'utf-8');
      return true;
    } catch (e) {
      console.error('Save config failed:', e);
      return false;
    }
  });

  // ▼▼▼ 新增：获取应用配置 ▼▼▼
  ipcMain.handle('get-app-config', async () => {
    try {
      if (!fsSync.existsSync(CONFIG_FILE)) return {};
      const content = await fs.readFile(CONFIG_FILE, 'utf-8');
      return JSON.parse(content);
    } catch (e) {
      return {};
    }
  });



  app.on("activate", function () {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", function () {
  if (process.platform !== "darwin") app.quit();
});
