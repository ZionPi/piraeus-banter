import React, { useState, useEffect } from "react";
import { MainLayout } from "@/layouts/MainLayout";
import { ChatArea } from "@/components/ChatArea";
import { ExportModal } from "@/components/ExportModal";
import { useProjectStore } from "@/store/projectStore";

export const Workspace: React.FC = () => {
  const [isExportOpen, setIsExportOpen] = useState(false);

  const { currentProjectName, renameCurrentProject } = useProjectStore();

  // 本地状态用于输入框显示
  const [titleValue, setTitleValue] = useState(currentProjectName);

  // 当 Store 变了（比如加载了新项目），同步更新输入框
  useEffect(() => {
    setTitleValue(currentProjectName);
  }, [currentProjectName]);

  const handleBlur = () => {
    if (titleValue !== currentProjectName) {
      renameCurrentProject(titleValue);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter") {
      e.currentTarget.blur(); // 触发 blur 保存
    }
  };

  return (
    <MainLayout>
      <header className="h-16 flex-shrink-0 flex items-center justify-between px-8 border-b border-secondary/20 bg-background-light/80 backdrop-blur-md z-10 sticky top-0">
        <div className="flex items-center gap-3 flex-1">
          {/* ▼▼▼ 可编辑标题 ▼▼▼ */}
          <input
            type="text"
            value={titleValue}
            onChange={(e) => setTitleValue(e.target.value)}
            onBlur={handleBlur}
            onKeyDown={handleKeyDown}
            className="text-xl font-bold text-text-primary tracking-tight bg-transparent border border-transparent hover:border-secondary/30 focus:border-primary focus:bg-white/50 rounded px-2 py-1 outline-none transition-all w-full max-w-md truncate"
            title="Click to rename project"
          />

          <span className="px-2 py-0.5 text-xs bg-secondary/30 text-text-secondary rounded-full flex-shrink-0">
            Draft
          </span>
        </div>

        <div className="flex gap-2">
          <button
            onClick={() => setIsExportOpen(true)}
            className="p-2 text-text-secondary hover:text-primary transition-colors rounded-full hover:bg-secondary/20"
            title="Export"
          >
            <span className="material-symbols-outlined">ios_share</span>
          </button>
        </div>
      </header>

      <ChatArea />

      <ExportModal
        isOpen={isExportOpen}
        onClose={() => setIsExportOpen(false)}
      />
    </MainLayout>
  );
};
