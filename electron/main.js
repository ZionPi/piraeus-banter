const { app, BrowserWindow, ipcMain } = require("electron");
const { protocol } = require('electron');
const path = require("path");
const fs = require("fs").promises;
const fsSync = require("fs");
const os = require("os");

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

app.whenReady().then(() => {
  protocol.handle('media', (req) => {
    const pathToMedia = req.url.slice('media://'.length);
    // 处理 Windows 下可能的路径问题，并解码
    const decodedPath = decodeURIComponent(pathToMedia);
    // 使用 net 模块加载本地文件
    return net.fetch(url.pathToFileURL(decodedPath).toString());
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

  ipcMain.handle('get-projects-dir', () => {
    return PROJECTS_DIR;
  });

  app.on("activate", function () {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", function () {
  if (process.platform !== "darwin") app.quit();
});
