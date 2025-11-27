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

app.whenReady().then(() => {
  protocol.handle('media', (req) => {
    try {
      let requestUrl = req.url;

      // 1. 打印原始请求，看看有没有带 ?t=...
      console.log('>>> [Media Req Raw]:', requestUrl);

      // 2. 剥离 query 参数 (比如 ?t=17123884)
      const queryIndex = requestUrl.indexOf('?');
      if (queryIndex !== -1) {
        requestUrl = requestUrl.slice(0, queryIndex);
      }

      // 3. 提取路径
      let pathToMedia = requestUrl.slice('media://'.length);

      // 4. 解码 (处理空格 %20)
      pathToMedia = decodeURIComponent(pathToMedia);

      // 5. Windows 兼容修复
      if (process.platform === 'win32' && pathToMedia.startsWith('/') && !pathToMedia.startsWith('//')) {
        pathToMedia = pathToMedia.slice(1);
      }

      // 6. 打印最终解析路径
      console.log('>>> [Media Path Final]:', pathToMedia);

      // 7. 加载文件
      const fileUrl = url.pathToFileURL(pathToMedia).toString();
      return net.fetch(fileUrl);

    } catch (error) {
      console.error('>>> [Media Error]:', error);
      return new Response('Failed to load media', { status: 500 });
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

  app.on("activate", function () {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", function () {
  if (process.platform !== "darwin") app.quit();
});
