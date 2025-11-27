import React from "react";
import { useProjectStore } from "@/store/projectStore"; // 1. 引入 Store
import { cn } from "@/utils/cn";

export const PlayerControl: React.FC = () => {
  // 2. 从 Store 获取状态和方法
  const { isPlaying, togglePlayback, openExportModal } = useProjectStore();

  return (
    <footer className="flex h-20 w-full flex-shrink-0 items-center justify-between border-t border-secondary/30 bg-surface px-6 shadow-[0_-2px_10px_rgba(0,0,0,0.03)] select-none">
      {/* 播放按钮组 */}
      <div className="flex items-center gap-4 w-1/4">
        <button className="text-text-secondary hover:text-primary transition-colors p-2 rounded-full">
          <span className="material-symbols-outlined text-3xl">
            fast_rewind
          </span>
        </button>

        {/* 3. 核心修改：绑定点击事件和图标切换 */}
        <button
          onClick={togglePlayback}
          className={cn(
            "flex items-center justify-center size-10 text-background-light rounded-full shadow-lg transform transition-all active:scale-95",
            isPlaying
              ? "bg-secondary hover:bg-opacity-90"
              : "bg-primary hover:bg-opacity-90"
          )}
          title={isPlaying ? "Pause" : "Play"}
        >
          <span
            className="material-symbols-outlined text-3xl"
            style={{ fontVariationSettings: "'FILL' 1" }}
          >
            {isPlaying ? "pause" : "play_arrow"}
          </span>
        </button>

        <button className="text-text-secondary hover:text-primary transition-colors p-2 rounded-full">
          <span className="material-symbols-outlined text-3xl">
            fast_forward
          </span>
        </button>
      </div>

      {/* 进度条 (目前还是静态的) */}
      <div className="flex flex-1 items-center gap-4 mx-4">
        <span className="font-display text-xs text-text-secondary font-mono">
          00:00
        </span>
        <div className="relative w-full h-1.5 bg-secondary/20 rounded-full cursor-pointer">
          <div
            className="absolute top-0 left-0 h-full bg-primary/40 rounded-full"
            style={{ width: "0%" }}
          ></div>
        </div>
        <span className="font-display text-xs text-text-secondary font-mono">
          00:00
        </span>
      </div>

      {/* 导出按钮 (保持不变) */}
      <div className="flex items-center gap-3 w-1/4 justify-end">
        <button
          className="px-3 py-1.5 text-xs font-bold border border-secondary text-text-secondary hover:bg-secondary/20 hover:text-text-primary transition-colors rounded-lg"
          onClick={() => alert("SRT export coming soon!")} // 暂时留空或绑定到后续的 SRT 逻辑
        >
          <span className="material-symbols-outlined text-sm align-bottom mr-1">subtitles</span>
          .SRT
        </button>

        {/* ▼▼▼ 绑定点击事件 ▼▼▼ */}
        <button
          onClick={openExportModal}
          className="px-4 py-1.5 text-xs font-bold bg-primary text-background-light hover:bg-opacity-90 transition-colors rounded-lg shadow-md flex items-center gap-1"
        >
          <span className="material-symbols-outlined text-sm">movie</span>
          Export Video
        </button>
      </div>
    </footer>
  );
};
