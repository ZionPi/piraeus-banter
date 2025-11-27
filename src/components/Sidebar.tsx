import React, { useState, useEffect, useMemo } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import { useProjectStore } from "@/store/projectStore";
import { ImportScriptModal } from "./ImportScriptModal";
import { VoiceSelectorModal } from "./VoiceSelectorModal";
import voicePresets from "@/data/voice_presets.json";

export const Sidebar: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();

  // 从 Store 获取状态和方法
  const {
    hostVoiceId,
    guestVoiceId,
    projectList,
    fetchAllProjects,
    loadProject,
    currentProjectName,
    createNewProject,
    hostName,
    guestName,
    updateHostName,
    updateGuestName,
  } = useProjectStore();

  const [voiceModalOpen, setVoiceModalOpen] = useState(false);
  const [editingRole, setEditingRole] = useState<"host" | "guest">("host");
  // 本地 UI 状态
  const [isImportOpen, setIsImportOpen] = useState(false);
  const [projectSearchTerm, setProjectSearchTerm] = useState("");

  const { deleteProjectFile } = useProjectStore(); // 获取删除方法

  const handleDelete = (
    e: React.MouseEvent,
    filename: string,
    name: string
  ) => {
    e.stopPropagation(); // 防止触发点击加载
    if (
      confirm(
        `Are you sure you want to delete "${name}"?\nThis cannot be undone.`
      )
    ) {
      deleteProjectFile(filename);
    }
  };

  const getVoiceName = (id: string) => {
    const v = voicePresets.find((v) => v.id === id);
    return v ? v.name : "Unknown Voice";
  };

  // 打开弹窗的处理函数
  const openVoiceModal = (role: "host" | "guest") => {
    setEditingRole(role);
    setVoiceModalOpen(true);
  };

  // 初始化加载项目列表
  useEffect(() => {
    fetchAllProjects();
  }, []);

  // 路由激活状态判断
  const isActive = (path: string) =>
    location.pathname === path
      ? "bg-secondary/20 text-text-primary font-bold"
      : "text-text-secondary hover:bg-secondary/10";

  // 导航辅助函数
  const handleNav = (path: string) => {
    navigate(path);
  };

  // 项目点击处理
  const handleProjectClick = (filename: string) => {
    loadProject(filename);
    navigate("/");
  };

  // 新建项目处理
  const handleCreateClick = (e: React.MouseEvent) => {
    e.stopPropagation(); // 防止触发展开/收起
    createNewProject();
    navigate("/");
  };

  // 搜索过滤逻辑
  const filteredProjects = projectList.filter((p) =>
    p.name.toLowerCase().includes(projectSearchTerm.toLowerCase())
  );

  return (
    // 最外层：flex 布局，h-full 占满高度
    <aside className="flex w-80 flex-shrink-0 flex-col justify-between border-r border-secondary/30 bg-surface p-4 h-full select-none">
      {/* --- 上半部分：可滚动的内容区域 --- */}
      <div className="flex flex-col gap-6 overflow-y-auto flex-1 -mr-2 pr-2 scrollbar-thin scrollbar-thumb-secondary/20">
        {/* 1. Logo - 点击回首页 */}
        <div
          className="flex items-center gap-3 cursor-pointer hover:opacity-80 transition-opacity flex-shrink-0"
          onClick={() => handleNav("/")}
        >
          <div
            className="bg-center bg-no-repeat aspect-square bg-cover size-10 rounded-full border-2 border-primary"
            style={{
              backgroundImage:
                'url("https://lh3.googleusercontent.com/aida-public/AB6AXuCZGS4y4M1sOc6JV0MxAzAcsVvQudWdvZcEcbtRwjIOrKtjFHh5KXNjNWBxUQsodz3J3Ip2feZ2AAzZj6NHjPlh3bbX9LeywU2m88cJoqfE3zG7p6dPlbzwHp4nZKIVlafO_edf4ZRyy3Vis94-h8949bYAAsqI9SG_9uGiKgQJ6Ho4_EOvzC1sOTvQocmbDZYFgi3sDv1JbEuTJOcodyk-tCPFP_5b1X1sFry5GN6jzdQw2gRCkWTWMv4yGzD6NGYNgDDZME02YGk")',
            }}
          ></div>
          <div className="flex flex-col">
            <h1 className="font-display text-base font-bold leading-normal text-primary">
              Piraeus Banter
            </h1>
            <p className="font-display text-sm font-normal leading-normal text-text-secondary">
              Content Creation Tool
            </p>
          </div>
        </div>

        {/* 2. 菜单列表 */}
        <div className="flex flex-col gap-2">
          {/* === Projects 分组 === */}
          <details className="flex flex-col group" open>
            {/* 分组标题 + 新建按钮 */}
            <summary className="flex cursor-pointer list-none items-center justify-between gap-6 px-2 py-2 hover:bg-secondary/5 rounded-lg group-summary sticky top-0 bg-surface z-10">
              <p className="font-display text-sm font-bold leading-normal text-text-primary tracking-wide uppercase">
                Projects
              </p>
              <div className="flex items-center gap-2">
                <button
                  onClick={handleCreateClick}
                  className="p-1 rounded hover:bg-secondary/20 text-text-secondary hover:text-primary transition-colors"
                  title="Create New Project"
                >
                  <span className="material-symbols-outlined text-lg">add</span>
                </button>
                <span className="material-symbols-outlined text-text-secondary group-open:rotate-180 transition-transform text-lg">
                  expand_more
                </span>
              </div>
            </summary>

            {/* 搜索框 (Sticky 吸顶) */}
            <div className="px-2 pb-2 pt-1 sticky top-9 bg-surface z-10">
              <div className="relative flex items-center">
                <span className="absolute left-2 text-text-secondary pointer-events-none">
                  <span className="material-symbols-outlined text-sm">
                    search
                  </span>
                </span>
                <input
                  type="text"
                  placeholder="Find..."
                  value={projectSearchTerm}
                  onChange={(e) => setProjectSearchTerm(e.target.value)}
                  className="w-full pl-8 pr-6 py-1.5 text-xs bg-background-light border border-secondary/30 rounded-md focus:outline-none focus:border-primary/50 focus:ring-1 focus:ring-primary/20 text-text-primary placeholder:text-text-secondary/50 transition-all"
                />
                {projectSearchTerm && (
                  <button
                    onClick={() => setProjectSearchTerm("")}
                    className="absolute right-2 text-text-secondary hover:text-primary"
                  >
                    <span className="material-symbols-outlined text-sm">
                      close
                    </span>
                  </button>
                )}
              </div>
            </div>

            {/* 项目列表 */}
            <div className="flex flex-col gap-1 px-2 pb-2">
              {projectList.length === 0 ? (
                <p className="text-xs text-text-secondary px-3 py-2 italic">
                  No projects yet.
                </p>
              ) : filteredProjects.length === 0 ? (
                <p className="text-xs text-text-secondary px-3 py-2 italic">
                  No matches found.
                </p>
              ) : (
                filteredProjects.map((proj) => (
                  <div
                    key={proj.filename}
                    onClick={() => handleProjectClick(proj.filename)}
                    className={`px-3 py-1.5 text-sm font-display rounded cursor-pointer transition-colors truncate flex justify-between items-center group/item ${
                      currentProjectName === proj.name
                        ? "bg-primary/10 text-primary font-bold"
                        : "text-text-secondary hover:bg-secondary/10"
                    }`}
                    title={proj.name}
                  >
                    <span className="truncate">{proj.name}</span>

                    <button
                      onClick={(e) => handleDelete(e, proj.filename, proj.name)}
                      className="opacity-0 group-hover/item:opacity-100 p-1 hover:bg-red-100 hover:text-red-500 rounded transition-all"
                      title="Delete Project"
                    >
                      <span className="material-symbols-outlined text-xs">
                        delete
                      </span>
                    </button>
                  </div>
                ))
              )}
            </div>
          </details>

          {/* === Global Config 分组 === */}
          <details className="flex flex-col group" open>
            <summary className="flex cursor-pointer list-none items-center justify-between gap-6 px-2 py-2 hover:bg-secondary/5 rounded-lg sticky top-0 bg-surface z-10">
              <p className="font-display text-sm font-bold leading-normal text-text-primary tracking-wide uppercase">
                Global Config
              </p>
              <span className="material-symbols-outlined text-text-secondary group-open:rotate-180 transition-transform text-lg">
                expand_more
              </span>
            </summary>
            <div className="flex flex-col gap-4 px-2 pt-2 pb-4">
              {/* ▼▼▼ 新增：Host 名字输入框 ▼▼▼ */}
              <label className="flex flex-col w-full">
                <p className="font-display text-sm font-semibold leading-normal pb-1 text-text-secondary">
                  Host Name
                </p>
                <input
                  type="text"
                  value={hostName}
                  onChange={(e) => updateHostName(e.target.value)}
                  className="w-full px-3 py-2 bg-background-light border border-secondary/50 rounded-lg text-sm text-text-primary focus:outline-none focus:border-primary transition-all"
                />
              </label>

              {/* Host Voice Selector - 改为按钮 */}
              <div className="flex flex-col w-full">
                <p className="font-display text-sm font-semibold leading-normal pb-2 text-text-secondary">
                  Host Voice
                </p>
                <button
                  onClick={() => openVoiceModal("host")}
                  className="w-full flex items-center justify-between px-3 py-2 bg-background-light border border-secondary/50 rounded-lg shadow-sm hover:border-primary hover:bg-white transition-all text-left group/btn"
                >
                  <span className="font-display text-sm text-text-primary group-hover/btn:text-primary font-bold">
                    {getVoiceName(hostVoiceId)}
                  </span>
                  <span className="material-symbols-outlined text-lg text-text-secondary group-hover/btn:text-primary">
                    tune
                  </span>
                </button>
              </div>

              <label className="flex flex-col w-full mt-2">
                <p className="font-display text-sm font-semibold leading-normal pb-1 text-text-secondary">
                  Guest Name
                </p>
                <input
                  type="text"
                  value={guestName}
                  onChange={(e) => updateGuestName(e.target.value)}
                  className="w-full px-3 py-2 bg-background-light border border-secondary/50 rounded-lg text-sm text-text-primary focus:outline-none focus:border-primary transition-all"
                />
              </label>

              {/* Guest Voice Selector - 改为按钮 */}
              <div className="flex flex-col w-full">
                <p className="font-display text-sm font-semibold leading-normal pb-2 text-text-secondary">
                  Guest Voice
                </p>
                <button
                  onClick={() => openVoiceModal("guest")}
                  className="w-full flex items-center justify-between px-3 py-2 bg-background-light border border-secondary/50 rounded-lg shadow-sm hover:border-primary hover:bg-white transition-all text-left group/btn"
                >
                  <span className="font-display text-sm text-text-primary group-hover/btn:text-primary font-bold">
                    {getVoiceName(guestVoiceId)}
                  </span>
                  <span className="material-symbols-outlined text-lg text-text-secondary group-hover/btn:text-primary">
                    tune
                  </span>
                </button>
              </div>

              <label className="flex flex-col w-full">
                <div className="flex justify-between">
                  <p className="font-display text-sm font-semibold leading-normal pb-2 text-text-secondary">
                    Speed
                  </p>
                  <p className="font-mono text-xs text-primary">1.0x</p>
                </div>
                <input
                  type="range"
                  min="0.5"
                  max="2"
                  step="0.1"
                  defaultValue="1"
                  className="accent-primary h-1 bg-secondary/30 rounded-lg appearance-none cursor-pointer"
                />
              </label>
            </div>
          </details>
        </div>
      </div>

      {/* --- 底部：固定操作按钮 --- */}
      <div className="flex flex-col gap-1 border-t border-secondary/30 pt-4 mt-2 flex-shrink-0 bg-surface">
        {/* 导入按钮 */}
        <button
          onClick={() => setIsImportOpen(true)}
          className="flex items-center gap-3 w-full text-left px-3 py-2 cursor-pointer bg-primary/10 text-primary border border-primary/20 rounded hover:bg-primary/20 transition-colors"
        >
          <span className="material-symbols-outlined text-xl">upload_file</span>
          <span className="font-display text-sm font-bold leading-normal">
            Import Script
          </span>
        </button>

        {/* 设置按钮 */}
        <div
          onClick={() => handleNav("/settings")}
          className={`flex items-center gap-3 px-3 py-2 cursor-pointer rounded transition-colors ${isActive(
            "/settings"
          )}`}
        >
          <span className="material-symbols-outlined text-xl">settings</span>
          <p className="font-display text-sm font-semibold leading-normal">
            Settings
          </p>
        </div>
      </div>

      {/* 挂载音色选择弹窗 */}
      <VoiceSelectorModal
        isOpen={voiceModalOpen}
        onClose={() => setVoiceModalOpen(false)}
        role={editingRole}
      />

      {/* 导入弹窗组件 */}
      <ImportScriptModal
        isOpen={isImportOpen}
        onClose={() => setIsImportOpen(false)}
      />
    </aside>
  );
};
