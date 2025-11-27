import React, { useState } from 'react';
import { useProjectStore } from '@/store/projectStore';

interface ExportModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const ExportModal: React.FC<ExportModalProps> = ({
  isOpen,
  onClose,
}) => {
  // 1. 所有的 Hooks 必须在最顶层执行，不能被 if 打断
  const { exportFullAudio } = useProjectStore();
  const [isExporting, setIsExporting] = useState(false);

  // 处理点击
  const handleExportAudio = async () => {
    setIsExporting(true);
    // 这里会自动调用另存为弹窗，如果用户取消，path 为 null
    const path = await exportFullAudio();
    setIsExporting(false);

    if (path) {
      alert(`Audio Exported Successfully!\nPath: ${path}`);
      // 这里未来可以调用 Electron 打开文件夹
    }
  };

  // 2. 在 Hooks 执行完之后，再判断是否需要渲染 UI
  // ▼▼▼ 移动到这里 ▼▼▼
  if (!isOpen) return null;
  // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4 animate-in fade-in duration-200">
      <div className="w-full max-w-4xl rounded-xl border border-secondary bg-[#FEFEFE] shadow-2xl flex flex-col max-h-[90vh] overflow-hidden"
        style={{ backgroundImage: `url('data:image/svg+xml,%3Csvg width="60" height="60" viewBox="0 0 60 60" xmlns="http://www.w3.org/2000/svg"%3E%3Cg fill="none" fill-rule="evenodd"%3E%3Cg fill="%23DCD3C3" fill-opacity="0.1"%3E%3Cpath d="M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z"/%3E%3C/g%3E%3C/g%3E%3C/svg%3E')` }}>

        {/* Header */}
        <div className="flex items-center justify-between border-b border-secondary/30 p-6 bg-white/50">
          <div>
            <h2 className="font-display text-3xl font-bold text-text-primary">Export Your Creation</h2>
            <p className="text-text-secondary">Finalize your video, audio, and subtitle files.</p>
          </div>
          <button onClick={onClose} className="p-2 rounded-full hover:bg-secondary/20 text-text-secondary hover:text-text-primary transition-colors">
            <span className="material-symbols-outlined">close</span>
          </button>
        </div>

        {/* Scrollable Content */}
        <div className="flex-1 overflow-y-auto p-6 sm:p-8 space-y-8">

          {/* Video Settings */}
          <section>
            <h3 className="font-display text-2xl text-text-primary mb-4">Video Settings</h3>
            <div className="flex flex-col gap-6 rounded-lg border border-secondary/30 bg-white/50 p-6">
              <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
                {/* Resolution */}
                <div>
                  <p className="mb-3 text-sm font-bold tracking-wide text-text-secondary">Resolution</p>
                  <div className="flex gap-3">
                    {['720p', '1080p', '4K'].map((res) => (
                      <label key={res} className="cursor-pointer relative flex-1">
                        <input type="radio" name="resolution" className="peer sr-only" defaultChecked={res === '1080p'} />
                        <div className="flex h-10 items-center justify-center rounded-lg border border-secondary bg-white text-sm font-medium text-text-primary shadow-sm transition-all peer-checked:border-primary peer-checked:bg-primary/10 peer-checked:text-primary hover:bg-secondary/10">
                          {res}
                        </div>
                      </label>
                    ))}
                  </div>
                </div>
                {/* Quality */}
                <div>
                  <p className="mb-3 text-sm font-bold tracking-wide text-text-secondary">Quality</p>
                  <div className="flex gap-3">
                    {['Standard', 'High'].map((q) => (
                      <label key={q} className="cursor-pointer relative flex-1">
                        <input type="radio" name="quality" className="peer sr-only" defaultChecked={q === 'High'} />
                        <div className="flex h-10 items-center justify-center rounded-lg border border-secondary bg-white text-sm font-medium text-text-primary shadow-sm transition-all peer-checked:border-primary peer-checked:bg-primary/10 peer-checked:text-primary hover:bg-secondary/10">
                          {q}
                        </div>
                      </label>
                    ))}
                  </div>
                </div>
              </div>
              <button className="mt-2 flex h-12 w-full items-center justify-center gap-3 rounded-lg bg-primary px-5 text-lg font-bold text-white shadow-lg hover:bg-opacity-90 active:scale-[0.98] transition-all">
                <span className="material-symbols-outlined">movie_creation</span>
                Generate Video (.mp4)
              </button>
            </div>
          </section>

          {/* Individual Assets */}
          <section>
            <h3 className="font-display text-2xl text-text-primary mb-4">Individual Assets</h3>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">

              {/* 导出音频按钮 */}
              <button
                onClick={handleExportAudio}
                disabled={isExporting}
                className="flex h-12 items-center justify-center gap-2 rounded-lg border border-secondary bg-white px-5 font-bold text-text-primary shadow-sm hover:border-primary hover:text-primary transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isExporting ? (
                  <span className="material-symbols-outlined animate-spin">sync</span>
                ) : (
                  <span className="material-symbols-outlined">headphones</span>
                )}
                {isExporting ? "Merging..." : "Export Audio (.mp3)"}
              </button>

              <button className="flex h-12 items-center justify-center gap-2 rounded-lg border border-secondary bg-white px-5 font-bold text-text-primary shadow-sm hover:border-primary hover:text-primary transition-all">
                <span className="material-symbols-outlined">subtitles</span>
                Export Subtitles (.srt)
              </button>
            </div>
          </section>

          {/* Queue (占位) */}
          <section>
            <h3 className="font-display text-2xl text-text-primary mb-4">Export Queue</h3>
            <div className="space-y-4">
              <div className="flex items-center gap-4 rounded-lg border border-secondary/30 bg-white/60 p-4">
                <span className="material-symbols-outlined text-3xl text-primary">check_circle</span>
                <div className="flex-1">
                  <div className="flex justify-between">
                    <p className="font-bold text-text-primary">Example_Export_File.mp4</p>
                    <p className="font-bold text-primary">Ready</p>
                  </div>
                  <p className="text-xs text-text-secondary">Ready to export</p>
                </div>
              </div>
            </div>
          </section>

        </div>
      </div>
    </div>
  );
};