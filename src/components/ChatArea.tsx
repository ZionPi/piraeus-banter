import React, { useEffect, useRef, useState, useLayoutEffect } from 'react';
import { useProjectStore } from '@/store/projectStore';
import { ChatBubble } from './ChatBubble';

export const ChatArea: React.FC = () => {
  // 1. 从 Store 获取 scrollPosition 和 setScrollPosition
  const { bubbles, addBubble, generateAll, currentProjectName, scrollPosition, setScrollPosition, saveCurrentProject } = useProjectStore();
  const [searchTerm, setSearchTerm] = useState('');

  const scrollContainerRef = useRef<HTMLDivElement>(null);
  const bottomRef = useRef<HTMLDivElement>(null);

  // 防抖定时器 Ref
  const saveTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  const filteredBubbles = bubbles.filter(b =>
    b.content.toLowerCase().includes(searchTerm.toLowerCase()) ||
    b.name.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const pendingCount = bubbles.filter(b => b.status === 'idle' || b.status === 'error').length;
  const generatingCount = bubbles.filter(b => b.status === 'loading').length;

  const prevProjectName = useRef(currentProjectName);

  useLayoutEffect(() => {
    const container = scrollContainerRef.current;
    if (container && scrollPosition > 0) {
      container.scrollTop = scrollPosition;
    }
  }, [currentProjectName]);

  const handleScroll = (e: React.UIEvent<HTMLDivElement>) => {
    const scrollTop = e.currentTarget.scrollTop;
    setScrollPosition(scrollTop);

    if (saveTimeoutRef.current) clearTimeout(saveTimeoutRef.current);
    saveTimeoutRef.current = setTimeout(() => {
      saveCurrentProject();
    }, 1000);
  };

  useEffect(() => {
    return () => {
      if (saveTimeoutRef.current) clearTimeout(saveTimeoutRef.current);
    };
  }, [currentProjectName]);

  // --- 辅助逻辑: 新增气泡自动滚到底 ---
  const prevBubbleCount = useRef(bubbles.length);
  useEffect(() => {
    if (bubbles.length > prevBubbleCount.current) {
      // 只有新增时才强制滚到底，加载时不滚
      scrollContainerRef.current?.scrollTo({ top: scrollContainerRef.current.scrollHeight, behavior: 'smooth' });
    }
    prevBubbleCount.current = bubbles.length;
  }, [bubbles.length]);

  // 跳转函数
  const scrollToTop = () => scrollContainerRef.current?.scrollTo({ top: 0, behavior: 'smooth' });
  const scrollToBottom = () => bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  const handleGenerateAll = async () => {
    if (pendingCount === 0) return;
    await generateAll();
  };

  useEffect(() => {
    const isProjectChanged = prevProjectName.current !== currentProjectName;
    const isBubbleAdded = bubbles.length > prevBubbleCount.current;

    // 只有在“项目没变”且“气泡增加了”的情况下，才滚到底部
    // 如果是切换项目导致的气泡变化，绝对不要滚，交给 useLayoutEffect 去恢复记忆位置
    if (!isProjectChanged && isBubbleAdded) {
      scrollContainerRef.current?.scrollTo({ top: scrollContainerRef.current.scrollHeight, behavior: 'smooth' });
    }

    // 更新 Refs
    prevProjectName.current = currentProjectName;
    prevBubbleCount.current = bubbles.length;
  }, [bubbles.length, currentProjectName]);

  return (
    <div className="flex flex-1 flex-col h-full overflow-hidden relative bg-background-light">

      {/* 顶部搜索栏 */}
      <div className="flex-shrink-0 px-8 py-4 bg-background-light/95 backdrop-blur-sm border-b border-secondary/10 z-10 flex items-center justify-between gap-4">
        <div className="flex-1 max-w-2xl relative group">
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
        <button
          onClick={handleGenerateAll}
          disabled={pendingCount === 0 && generatingCount === 0}
          className={`flex items-center gap-2 px-4 py-2 rounded-full text-sm font-bold shadow-md transition-all ${generatingCount > 0 ? "bg-secondary/20 text-primary cursor-wait" : pendingCount > 0 ? "bg-primary text-white hover:bg-opacity-90 active:scale-95" : "bg-gray-100 text-gray-400 cursor-not-allowed"}`}
        >
          {generatingCount > 0 ? (
            <>
              <span className="material-symbols-outlined text-lg animate-spin">sync</span>
              <span>Generating... ({generatingCount})</span>
            </>
          ) : (
            <>
              <span className="material-symbols-outlined text-lg">magic_button</span>
              <span>Generate All {pendingCount > 0 ? `(${pendingCount})` : ''}</span>
            </>
          )}
        </button>
      </div>

      {/* 滚动区域 - 绑定 onScroll */}
      <div
        ref={scrollContainerRef}
        className="flex-1 overflow-y-auto p-8 pb-32 scroll-smooth"
        style={{ scrollBehavior: 'auto' }}
        onScroll={handleScroll} // ▼▼▼ 绑定滚动事件 ▼▼▼
      >
        <div className="flex flex-col gap-6 w-full max-w-7xl mx-auto">
          {filteredBubbles.length > 0 ? (
            filteredBubbles.map((bubble) => (
              <ChatBubble key={bubble.id} data={bubble} />
            ))
          ) : (
            <div className="text-center py-20 text-text-secondary flex flex-col items-center gap-2">
              <span className="material-symbols-outlined text-4xl opacity-30">forum</span>
              <p>No dialogue found.</p>
            </div>
          )}

          {!searchTerm && (
            <div className="flex justify-center items-center gap-4 pt-12 opacity-60 hover:opacity-100 transition-opacity pb-12">
              <button onClick={() => addBubble('guest')} className="flex items-center gap-2 px-4 py-2 text-sm font-bold border border-secondary/50 text-text-secondary hover:bg-secondary/20 hover:text-text-primary transition-colors rounded-full transform active:scale-95">
                <span className="material-symbols-outlined text-lg">add</span> Guest
              </button>
              <button onClick={() => addBubble('host')} className="flex items-center gap-2 px-4 py-2 text-sm font-bold border border-primary/30 text-primary bg-primary/5 hover:bg-primary/15 transition-colors rounded-full transform active:scale-95">
                <span className="material-symbols-outlined text-lg">add</span> Host
              </button>
            </div>
          )}
          <div ref={bottomRef} />
        </div>
      </div>

      {/* 悬浮按钮 */}
      <div className="absolute bottom-8 right-8 z-20 flex flex-col gap-2">
        <button onClick={scrollToTop} className="p-2 bg-white/80 backdrop-blur border border-secondary/30 rounded-full shadow-lg text-text-secondary hover:text-primary transition-all hover:-translate-y-1">
          <span className="material-symbols-outlined">vertical_align_top</span>
        </button>
        <button onClick={scrollToBottom} className="p-2 bg-white/80 backdrop-blur border border-secondary/30 rounded-full shadow-lg text-text-secondary hover:text-primary transition-all hover:-translate-y-1">
          <span className="material-symbols-outlined">vertical_align_bottom</span>
        </button>
      </div>
    </div>
  );
};