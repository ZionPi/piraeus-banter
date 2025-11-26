import React, { ReactNode } from "react";
import { Sidebar } from "@/components/Sidebar";
import { PlayerControl } from "@/components/PlayerControl";

interface MainLayoutProps {
  children: ReactNode;
}

export const MainLayout: React.FC<MainLayoutProps> = ({ children }) => {
  return (
    // 🔴 最外层：强制占满屏幕，禁止溢出 (overflow-hidden)
    <div className="flex h-screen w-screen flex-col overflow-hidden bg-background-light font-display text-text-primary">
      {/* 🔵 中间主体层：水平排列 */}
      <div className="flex flex-1 w-full flex-row overflow-hidden min-h-0">
        {/* 左侧 Sidebar：固定宽度，高度自动填满，自己内部滚动 */}
        <div className="flex-shrink-0 h-full">
          <Sidebar />
        </div>

        {/* 右侧主内容：占据剩余空间 */}
        {/* 关键：min-w-0 防止被子元素撑大 */}
        {/* 关键：relative 确保内部绝对定位元素以它为基准 */}
        <main className="flex flex-1 flex-col min-w-0 h-full bg-background-light relative overflow-hidden">
          {children}
        </main>
      </div>

      {/* 底部播放器：固定高度，不参与挤压 */}
      <div className="w-full flex-shrink-0 z-50">
        <PlayerControl />
      </div>
    </div>
  );
};
