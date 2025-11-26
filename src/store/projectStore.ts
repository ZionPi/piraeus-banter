import { create } from 'zustand';

// ... (Bubble, ProjectSummary 等接口定义保持不变)
export type BubbleStatus = 'idle' | 'loading' | 'success' | 'error';

export interface Bubble {
  id: string;
  role: 'host' | 'guest';
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

  // ... (动作定义不变)
  addBubble: (role: 'host' | 'guest') => void;
  updateBubbleContent: (id: string, content: string) => void;
  deleteBubble: (id: string) => void;
  updateHostName: (name: string) => void;
  updateGuestName: (name: string) => void;
  setVoice: (role: 'host' | 'guest', voiceId: string) => void;
  fetchAllProjects: () => Promise<void>;
  loadProject: (filename: string) => Promise<void>;
  importScript: (jsonString: string, filename?: string) => Promise<void>;
  createNewProject: () => Promise<void>;
  saveCurrentProject: () => Promise<void>;
  generateAudio: (bubbleId: string) => Promise<void>;
  generateAll: () => Promise<void>;
  getExportData: () => { audioFiles: string[], duration: number };
}

// 辅助函数：检查文本是否包含有效语音内容 (汉字、字母、数字)
const hasValidSpeech = (text: string) => {
  return /[a-zA-Z0-9\u4e00-\u9fa5]/.test(text);
};

// 辅助函数：睡眠
const sleep = (ms: number) => new Promise(r => setTimeout(r, ms));

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

  // ... (addBubble, updateBubbleContent, deleteBubble, updateHostName, updateGuestName, setVoice 保持不变)
  addBubble: (role) => set((state) => ({
    bubbles: [...state.bubbles, {
      id: Date.now().toString(),
      role,
      name: role === 'host' ? state.hostName : state.guestName,
      content: '',
      status: 'idle'
    }]
  })),

  updateBubbleContent: (id, content) => set((state) => ({
    bubbles: state.bubbles.map((b) =>
      b.id === id ? { ...b, content, status: 'idle' } : b
    )
  })),

  deleteBubble: (id) => set((state) => ({
    bubbles: state.bubbles.filter((b) => b.id !== id)
  })),

  updateHostName: (name) => {
    set((state) => ({
      hostName: name,
      bubbles: state.bubbles.map(b => b.role === 'host' ? { ...b, name: name } : b)
    }));
    get().saveCurrentProject();
  },

  updateGuestName: (name) => {
    set((state) => ({
      guestName: name,
      bubbles: state.bubbles.map(b => b.role === 'guest' ? { ...b, name: name } : b)
    }));
    get().saveCurrentProject();
  },

  setVoice: (role, voiceId) => {
    set((state) => {
      const newRecents = [voiceId, ...state.recentVoiceIds.filter(id => id !== voiceId)].slice(0, 8);
      return {
        hostVoiceId: role === 'host' ? voiceId : state.hostVoiceId,
        guestVoiceId: role === 'guest' ? voiceId : state.guestVoiceId,
        recentVoiceIds: newRecents
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
      bubbles: [{
        id: '1',
        role: 'host',
        name: 'Host',
        content: "Start creating...",
        status: 'idle'
      }],
      hostVoiceId: "zh_female_inspirational",
      guestVoiceId: "zh_male_huolijieshuo"
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
        status: b.status === 'loading' ? 'idle' : b.status
      }));

      set({
        currentProjectName: data.name,
        bubbles: fixedBubbles,
        hostName: data.hostName || "Host (Leo)",
        guestName: data.guestName || "Guest (Jane)",
        hostVoiceId: data.hostVoiceId || "zh_female_inspirational",
        guestVoiceId: data.guestVoiceId || "zh_male_huolijieshuo",
        recentVoiceIds: data.recentVoiceIds || []
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
        bubbles: state.bubbles
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
        const isHost = item.speaker.toLowerCase().includes('speaker 2');
        return {
          id: item.id.toString(),
          role: isHost ? 'host' : 'guest',
          name: isHost ? state.hostName : state.guestName,
          content: item.content,
          isNonEssential: item.non_essential_speech,
          topicId: item.topic_id,
          status: 'idle'
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
    const bubble = state.bubbles.find(b => b.id === bubbleId);
    if (!bubble) return;

    // 1. 检查是否是无效内容 (如 "......", "？")
    if (!hasValidSpeech(bubble.content)) {
      set((state) => ({
        bubbles: state.bubbles.map(b => b.id === bubbleId ? {
          ...b,
          status: 'error',
          errorMessage: "No speech content"
        } : b)
      }));
      return; // 终止，不请求后端
    }

    set((state) => ({
      bubbles: state.bubbles.map(b => b.id === bubbleId ? { ...b, status: 'loading', errorMessage: undefined } : b)
    }));

    try {
      let projectsDir = '';
      if (window.electronAPI) {
        projectsDir = await window.electronAPI.getProjectsDir();
      }

      const speakerId = bubble.role === 'host' ? state.hostVoiceId : state.guestVoiceId;

      const response = await fetch('http://127.0.0.1:8000/api/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          text: bubble.content,
          speaker: speakerId,
          project_path: projectsDir,
          bubble_id: bubble.id,
          app_key: "",
          access_token: ""
        }),
      });

      if (!response.ok) {
        const errData = await response.json();
        throw new Error(errData.detail || 'API Error');
      }

      const data = await response.json();

      if (data.success) {
        set((state) => ({
          bubbles: state.bubbles.map(b => b.id === bubbleId ? {
            ...b,
            status: 'success',
            audioPath: data.audio_path,
            duration: data.duration
          } : b)
        }));
      }

    } catch (e: any) {
      console.error(e);
      set((state) => ({
        bubbles: state.bubbles.map(b => b.id === bubbleId ? {
          ...b,
          status: 'error',
          errorMessage: "Failed"
        } : b)
      }));
    }

    get().saveCurrentProject();
  },

  // ✅ 优化：批量生成 (防封号策略 + 断点续传)
  generateAll: async () => {
    const state = get();
    // 只找未成功的 (idle 或 error)，这样如果中断了，下次点这个按钮只会跑剩下的
    const bubblesToGen = state.bubbles.filter(b => b.status !== 'success' && b.status !== 'loading');

    if (bubblesToGen.length === 0) return;

    console.log(`Starting batch generation for ${bubblesToGen.length} bubbles...`);

    for (const bubble of bubblesToGen) {
      // 检查应用是否还在运行，或者是否需要中断 (可选优化)

      await get().generateAudio(bubble.id);

      // 防封号策略：每条之间休息 500ms
      await sleep(500);
    }
  },

  getExportData: () => {
    const state = get();
    const validBubbles = state.bubbles.filter(b => b.status === 'success' && b.audioPath);
    return {
      audioFiles: validBubbles.map(b => b.audioPath!),
      duration: validBubbles.reduce((acc, curr) => acc + (curr.duration || 0), 0)
    };
  }
}));