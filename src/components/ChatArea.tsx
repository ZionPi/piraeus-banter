import React, { useEffect, useRef, useState } from "react";
import { useProjectStore } from "@/store/projectStore";
import { ChatBubble } from "./ChatBubble";

export const ChatArea: React.FC = () => {
  const { bubbles, addBubble } = useProjectStore();
  const [searchTerm, setSearchTerm] = useState("");

  // 滚动容器的 Ref
  const scrollContainerRef = useRef<HTMLDivElement>(null);
  const bottomRef = useRef<HTMLDivElement>(null);

  const filteredBubbles = bubbles.filter(
    (b) =>
      b.content.toLowerCase().includes(searchTerm.toLowerCase()) ||
      b.name.toLowerCase().includes(searchTerm.toLowerCase())
  );

  // 自动滚动到底部
  useEffect(() => {
    if (!searchTerm && bottomRef.current) {
      bottomRef.current.scrollIntoView({ behavior: "smooth" });
    }
  }, [bubbles.length, searchTerm]);

  // 手动跳转函数
  const scrollToTop = () =>
    scrollContainerRef.current?.scrollTo({ top: 0, behavior: "smooth" });
  const scrollToBottom = () =>
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });

  return (
    // 🔴 关键：flex-1 让它填满 main 的剩余空间
    // 🔴 关键：overflow-y-auto 开启垂直滚动
    // 🔴 关键：h-full 确保高度被限制，从而触发滚动条
    <div className="flex flex-1 flex-col h-full overflow-hidden relative">
      {/* 顶部搜索栏 (固定不动) */}
      <div className="flex-shrink-0 px-8 py-4 bg-background-light/95 backdrop-blur-sm border-b border-secondary/10 z-10">
        <div className="max-w-7xl mx-auto relative group">
          <span className="absolute left-3 top-1/2 -translate-y-1/2 text-text-secondary group-focus-within:text-primary transition-colors">
            <span className="material-symbols-outlined text-xl">search</span>
          </span>
          <input
            type="text"
            placeholder="Search dialogue..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2 bg-white border border-secondary/30 rounded-full text-sm focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary transition-all shadow-sm"
          />
        </div>
      </div>

      {/* 滚动区域容器 */}
      <div
        ref={scrollContainerRef}
        className="flex-1 overflow-y-auto p-8 pb-32 scroll-smooth"
      >
        <div className="flex flex-col gap-6 w-full max-w-7xl mx-auto">
          {filteredBubbles.length > 0 ? (
            filteredBubbles.map((bubble) => (
              <ChatBubble key={bubble.id} data={bubble} />
            ))
          ) : (
            <div className="text-center py-20 text-text-secondary">
              <p>No dialogue found.</p>
            </div>
          )}

          {/* 底部添加按钮 */}
          {!searchTerm && (
            <div className="flex justify-center items-center gap-4 pt-12 opacity-60 hover:opacity-100 transition-opacity">
              <button
                onClick={() => addBubble("guest")}
                className="btn-add border border-secondary/50 text-text-secondary hover:bg-secondary/20 px-4 py-2 rounded-full font-bold flex gap-2 items-center"
              >
                <span className="material-symbols-outlined">add</span> Guest
              </button>
              <button
                onClick={() => addBubble("host")}
                className="btn-add border border-primary/30 text-primary bg-primary/5 hover:bg-primary/15 px-4 py-2 rounded-full font-bold flex gap-2 items-center"
              >
                <span className="material-symbols-outlined">add</span> Host
              </button>
            </div>
          )}

          {/* 底部锚点 */}
          <div ref={bottomRef} />
        </div>
      </div>

      {/* 悬浮跳转按钮 (绝对定位在右下角) */}
      <div className="absolute bottom-8 right-8 z-20 flex flex-col gap-2">
        <button
          onClick={scrollToTop}
          className="p-2 bg-white/80 backdrop-blur border border-secondary/30 rounded-full shadow-lg text-text-secondary hover:text-primary transition-all"
        >
          <span className="material-symbols-outlined">vertical_align_top</span>
        </button>
        <button
          onClick={scrollToBottom}
          className="p-2 bg-white/80 backdrop-blur border border-secondary/30 rounded-full shadow-lg text-text-secondary hover:text-primary transition-all"
        >
          <span className="material-symbols-outlined">
            vertical_align_bottom
          </span>
        </button>
      </div>
    </div>
  );
};
