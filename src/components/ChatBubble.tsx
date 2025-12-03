import React, { useRef, useEffect } from 'react';
import { Bubble, useProjectStore } from '@/store/projectStore';
import { cn } from '@/utils/cn';

interface ChatBubbleProps {
  data: Bubble;
}

export const ChatBubble: React.FC<ChatBubbleProps> = ({ data }) => {
  // 1. 获取 currentPlayingId
  const { updateBubbleContent, deleteBubble, generateAudio, currentPlayingId, playSingleBubble } = useProjectStore();
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const bubbleRef = useRef<HTMLDivElement>(null);

  const isHost = data.role === 'host';
  // 2. 判断是否正在播放自己
  const isPlayingThis = currentPlayingId === data.id;

  // 自动调整高度
  const adjustHeight = () => {
    const el = textareaRef.current;
    if (el) {
      el.style.height = 'auto';
      el.style.height = el.scrollHeight + 'px';
    }
  };

  useEffect(() => {
    adjustHeight();
  }, [data.content]);

  // 3. 核心逻辑：自动滚动跟随
  useEffect(() => {
    if (isPlayingThis && bubbleRef.current) {
      // 当轮到我播放时，平滑滚动到屏幕中间
      bubbleRef.current.scrollIntoView({
        behavior: 'smooth',
        block: 'center',
      });
    }
  }, [isPlayingThis]);

  const handleGenerate = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (!data.content.trim()) return;
    generateAudio(data.id);
  };

  const handlePlay = (e: React.MouseEvent) => {
    e.stopPropagation();
    // 不再自己 new Audio，而是交给 Store 统一管理
    playSingleBubble(data.id);
  };

  return (
    <div
      ref={bubbleRef} // 绑定 ref 用于滚动
      className={cn(
        "flex items-start gap-3 group w-full transition-all duration-300 px-2 py-2 rounded-xl",
        isHost ? "justify-end" : "justify-start",
        // 4. 高亮样式：背景微调 + 边框高亮
        isPlayingThis && "bg-secondary/10 ring-2 ring-primary ring-offset-4 ring-offset-background-light"
      )}
    >

      {/* 左侧操作区 */}
      {!isHost && (
        <div className="flex flex-col gap-1 mt-4 opacity-0 group-hover:opacity-100 transition-opacity text-text-secondary">
          <button onClick={() => deleteBubble(data.id)} className="hover:text-red-500 p-1 rounded transition-colors">
            <span className="material-symbols-outlined text-lg">delete</span>
          </button>
          <span className="material-symbols-outlined text-lg cursor-grab p-1 opacity-50 hover:opacity-100">drag_indicator</span>
        </div>
      )}

      <div className={cn("flex-1 max-w-[85%] flex flex-col", isHost && "items-end")}>

        <div className={cn("flex items-center gap-2 mb-1.5 mx-1", isHost ? "flex-row-reverse" : "flex-row")}>
          <span className={cn("text-xs font-bold transition-colors",
            // 播放时名字也变色
            isPlayingThis ? "text-primary" : (isHost ? "text-primary" : "text-text-secondary")
          )}>
            {data.name} {isPlayingThis && "(Speaking...)"}
          </span>
          {data.status === 'error' && <span className="size-2 rounded-full bg-red-400" title="Error"></span>}
          {data.status === 'success' && <span className="size-2 rounded-full bg-primary" title="Ready"></span>}
        </div>

        <div className={cn(
          "border shadow-sm transition-all w-full relative overflow-hidden flex flex-col",
          isHost
            ? "bg-[#E6F0E7] border-primary/30 rounded-2xl rounded-tr-sm"
            : "bg-[#FDFBF4] border-secondary/40 rounded-2xl rounded-tl-sm",
          data.status === 'loading' && "animate-pulse border-primary/50",
          // 播放时的额外阴影
          isPlayingThis && "shadow-md border-primary"
        )}>

          <textarea
            ref={textareaRef}
            value={data.content}
            onChange={(e) => {
              updateBubbleContent(data.id, e.target.value);
              adjustHeight();
            }}
            placeholder="Type dialogue here..."
            className="w-full bg-transparent border-none outline-none resize-none font-display text-base text-text-primary placeholder:text-text-secondary/50 overflow-hidden p-4 pb-2 leading-relaxed"
            rows={1}
            spellCheck={false}
          />

          {/* Action Bar */}
          <div className="px-3 pb-2 pt-1 flex items-center justify-between gap-2 min-h-[32px]">
            <div className="flex items-center gap-2">
              {data.status === 'idle' && (
                <button onClick={handleGenerate} className="flex items-center gap-1 px-2 py-1 rounded-md bg-white/50 hover:bg-white text-text-secondary hover:text-primary text-xs font-semibold transition-colors border border-transparent hover:border-primary/20 shadow-sm">
                  <span className="material-symbols-outlined text-sm">magic_button</span>
                  <span>Generate</span>
                </button>
              )}
              {data.status === 'loading' && (
                <div className="flex items-center gap-1 px-2 py-1 text-primary text-xs font-semibold bg-white/30 rounded-md">
                  <span className="material-symbols-outlined text-sm animate-spin">progress_activity</span>
                  <span>Crafting...</span>
                </div>
              )}
              {data.status === 'success' && (
                <div className="flex items-center gap-3 bg-white/40 px-2 py-1 rounded-full border border-black/5">
                  <button onClick={handlePlay} className="flex items-center justify-center size-6 rounded-full bg-primary text-white hover:bg-primary-dark shadow-sm active:scale-95">
                    <span className="material-symbols-outlined text-base">play_arrow</span>
                  </button>
                  <div className="flex flex-col">
                    {/* 显示时长，如果正在播放显示 Playing */}
                    <span className="text-[10px] text-text-secondary font-mono leading-none">
                      {isPlayingThis ? <span className="text-primary font-bold">Playing...</span> : (data.duration ? `${data.duration}s` : 'Ready')}
                    </span>
                    <div className="flex gap-0.5 mt-0.5 items-end h-2.5">
                      {[40, 70, 50, 90, 60, 30, 80].map((h, i) => (
                        <div key={i} className={cn("w-0.5 rounded-full transition-colors", isPlayingThis ? "bg-primary animate-pulse" : "bg-primary/60")} style={{ height: `${h}%` }}></div>
                      ))}
                    </div>
                  </div>
                  <div className="w-[1px] h-3 bg-black/10 mx-1"></div>
                  <button onClick={handleGenerate} className="text-text-secondary hover:text-primary transition-colors">
                    <span className="material-symbols-outlined text-base">refresh</span>
                  </button>
                </div>
              )}
              {data.status === 'error' && (
                <div className="flex items-center gap-2 bg-red-50 border border-red-100 px-2 py-1 rounded-md">
                  <span className="text-xs text-red-500 font-medium max-w-[100px] truncate">{data.errorMessage || "Error"}</span>
                  <button onClick={handleGenerate} className="size-5 flex items-center justify-center rounded-full hover:bg-red-100 text-red-500 transition-colors">
                    <span className="material-symbols-outlined text-sm">refresh</span>
                  </button>
                </div>
              )}
            </div>
            <div className="text-[10px] text-text-secondary/40 font-mono select-none">
              {data.content.length} chars
            </div>
          </div>
        </div>
      </div>

      {/* 右侧操作区 */}
      {isHost && (
        <div className="flex flex-col gap-1 mt-4 opacity-0 group-hover:opacity-100 transition-opacity text-text-secondary">
          <button onClick={() => deleteBubble(data.id)} className="hover:text-red-500 p-1 rounded transition-colors">
            <span className="material-symbols-outlined text-lg">delete</span>
          </button>
          <span className="material-symbols-outlined text-lg cursor-grab p-1 opacity-50 hover:opacity-100">drag_indicator</span>
        </div>
      )}
    </div>
  );
};