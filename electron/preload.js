// electron/preload.js
const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("electronAPI", {
  // 获取项目列表
  getProjects: () => ipcRenderer.invoke("get-projects"),
  // 创建/保存项目
  saveProject: (projectData) => ipcRenderer.invoke("save-project", projectData),
  // 加载特定项目
  loadProject: (filename) => ipcRenderer.invoke("load-project", filename),
  // 删除项目
  deleteProject: (filename) => ipcRenderer.invoke("delete-project", filename),

  getProjectsDir: () => ipcRenderer.invoke('get-projects-dir'),

});
