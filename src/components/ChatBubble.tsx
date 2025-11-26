import React, { useRef, useEffect } from 'react';
import { Bubble, useProjectStore } from '@/store/projectStore';
import { cn } from '@/utils/cn';

// [
//     {
//         "name": "温柔姐姐",
//         "id": "zh_female_inspirational"
//     },

interface ChatBubbleProps {
  data: Bubble;
}

export const ChatBubble: React.FC<ChatBubbleProps> = ({ data }) => {
  const { updateBubbleContent, deleteBubble, generateAudio } = useProjectStore();
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const isHost = data.role === 'host';

  // 自动调整文本框高度
  const adjustHeight = () => {
    const el = textareaRef.current;
    if (el) {
      el.style.height = 'auto';
      el.style.height = el.scrollHeight + 'px';
    }
  };

  // 内容变化时调整高度
  useEffect(() => {
    adjustHeight();
  }, [data.content]);

  // 生成/重新生成音频
  const handleGenerate = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (!data.content.trim()) return;
    generateAudio(data.id);
  };

  // 播放音频
  const handlePlay = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (data.audioPath) {
      // ▼▼▼ 修改：使用 media:// 协议加载本地文件 ▼▼▼
      // 将反斜杠替换为正斜杠 (Windows 兼容性)
      const normalizedPath = data.audioPath.replace(/\\/g, '/');
      const audioUrl = `media://${normalizedPath}`;

      const audio = new Audio(audioUrl);
      audio.play().catch(err => {
        console.error("Play error:", err);
        // 友好的错误提示
        alert("无法播放音频。\n可能是文件路径包含特殊字符，或者文件已被移动。");
      });
    }
  };

  return (
    <div className={cn(
      "flex items-start gap-3 group w-full transition-all duration-300",
      isHost ? "justify-end" : "justify-start"
    )}>

      {/* 左侧操作区 (Guest Only): 删除 & 拖拽 */}
      {!isHost && (
        <div className="flex flex-col gap-1 mt-4 opacity-0 group-hover:opacity-100 transition-opacity text-text-secondary">
          <button
            onClick={() => deleteBubble(data.id)}
            className="hover:text-red-500 p-1 rounded transition-colors"
            title="Delete Bubble"
          >
            <span className="material-symbols-outlined text-lg">delete</span>
          </button>
          <span className="material-symbols-outlined text-lg cursor-grab p-1 opacity-50 hover:opacity-100">drag_indicator</span>
        </div>
      )}

      <div className={cn("flex-1 max-w-[85%] flex flex-col", isHost && "items-end")}>

        {/* 角色名 & 状态点 */}
        <div className={cn("flex items-center gap-2 mb-1.5 mx-1", isHost ? "flex-row-reverse" : "flex-row")}>
          <span className={cn("text-xs font-bold", isHost ? "text-primary" : "text-text-secondary")}>
            {data.name}
          </span>
          {/* 状态指示小圆点 */}
          {data.status === 'error' && <span className="size-2 rounded-full bg-red-400 shadow-sm" title="Error"></span>}
          {data.status === 'success' && <span className="size-2 rounded-full bg-primary shadow-sm" title="Ready"></span>}
        </div>

        {/* 气泡主体容器 */}
        <div className={cn(
          "border shadow-sm transition-all w-full relative overflow-hidden flex flex-col",
          isHost
            ? "bg-[#E6F0E7] border-primary/30 rounded-2xl rounded-tr-sm"  // Host 绿色气泡
            : "bg-[#FDFBF4] border-secondary/40 rounded-2xl rounded-tl-sm", // Guest 米色气泡
          data.status === 'loading' && "animate-pulse border-primary/50"
        )}>

          {/* 文本编辑区域 */}
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

          {/* --- 底部操作栏 (Action Bar) --- */}
          <div className="px-3 pb-2 pt-1 flex items-center justify-between gap-2 min-h-[32px]">

            {/* 左侧：生成状态/播放控制 */}
            <div className="flex items-center gap-2">

              {/* 状态 1: 未生成 (Idle) */}
              {data.status === 'idle' && (
                <button
                  onClick={handleGenerate}
                  className="flex items-center gap-1 px-2 py-1 rounded-md bg-white/50 hover:bg-white text-text-secondary hover:text-primary text-xs font-semibold transition-colors border border-transparent hover:border-primary/20 shadow-sm"
                  title="Generate Audio"
                >
                  <span className="material-symbols-outlined text-sm">magic_button</span>
                  <span>Generate</span>
                </button>
              )}

              {/* 状态 2: 生成中 (Loading) */}
              {data.status === 'loading' && (
                <div className="flex items-center gap-1 px-2 py-1 text-primary text-xs font-semibold bg-white/30 rounded-md">
                  <span className="material-symbols-outlined text-sm animate-spin">progress_activity</span>
                  <span>Crafting...</span>
                </div>
              )}

              {/* 状态 3: 成功 (Success) - 包含播放和重新生成 */}
              {data.status === 'success' && (
                <div className="flex items-center gap-3 bg-white/40 px-2 py-1 rounded-full border border-black/5">
                  {/* 播放按钮 */}
                  <button
                    onClick={handlePlay}
                    className="flex items-center justify-center size-6 rounded-full bg-primary text-white hover:bg-primary-dark shadow-sm transition-transform active:scale-95"
                    title="Play Audio"
                  >
                    <span className="material-symbols-outlined text-base">play_arrow</span>
                  </button>

                  {/* 假波形 & 时长 */}
                  <div className="flex flex-col justify-center">
                    <div className="flex gap-0.5 items-end h-2.5">
                      {[40, 70, 50, 90, 60, 30, 80].map((h, i) => (
                        <div key={i} className="w-0.5 bg-primary/60 rounded-full" style={{ height: `${h}%` }}></div>
                      ))}
                    </div>
                  </div>

                  <div className="w-[1px] h-3 bg-black/10 mx-1"></div>

                  {/* 重新生成按钮 (Regenerate) */}
                  <button
                    onClick={handleGenerate}
                    className="text-text-secondary hover:text-primary transition-colors"
                    title="Regenerate Audio"
                  >
                    <span className="material-symbols-outlined text-base">refresh</span>
                  </button>
                </div>
              )}

              {/* 状态 4: 失败 (Error) */}
              {data.status === 'error' && (
                <div className="flex items-center gap-2 bg-red-50 border border-red-100 px-2 py-1 rounded-md">
                  <span className="text-xs text-red-500 font-medium max-w-[100px] truncate">
                    {data.errorMessage || "Error"}
                  </span>
                  <button
                    onClick={handleGenerate}
                    className="size-5 flex items-center justify-center rounded-full hover:bg-red-100 text-red-500 transition-colors"
                    title="Retry"
                  >
                    <span className="material-symbols-outlined text-sm">refresh</span>
                  </button>
                </div>
              )}
            </div>

            {/* 右侧：字数统计 */}
            <div className="text-[10px] text-text-secondary/40 font-mono select-none">
              {data.content.length} chars
            </div>
          </div>
        </div>
      </div>

      {/* 右侧操作区 (Host Only): 删除 & 拖拽 */}
      {isHost && (
        <div className="flex flex-col gap-1 mt-4 opacity-0 group-hover:opacity-100 transition-opacity text-text-secondary">
          <button
            onClick={() => deleteBubble(data.id)}
            className="hover:text-red-500 p-1 rounded transition-colors"
            title="Delete Bubble"
          >
            <span className="material-symbols-outlined text-lg">delete</span>
          </button>
          <span className="material-symbols-outlined text-lg cursor-grab p-1 opacity-50 hover:opacity-100">drag_indicator</span>
        </div>
      )}
    </div>
  );
};