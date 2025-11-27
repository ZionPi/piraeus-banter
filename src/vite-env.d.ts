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
    showSaveDialog: (defaultName: string) => Promise<string | null>;

    renameProject: (
      oldFilename: string,
      newName: string
    ) => Promise<{ success: boolean; newFilename?: string }>;
  };
}
