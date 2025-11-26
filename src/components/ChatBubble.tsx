import React, { useRef, useEffect } from "react";
import { Bubble, useProjectStore } from "@/store/projectStore";
import { cn } from "@/utils/cn"; // 稍后我们会创建这个工具函数

interface ChatBubbleProps {
  data: Bubble;
}

export const ChatBubble: React.FC<ChatBubbleProps> = ({ data }) => {
  const { updateBubbleContent, deleteBubble } = useProjectStore();
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const isHost = data.role === "host";

  // 自动调整高度的魔法函数
  const adjustHeight = () => {
    const el = textareaRef.current;
    if (el) {
      el.style.height = "auto"; // 先重置
      el.style.height = el.scrollHeight + "px"; // 再撑开
    }
  };

  // 初始化时调整一次高度
  useEffect(() => {
    adjustHeight();
  }, [data.content]);

  return (
    <div
      className={cn(
        "flex items-start gap-3 group w-full animate-in fade-in slide-in-from-bottom-2 duration-300",
        isHost ? "justify-end" : "justify-start"
      )}
    >
      {/* 左侧操作区 (Guest) */}
      {!isHost && (
        <div className="flex flex-col gap-1 mt-8 opacity-0 group-hover:opacity-100 transition-opacity">
          <button
            onClick={() => deleteBubble(data.id)}
            className="text-text-secondary hover:text-red-500"
          >
            <span className="material-symbols-outlined text-lg">delete</span>
          </button>
          <span className="material-symbols-outlined text-text-secondary text-lg cursor-grab">
            drag_indicator
          </span>
        </div>
      )}

      <div
        className={cn(
          "flex-1 max-w-[80%] flex flex-col",
          isHost && "items-end"
        )}
      >
        <p
          className={cn(
            "text-xs font-bold mb-1.5 mx-1",
            isHost ? "text-primary mr-2" : "text-text-secondary ml-2"
          )}
        >
          {data.name}
        </p>

        <div
          className={cn(
            "p-4 border shadow-sm transition-all hover:shadow-md w-full relative",
            isHost
              ? "bg-[#E6F0E7] border-primary/30 rounded-2xl rounded-tr-sm"
              : "bg-[#FDFBF4] border-secondary/40 rounded-2xl rounded-tl-sm"
          )}
        >
          {/* 这是一个可编辑的 Textarea */}
          <textarea
            ref={textareaRef}
            value={data.content}
            onChange={(e) => {
              updateBubbleContent(data.id, e.target.value);
              adjustHeight();
            }}
            placeholder="Type dialogue here..."
            className="w-full bg-transparent border-none outline-none resize-none font-display text-base text-text-primary placeholder:text-text-secondary/50 overflow-hidden"
            rows={1}
            spellCheck={false}
          />
        </div>
      </div>

      {/* 右侧操作区 (Host) */}
      {isHost && (
        <div className="flex flex-col gap-1 mt-8 opacity-0 group-hover:opacity-100 transition-opacity">
          <button
            onClick={() => deleteBubble(data.id)}
            className="text-text-secondary hover:text-red-500"
          >
            <span className="material-symbols-outlined text-lg">delete</span>
          </button>
          <span className="material-symbols-outlined text-text-secondary text-lg cursor-grab">
            drag_indicator
          </span>
        </div>
      )}
    </div>
  );
};
