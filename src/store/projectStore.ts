import { create } from "zustand";

// ... (Bubble, ProjectSummary 等接口定义保持不变)
export type BubbleStatus = "idle" | "loading" | "success" | "error";

export interface Bubble {
  id: string;
  role: "host" | "guest";
  name: string;
  content: string;
  isNonEssential?: boolean;
  topicId?: number;
  status: BubbleStatus;
  audioPath?: string;
  duration?: number;
  errorMessage?: string;
}

interface ProjectSummary {
  filename: string;
  name: string;
  updatedAt: number;
}

interface ProjectState {
  // ... (状态定义不变)
  currentProjectName: string;
  projectList: ProjectSummary[];
  bubbles: Bubble[];
  hostName: string;
  guestName: string;
  hostVoiceId: string;
  guestVoiceId: string;
  recentVoiceIds: string[];

  isPlaying: boolean;
  currentPlayingId: string | null;

  isExportModalOpen: boolean;
  openExportModal: () => void;
  closeExportModal: () => void;

  // ... (动作定义不变)
  clearWorkspace: () => void;
  addBubble: (role: "host" | "guest") => void;
  updateBubbleContent: (id: string, content: string) => void;
  deleteBubble: (id: string) => void;
  updateHostName: (name: string) => void;
  updateGuestName: (name: string) => void;
  setVoice: (role: "host" | "guest", voiceId: string) => void;
  fetchAllProjects: () => Promise<void>;
  loadProject: (filename: string) => Promise<void>;
  importScript: (jsonString: string, filename?: string) => Promise<void>;
  createNewProject: () => Promise<void>;
  saveCurrentProject: () => Promise<void>;
  generateAudio: (bubbleId: string) => Promise<void>;
  generateAll: () => Promise<void>;
  getExportData: () => { audioFiles: string[]; duration: number };
  renameCurrentProject: (newName: string) => Promise<void>;
  deleteProjectFile: (filename: string) => Promise<void>;

  togglePlayback: () => void;

  exportFullAudio: () => Promise<string | null>; // 返回导出的文件路径
}

// 辅助函数：检查文本是否包含有效语音内容 (汉字、字母、数字)
const hasValidSpeech = (text: string) => {
  return /[a-zA-Z0-9\u4e00-\u9fa5]/.test(text);
};


// 辅助函数：净化文件名 (放在文件顶部或者 generateAudio 内部)
const sanitizeName = (name: string) => name.replace(/[^a-z0-9_\u4e00-\u9fa5\-]/gi, '_');
// 辅助函数：睡眠
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

let audioPlayer: HTMLAudioElement | null = null;
let playlist: Bubble[] = [];
let currentPlaylistIndex = -1;

export const useProjectStore = create<ProjectState>((set, get) => ({
  // ... (初始状态保持不变)
  currentProjectName: "New_Project",
  projectList: [],
  bubbles: [],
  hostName: "Host (Leo)",
  guestName: "Guest (Jane)",
  hostVoiceId: "zh_female_inspirational",
  guestVoiceId: "zh_male_huolijieshuo",
  recentVoiceIds: ["zh_female_inspirational", "zh_male_huolijieshuo"],

  isPlaying: false,
  currentPlayingId: null,
  isExportModalOpen: false,

  openExportModal: () => set({ isExportModalOpen: true }),
  closeExportModal: () => set({ isExportModalOpen: false }),

  // ... (addBubble, updateBubbleContent, deleteBubble, updateHostName, updateGuestName, setVoice 保持不变)
  addBubble: (role) =>
    set((state) => ({
      bubbles: [
        ...state.bubbles,
        {
          id: Date.now().toString(),
          role,
          name: role === "host" ? state.hostName : state.guestName,
          content: "",
          status: "idle",
        },
      ],
    })),

  updateBubbleContent: (id, content) =>
    set((state) => ({
      bubbles: state.bubbles.map((b) =>
        b.id === id ? { ...b, content, status: "idle" } : b
      ),
    })),

  deleteBubble: (id) =>
    set((state) => ({
      bubbles: state.bubbles.filter((b) => b.id !== id),
    })),

  updateHostName: (name) => {
    set((state) => ({
      hostName: name,
      bubbles: state.bubbles.map((b) =>
        b.role === "host" ? { ...b, name: name } : b
      ),
    }));
    get().saveCurrentProject();
  },

  updateGuestName: (name) => {
    set((state) => ({
      guestName: name,
      bubbles: state.bubbles.map((b) =>
        b.role === "guest" ? { ...b, name: name } : b
      ),
    }));
    get().saveCurrentProject();
  },

  setVoice: (role, voiceId) => {
    set((state) => {
      const newRecents = [
        voiceId,
        ...state.recentVoiceIds.filter((id) => id !== voiceId),
      ].slice(0, 8);
      return {
        hostVoiceId: role === "host" ? voiceId : state.hostVoiceId,
        guestVoiceId: role === "guest" ? voiceId : state.guestVoiceId,
        recentVoiceIds: newRecents,
      };
    });
    get().saveCurrentProject();
  },

  // ... (fetchAllProjects, createNewProject 保持不变)
  fetchAllProjects: async () => {
    if (window.electronAPI) {
      const list = await window.electronAPI.getProjects();
      set({ projectList: list });
    }
  },

  createNewProject: async () => {
    const timestamp = Date.now().toString().slice(-6);
    const newName = `New_Project_${timestamp}`;
    set({
      currentProjectName: newName,
      bubbles: [
        {
          id: "1",
          role: "host",
          name: "Host",
          content: "Start creating...",
          status: "idle",
        },
      ],
      hostVoiceId: "zh_female_inspirational",
      guestVoiceId: "zh_male_huolijieshuo",
    });
    await get().saveCurrentProject();
  },

  // ✅ 修复：Load Project 时，重置 stuck 状态
  loadProject: async (filename) => {
    if (!window.electronAPI) return;
    const data = await window.electronAPI.loadProject(filename);
    if (data) {
      // 修复逻辑：如果有气泡卡在 'loading' 状态 (可能是意外退出导致)，重置为 'idle'
      const fixedBubbles = (data.bubbles || []).map((b: Bubble) => ({
        ...b,
        status: b.status === "loading" ? "idle" : b.status,
      }));

      set({
        currentProjectName: data.name,
        bubbles: fixedBubbles,
        hostName: data.hostName || "Host (Leo)",
        guestName: data.guestName || "Guest (Jane)",
        hostVoiceId: data.hostVoiceId || "zh_female_inspirational",
        guestVoiceId: data.guestVoiceId || "zh_male_huolijieshuo",
        recentVoiceIds: data.recentVoiceIds || [],
      });
    }
  },

  // ... (importScript, saveCurrentProject 保持不变)
  saveCurrentProject: async () => {
    const state = get();
    if (window.electronAPI) {
      const projectData = {
        id: Date.now(),
        name: state.currentProjectName,
        hostName: state.hostName,
        guestName: state.guestName,
        hostVoiceId: state.hostVoiceId,
        guestVoiceId: state.guestVoiceId,
        recentVoiceIds: state.recentVoiceIds,
        bubbles: state.bubbles,
      };
      await window.electronAPI.saveProject(projectData);
      await get().fetchAllProjects();
    }
  },

  importScript: async (jsonString, customName) => {
    try {
      const data = JSON.parse(jsonString);
      if (!Array.isArray(data.dialogue_list)) return;

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
          status: "idle",
        };
      });

      const newName = customName || `Import_${Date.now().toString().slice(-6)}`;
      set({ bubbles: newBubbles, currentProjectName: newName });
      await get().saveCurrentProject();
    } catch (e) {
      console.error(e);
    }
  },


  // ✅ 优化：单条生成逻辑 (增加内容检查)
  generateAudio: async (bubbleId) => {
    const state = get();
    const bubble = state.bubbles.find((b) => b.id === bubbleId);
    if (!bubble) return;

    // 1. 检查是否是无效内容 (如 "......", "？")
    if (!hasValidSpeech(bubble.content)) {
      set((state) => ({
        bubbles: state.bubbles.map((b) =>
          b.id === bubbleId
            ? {
              ...b,
              status: "error",
              errorMessage: "No speech content",
            }
            : b
        ),
      }));
      return; // 终止，不请求后端
    }

    set((state) => ({
      bubbles: state.bubbles.map((b) =>
        b.id === bubbleId
          ? { ...b, status: "loading", errorMessage: undefined }
          : b
      ),
    }));

    try {
      let projectsDir = "";
      if (window.electronAPI) {
        projectsDir = await window.electronAPI.getProjectsDir();
      }

      const speakerId =
        bubble.role === "host" ? state.hostVoiceId : state.guestVoiceId;

      const uniqueFileId = `${sanitizeName(state.currentProjectName)}_${bubble.id}`;

      const response = await fetch("http://127.0.0.1:8000/api/generate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          text: bubble.content,
          speaker: speakerId,
          project_path: projectsDir,
          bubble_id: uniqueFileId,
          app_key: "",
          access_token: "",
        }),
      });

      if (!response.ok) {
        const errData = await response.json();
        throw new Error(errData.detail || "API Error");
      }

      const data = await response.json();

      if (data.success) {
        set((state) => ({
          bubbles: state.bubbles.map((b) =>
            b.id === bubbleId
              ? {
                ...b,
                status: "success",
                audioPath: data.audio_path,
                duration: data.duration,
              }
              : b
          ),
        }));
      }
    } catch (e: any) {
      console.error(e);
      set((state) => ({
        bubbles: state.bubbles.map((b) =>
          b.id === bubbleId
            ? {
              ...b,
              status: "error",
              errorMessage: "Failed",
            }
            : b
        ),
      }));
    }

    get().saveCurrentProject();
  },

  // ✅ 优化：批量生成 (防封号策略 + 断点续传)
  generateAll: async () => {
    const state = get();
    // 只找未成功的 (idle 或 error)，这样如果中断了，下次点这个按钮只会跑剩下的
    const bubblesToGen = state.bubbles.filter(
      (b) => b.status !== "success" && b.status !== "loading"
    );

    if (bubblesToGen.length === 0) return;

    console.log(
      `Starting batch generation for ${bubblesToGen.length} bubbles...`
    );

    for (const bubble of bubblesToGen) {
      // 检查应用是否还在运行，或者是否需要中断 (可选优化)

      await get().generateAudio(bubble.id);

      // 防封号策略：每条之间休息 500ms
      await sleep(500);
    }
  },

  getExportData: () => {
    const state = get();
    const validBubbles = state.bubbles.filter(
      (b) => b.status === "success" && b.audioPath
    );
    return {
      audioFiles: validBubbles.map((b) => b.audioPath!),
      duration: validBubbles.reduce(
        (acc, curr) => acc + (curr.duration || 0),
        0
      ),
    };
  },

  renameCurrentProject: async (newName) => {
    const state = get();
    if (!newName.trim()) return;

    // 假设当前项目的文件名是基于旧名字生成的，或者我们在 loadProject 时应该记录当前 filename
    // 为了简化，我们这里做一个假设：文件名就是 "CurrentName.json" 的格式
    // 更严谨的做法是在 Store 里存一个 `currentFilename` 状态，建议你加上

    // 临时策略：根据 currentProjectName 推导旧文件名 (注意：这要求之前保存时也是这个规则)
    const oldSafeName = state.currentProjectName.replace(/[^a-z0-9_\-]/gi, "_");
    const oldFilename = `${oldSafeName}.json`;

    if (window.electronAPI) {
      const result = await window.electronAPI.renameProject(
        oldFilename,
        newName
      );
      if (result.success) {
        set({ currentProjectName: newName });
        await get().fetchAllProjects(); // 刷新侧边栏列表
      } else {
        alert("Rename failed: " + (result.error || "Unknown error"));
      }
    }
  },

  clearWorkspace: () => {
    set({
      bubbles: [], // 清空气泡
      currentProjectName: "No Project Selected", // 更新标题
    });
  },

  deleteProjectFile: async (filename) => {
    if (window.electronAPI) {
      const success = await window.electronAPI.deleteProject(filename);

      if (success) {
        // 1. 先获取最新的项目列表 (此时文件已删，列表会少一个)
        const remainingList = await window.electronAPI.getProjects();
        set({ projectList: remainingList });

        // 2. 判断刚才删除的是不是“当前正在编辑”的项目
        const state = get();
        // 推导当前文件名 (确保逻辑一致)
        const currentSafeName = state.currentProjectName.replace(
          /[^a-z0-9_\-]/gi,
          "_"
        );
        const currentFilename = `${currentSafeName}.json`;

        if (filename === currentFilename) {
          // ⚠️ 情况 A: 删除了当前项目 -> 需要找个“替补”
          if (remainingList.length > 0) {
            // 如果还有其他项目，自动加载列表里的第一个
            console.log(
              "Deleted active project, switching to next available..."
            );
            await get().loadProject(remainingList[0].filename);
          } else {
            // 如果删光了，清空
            console.log("All projects deleted");
            get().clearWorkspace();
          }
        } else {
          // ⚠️ 情况 B: 删除的是列表里的其他项目 -> 不需要做任何跳转
          console.log("Deleted background project, staying put.");
        }
      }
    }
  },

  togglePlayback: () => {
    const state = get();

    // 1. 如果正在播放 -> 暂停
    if (state.isPlaying) {
      if (audioPlayer) audioPlayer.pause();
      set({ isPlaying: false });
      return;
    }

    // 2. 如果暂停中 -> 恢复
    if (audioPlayer && audioPlayer.readyState > 0 && !audioPlayer.ended) {
      audioPlayer.play();
      set({ isPlaying: true });
      return;
    }

    // 3. 否则 -> 从头开始播放
    // 筛选出所有“已生成”的气泡
    playlist = state.bubbles.filter(b => b.status === 'success' && b.audioPath);

    if (playlist.length === 0) {
      alert("Please generate audio first.");
      return;
    }

    currentPlaylistIndex = 0;

    // 递归播放函数
    const playNextTrack = () => {
      // 检查边界
      if (currentPlaylistIndex >= playlist.length) {
        console.log("Playback finished.");
        set({ isPlaying: false, currentPlayingId: null });
        audioPlayer = null;
        return;
      }

      const bubble = playlist[currentPlaylistIndex];
      set({ isPlaying: true, currentPlayingId: bubble.id });

      // 使用 media:// 协议 (注意 Windows 路径转换)
      const normalizedPath = bubble.audioPath!.replace(/\\/g, '/');
      const audioUrl = `media://${normalizedPath}?t=${Date.now()}`;

      // 清理旧监听器
      if (audioPlayer) {
        audioPlayer.onended = null;
        audioPlayer.onerror = null;
      }

      audioPlayer = new Audio(audioUrl);

      // 监听播放结束 -> 播下一个
      audioPlayer.onended = () => {
        currentPlaylistIndex++;
        playNextTrack();
      };

      // 监听错误 -> 跳过，播下一个
      audioPlayer.onerror = (e) => {
        console.error("Playback error for bubble:", bubble.id, e);
        currentPlaylistIndex++;
        playNextTrack();
      };

      // 开始播放
      audioPlayer.play().catch(e => {
        console.error("Play failed:", e);
        set({ isPlaying: false });
      });
    };

    // 启动
    playNextTrack();
  },

  exportFullAudio: async () => {
    const state = get();

    // 1. ▼▼▼ 检查是否有“掉队”的气泡 ▼▼▼
    const totalBubbles = state.bubbles.length;
    // 有效气泡：必须是 success 且有路径
    const validBubbles = state.bubbles.filter(b => b.status === 'success' && b.audioPath);
    const missingCount = totalBubbles - validBubbles.length;

    if (validBubbles.length === 0) {
      alert("No audio generated yet. Please generate audio first.");
      return null;
    }

    // 如果有未生成的，弹窗警告用户
    if (missingCount > 0) {
      const confirmExport = confirm(
        `⚠️ Warning: ${missingCount} bubbles are NOT generated yet.\n\nThey will be skipped in the export.\nDo you want to continue?`
      );
      if (!confirmExport) return null; // 用户取消
    }

    const audioFiles = validBubbles.map(b => b.audioPath!);

    try {
      if (!window.electronAPI) return null;

      const defaultName = `${state.currentProjectName}_Full.mp3`;
      const savePath = await window.electronAPI.showSaveDialog(defaultName);

      if (!savePath) return null; // 用户点击了取消

      let projectsDir = await window.electronAPI.getProjectsDir();

      // 3. 调用后端 (传入用户选择的 savePath)
      const response = await fetch('http://127.0.0.1:8000/api/export/audio', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          project_path: projectsDir,
          audio_files: audioFiles,
          output_path: savePath, // <--- 传绝对路径
          gap_ms: 300
        }),
      });

      if (!response.ok) throw new Error("Export API Failed");

      const data = await response.json();
      if (data.success) {
        return data.output_path;
      }

    } catch (e) {
      console.error("Export error:", e);
      alert("Export failed.");
    }
    return null;
  }


}));
