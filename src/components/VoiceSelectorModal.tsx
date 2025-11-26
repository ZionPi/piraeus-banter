import React, { useState, useMemo } from 'react';
import voicePresets from '@/data/voice_presets.json';
import { useProjectStore } from '@/store/projectStore';

interface VoiceSelectorModalProps {
    isOpen: boolean;
    onClose: () => void;
    role: 'host' | 'guest';
}

export const VoiceSelectorModal: React.FC<VoiceSelectorModalProps> = ({ isOpen, onClose, role }) => {
    // 1. 所有的 Hooks 必须在最顶层无条件执行
    const { hostVoiceId, guestVoiceId, recentVoiceIds, setVoice } = useProjectStore();
    const [searchTerm, setSearchTerm] = useState('');

    // 计算当前选中项
    const currentSelectedId = role === 'host' ? hostVoiceId : guestVoiceId;

    // Memo 必须在 return 之前执行
    const filteredVoices = useMemo(() => {
        return voicePresets.filter(v =>
            v.name.toLowerCase().includes(searchTerm.toLowerCase())
        );
    }, [searchTerm]);

    const recentVoices = useMemo(() => {
        return recentVoiceIds
            .map(id => voicePresets.find(v => v.id === id))
            .filter(v => v !== undefined);
    }, [recentVoiceIds]);

    const handleSelect = (voiceId: string) => {
        setVoice(role, voiceId);
        onClose();
    };

    // ▼▼▼ 2. 所有的 Hooks 执行完后，再进行条件返回 ▼▼▼
    if (!isOpen) return null;
    // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4 animate-in fade-in duration-200">
            <div
                className="w-full max-w-3xl h-[80vh] rounded-xl border border-secondary bg-[#FEFEFE] shadow-2xl flex flex-col overflow-hidden"
                style={{ backgroundImage: `url('data:image/svg+xml,%3Csvg width="60" height="60" viewBox="0 0 60 60" xmlns="http://www.w3.org/2000/svg"%3E%3Cg fill="none" fill-rule="evenodd"%3E%3Cg fill="%23DCD3C3" fill-opacity="0.1"%3E%3Cpath d="M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2v-4h4v-2h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2v-4h4v-2H6z"/%3E%3C/g%3E%3C/g%3E%3C/svg%3E')` }}
            >

                {/* Header & Search */}
                <div className="flex flex-col gap-4 border-b border-secondary/30 p-6 bg-white/80 backdrop-blur-md z-10">
                    <div className="flex justify-between items-center">
                        <h2 className="font-display text-2xl font-bold text-text-primary">
                            Select Voice for <span className="text-primary">{role === 'host' ? 'Host' : 'Guest'}</span>
                        </h2>
                        <button onClick={onClose} className="p-2 rounded-full hover:bg-secondary/20 text-text-secondary hover:text-text-primary transition-colors">
                            <span className="material-symbols-outlined">close</span>
                        </button>
                    </div>

                    <div className="relative group">
                        <span className="absolute left-3 top-1/2 -translate-y-1/2 text-text-secondary group-focus-within:text-primary transition-colors">
                            <span className="material-symbols-outlined text-xl">search</span>
                        </span>
                        <input
                            type="text"
                            placeholder="Search voice (e.g. 温柔, 广告, 粤语)..."
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="w-full pl-10 pr-4 py-3 bg-background-light border border-secondary/50 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary transition-all shadow-inner"
                            autoFocus
                        />
                    </div>
                </div>

                {/* Content List */}
                <div className="flex-1 overflow-y-auto p-6 space-y-8 scroll-smooth">

                    {/* Recent Section */}
                    {!searchTerm && recentVoices.length > 0 && (
                        <section>
                            <h3 className="text-xs font-bold text-text-secondary uppercase tracking-wider mb-3">Recent Used</h3>
                            <div className="flex flex-wrap gap-2">
                                {recentVoices.map((voice: any) => (
                                    <button
                                        key={voice.id}
                                        onClick={() => handleSelect(voice.id)}
                                        className={`px-4 py-2 rounded-full text-sm font-bold border transition-all transform active:scale-95 ${currentSelectedId === voice.id
                                            ? "bg-primary text-white border-primary shadow-md"
                                            : "bg-white border-secondary/50 text-text-primary hover:border-primary hover:text-primary hover:bg-primary/5"
                                            }`}
                                    >
                                        {voice.name}
                                    </button>
                                ))}
                            </div>
                        </section>
                    )}

                    {/* All Voices Section */}
                    <section>
                        <h3 className="text-xs font-bold text-text-secondary uppercase tracking-wider mb-3">
                            {searchTerm ? 'Search Results' : 'All Voices'}
                        </h3>

                        {filteredVoices.length === 0 ? (
                            <div className="text-center py-10 text-text-secondary">
                                No voices found matching "{searchTerm}"
                            </div>
                        ) : (
                            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
                                {filteredVoices.map((voice) => (
                                    <button
                                        key={voice.id}
                                        onClick={() => handleSelect(voice.id)}
                                        className={`flex items-center justify-center px-3 py-3 rounded-xl border text-sm font-medium transition-all text-center hover:shadow-md active:scale-[0.98] ${currentSelectedId === voice.id
                                            ? "bg-primary/10 border-primary text-primary ring-2 ring-primary/20"
                                            : "bg-white/60 border-secondary/30 text-text-primary hover:border-primary/50 hover:bg-white"
                                            }`}
                                    >
                                        {voice.name}
                                    </button>
                                ))}
                            </div>
                        )}
                    </section>
                </div>

                {/* Footer Hint */}
                <div className="bg-surface/50 p-3 text-center text-xs text-text-secondary border-t border-secondary/20">
                    Selecting a voice will apply it to all <strong>{role === 'host' ? 'Host' : 'Guest'}</strong> bubbles immediately.
                </div>

            </div>
        </div>
    );
};