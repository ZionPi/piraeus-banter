import React, { useEffect, useState } from 'react';
import { MainLayout } from '@/layouts/MainLayout';
import { ChatArea } from '@/components/ChatArea';
import { ExportModal } from '@/components/ExportModal';
import { useProjectStore } from '@/store/projectStore';

export const Workspace: React.FC = () => {
  const { currentProjectName, renameCurrentProject, isExportModalOpen, openExportModal, closeExportModal } = useProjectStore();

  const [titleValue, setTitleValue] = useState(currentProjectName);

  useEffect(() => {
    setTitleValue(currentProjectName);
  }, [currentProjectName]);

  const handleBlur = () => {
    if (titleValue !== currentProjectName) {
      renameCurrentProject(titleValue);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') e.currentTarget.blur();
  };

  return (
    <MainLayout>
      <header className="h-16 flex-shrink-0 flex items-center justify-between px-8 border-b border-secondary/20 bg-background-light/80 backdrop-blur-md z-10 sticky top-0">
        <div className="flex items-center gap-3 flex-1">
          <input
            type="text"
            value={titleValue}
            onChange={(e) => setTitleValue(e.target.value)}
            onBlur={handleBlur}
            onKeyDown={handleKeyDown}
            className="text-xl font-bold text-text-primary tracking-tight bg-transparent border border-transparent hover:border-secondary/30 focus:border-primary focus:bg-white/50 rounded px-2 py-1 outline-none transition-all w-full max-w-md truncate"
          />
          <span className="px-2 py-0.5 text-xs bg-secondary/30 text-text-secondary rounded-full flex-shrink-0">Draft</span>
        </div>

        <div className="flex gap-2">
          {/* ▼▼▼ 修改：使用 Store 的方法 ▼▼▼ */}
          <button
            onClick={openExportModal}
            className="p-2 text-text-secondary hover:text-primary transition-colors rounded-full hover:bg-secondary/20"
            title="Export"
          >
            <span className="material-symbols-outlined">ios_share</span>
          </button>
        </div>
      </header>

      <ChatArea />

      {/* ▼▼▼ 修改：从 Store 读取状态 ▼▼▼ */}
      <ExportModal isOpen={isExportModalOpen} onClose={closeExportModal} />
    </MainLayout>
  );
};