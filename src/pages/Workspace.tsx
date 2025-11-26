// src/pages/Workspace.tsx
import React, { useState } from "react";
import { MainLayout } from "@/layouts/MainLayout";
import { ChatArea } from "@/components/ChatArea";
import { ExportModal } from "@/components/ExportModal";

export const Workspace: React.FC = () => {
  const [isExportOpen, setIsExportOpen] = useState(false);

  return (
    <MainLayout>
      {/* 顶部标题栏 (Header) */}
      <header className="h-16 flex-shrink-0 flex items-center justify-between px-8 border-b border-secondary/20 bg-background-light/80 backdrop-blur-md z-10 sticky top-0">
        <div className="flex items-center gap-3">
          <h2 className="text-xl font-bold text-text-primary tracking-tight">
            Interview with Jane Doe
          </h2>
          <span className="px-2 py-0.5 text-xs bg-secondary/30 text-text-secondary rounded-full">
            Draft
          </span>
        </div>

        <div className="flex gap-2">
          <button
            className="p-2 text-text-secondary hover:text-primary transition-colors rounded-full hover:bg-secondary/20"
            title="Project Settings"
          >
            <span className="material-symbols-outlined">settings</span>
          </button>
          <button
            onClick={() => setIsExportOpen(true)}
            className="p-2 text-text-secondary hover:text-primary transition-colors rounded-full hover:bg-secondary/20"
            title="Export"
          >
            <span className="material-symbols-outlined">ios_share</span>
          </button>
        </div>
      </header>

      {/* 中间对话流区域 */}
      <ChatArea />
      <ExportModal
        isOpen={isExportOpen}
        onClose={() => setIsExportOpen(false)}
      />
    </MainLayout>
  );
};
