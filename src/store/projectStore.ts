import { create } from "zustand";

export interface Bubble {
  id: string;
  role: "host" | "guest";
  name: string;
  content: string;
  isNonEssential?: boolean;
  topicId?: number;
}

interface ProjectSummary {
  filename: string;
  name: string;
  updatedAt: number;
}

interface ProjectState {
  // 状态
  currentProjectName: string; // 当前文件名
  bubbles: Bubble[];
  hostName: string;
  guestName: string;
  projectList: ProjectSummary[]; // 所有项目列表

  // 动作
  addBubble: (role: "host" | "guest") => void;
  updateBubbleContent: (id: string, content: string) => void;
  deleteBubble: (id: string) => void;

  // 持久化动作
  fetchAllProjects: () => Promise<void>;
  loadProject: (filename: string) => Promise<void>;
  importScript: (jsonString: string, filename?: string) => Promise<void>;
  saveCurrentProject: () => Promise<void>;
  createNewProject: () => Promise<void>;
}

export const useProjectStore = create<ProjectState>((set, get) => ({
  currentProjectName: "New_Project",
  hostName: "Host (Leo)",
  guestName: "Guest (Jane)",
  bubbles: [],
  projectList: [],

  addBubble: (role) =>
    set((state) => ({
      bubbles: [
        ...state.bubbles,
        {
          id: Date.now().toString(),
          role,
          name: role === "host" ? state.hostName : state.guestName,
          content: "",
        },
      ],
    })),

  updateBubbleContent: (id, content) =>
    set((state) => ({
      bubbles: state.bubbles.map((b) => (b.id === id ? { ...b, content } : b)),
    })),

  deleteBubble: (id) =>
    set((state) => ({
      bubbles: state.bubbles.filter((b) => b.id !== id),
    })),

  // --- 1. 获取所有项目 ---
  fetchAllProjects: async () => {
    if (window.electronAPI) {
      const list = await window.electronAPI.getProjects();
      set({ projectList: list });
    }
  },

  // --- 2. 加载特定项目 ---
  loadProject: async (filename) => {
    if (!window.electronAPI) return;
    const data = await window.electronAPI.loadProject(filename);
    if (data) {
      set({
        currentProjectName: data.name,
        bubbles: data.bubbles || [],
        hostName: data.hostName,
        guestName: data.guestName,
      });
    }
  },

  // --- 3. 保存当前项目 ---
  saveCurrentProject: async () => {
    const state = get();
    if (window.electronAPI) {
      const projectData = {
        id: Date.now(), // 简单ID
        name: state.currentProjectName,
        hostName: state.hostName,
        guestName: state.guestName,
        bubbles: state.bubbles,
      };
      await window.electronAPI.saveProject(projectData);
      await get().fetchAllProjects(); // 刷新列表
    }
  },

  // --- 4. 导入并保存 ---
  importScript: async (jsonString, customName) => {
    try {
      const data = JSON.parse(jsonString);
      if (!Array.isArray(data.dialogue_list)) {
        alert("Format Error");
        return;
      }

      const state = get();
      const newBubbles: Bubble[] = data.dialogue_list.map((item: any) => {
        const isHost = item.speaker.toLowerCase().includes("speaker 2");
        return {
          id: item.id.toString(),
          role: isHost ? "host" : "guest",
          name: isHost ? state.hostName : state.guestName,
          content: item.content,
          isNonEssential: item.non_essential_speech,
          topicId: item.topic_id,
        };
      });

      // 生成新项目名 (例如 Import_20231027_1230)
      const newName =
        customName ||
        `Import_${new Date()
          .toISOString()
          .slice(0, 10)
          .replace(/-/g, "")}_${Date.now().toString().slice(-4)}`;

      set({ bubbles: newBubbles, currentProjectName: newName });

      // 立即保存到硬盘
      await get().saveCurrentProject();
    } catch (e) {
      console.error(e);
      alert("Failed to parse JSON.");
    }
  },

  createNewProject: async () => {
    // 1. 生成默认文件名 (例如 New_Project_1738492...)
    const timestamp = Date.now().toString().slice(-6);
    const newName = `New_Project_${timestamp}`;

    // 2. 重置状态 (清空气泡)
    set({
      currentProjectName: newName,
      bubbles: [
        {
          id: "1",
          role: "host",
          name: "Host (Leo)",
          content: "New project created! Start typing...",
        },
      ],
      // 这里的 hostName/guestName 可以保留当前的设置，也可以重置为默认
    });

    // 3. 立即保存到硬盘 (这样侧边栏列表才会刷新出这个新项目)
    await get().saveCurrentProject();
  },
}));
