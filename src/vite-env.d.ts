/// <reference types="vite/client" />

interface Window {
  electronAPI: {
    getProjects: () => Promise<any[]>;
    saveProject: (
      data: any
    ) => Promise<{ success: boolean; filename?: string }>;
    loadProject: (filename: string) => Promise<any>;
    deleteProject: (filename: string) => Promise<boolean>;
    getProjectsDir: () => Promise<string>;
  };
}
