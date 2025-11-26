import React from "react";

export const PlayerControl: React.FC = () => {
  return (
    <footer className="flex h-20 w-full flex-shrink-0 items-center justify-between border-t border-secondary/30 bg-surface px-6 shadow-[0_-2px_10px_rgba(0,0,0,0.03)]">
      {/* 播放按钮组 */}
      <div className="flex items-center gap-4 w-1/4">
        <button className="text-text-secondary hover:text-primary transition-colors">
          <span className="material-symbols-outlined text-3xl">
            fast_rewind
          </span>
        </button>
        <button className="flex items-center justify-center size-10 bg-primary text-background-light hover:bg-opacity-90 transition-all rounded-full shadow-lg transform hover:scale-105">
          <span
            className="material-symbols-outlined text-3xl"
            style={{ fontVariationSettings: "'FILL' 1" }}
          >
            play_arrow
          </span>
        </button>
        <button className="text-text-secondary hover:text-primary transition-colors">
          <span className="material-symbols-outlined text-3xl">
            fast_forward
          </span>
        </button>
      </div>

      {/* 进度条与波形 (模拟) */}
      <div className="flex flex-1 items-center gap-4 mx-4">
        <span className="font-display text-xs text-text-secondary font-mono">
          01:15
        </span>
        <div className="relative w-full h-8 bg-secondary/20 group flex items-center rounded-lg overflow-hidden cursor-pointer">
          {/* 进度层 */}
          <div className="absolute top-0 left-0 h-full w-[35%] bg-primary/20 z-0"></div>
          {/* 波形图 (模拟图片) */}
          <div className="absolute top-0 left-0 h-full w-full z-10 opacity-60 flex items-center">
            {/* 这里用一个简单的 CSS 渐变模拟波形，替换原本的 Google 图片链接 */}
            <div
              className="w-full h-1/2 bg-gradient-to-r from-transparent via-text-secondary to-transparent opacity-30"
              style={{
                maskImage:
                  "linear-gradient(to right, black 35%, transparent 35%)",
              }}
            ></div>
          </div>
          {/* 进度指示器 */}
          <div className="absolute top-0 bottom-0 left-[35%] w-0.5 bg-primary z-20"></div>
        </div>
        <span className="font-display text-xs text-text-secondary font-mono">
          04:30
        </span>
      </div>

      {/* 导出按钮 */}
      <div className="flex items-center gap-3 w-1/4 justify-end">
        <button className="px-3 py-1.5 text-xs font-bold border border-secondary text-text-secondary hover:bg-secondary/20 hover:text-text-primary transition-colors rounded-lg">
          <span className="material-symbols-outlined text-sm align-bottom mr-1">
            subtitles
          </span>
          .SRT
        </button>
        <button className="px-4 py-1.5 text-xs font-bold bg-primary text-background-light hover:bg-opacity-90 transition-colors rounded-lg shadow-md flex items-center gap-1">
          <span className="material-symbols-outlined text-sm">movie</span>
          Export Video
        </button>
      </div>
    </footer>
  );
};
