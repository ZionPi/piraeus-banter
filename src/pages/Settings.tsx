import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { MainLayout } from "@/layouts/MainLayout";

export const Settings: React.FC = () => {
  const navigate = useNavigate();
  const [showKey, setShowKey] = useState(false);

  return (
    <MainLayout>
      <div className="flex-1 overflow-y-auto p-8">
        <div className="mx-auto max-w-4xl">
          <div
            className="flex items-center gap-2 mb-6 text-text-secondary hover:text-primary transition-colors cursor-pointer w-fit"
            onClick={() => navigate("/")} // 点击跳转回首页
          >
            <span className="material-symbols-outlined text-xl">
              arrow_back
            </span>
            <span className="font-bold text-sm">Back to Workspace</span>
          </div>

          {/* 标题区 */}
          <div className="flex flex-col gap-3 mb-8">
            <h1 className="text-primary text-5xl font-bold leading-tight font-display">
              API Key Garden
            </h1>
            <p className="text-text-primary/80 text-base font-normal leading-normal">
              Connect your magical service sprites by adding their secret keys.
              These are needed to weave your audio stories.
            </p>
          </div>

          <div className="flex flex-col gap-6">
            {/* Google Gemini (已连接状态) */}
            <div className="flex flex-col gap-6 rounded-lg bg-white/50 border border-secondary/30 p-6 shadow-sm">
              <div className="flex items-start justify-between">
                <div className="flex items-center gap-4">
                  <div
                    className="bg-center bg-no-repeat aspect-square bg-cover size-14 rounded-full border border-secondary"
                    style={{
                      backgroundImage:
                        'url("https://lh3.googleusercontent.com/aida-public/AB6AXuD8ABeElpLDzSmLeBhFJGQcQMXtCA5zEjRjJ3JFJY1-Tom7pxoIBGaRkbjwRD8IqoZDJ6xy_HAm_Uey3xmYDbgwl7V8ehVoHR8oV7DqKrqnSUoeJPclf9QAFAorOtOgv0y1J6Pdbup56s6QDM2csrXqGZzJ4codxslNZASu3jVFQhMYuSNHWGfmsJcICZzdid_a05EE6GTu30vQTcdZq2l8GtAW-EEzgGQjW92CAZKRpRILCEC-tQ2bQF7vuCs_QelxXu58x4LQt4M")',
                    }}
                  ></div>
                  <div className="flex flex-col justify-center">
                    <div className="flex items-center gap-2">
                      <p className="text-text-primary text-xl font-bold leading-normal">
                        Google Gemini Sprite
                      </p>
                      <span className="flex items-center gap-1.5 text-xs font-bold text-primary border border-primary/50 bg-primary/10 px-2 py-0.5 rounded-full">
                        <span className="size-2 bg-primary rounded-full"></span>
                        Connected
                      </span>
                    </div>
                    <p className="text-text-secondary text-sm font-normal">
                      Status: Active
                    </p>
                  </div>
                </div>
                <button className="text-sm font-bold text-primary hover:underline transition-colors">
                  Edit
                </button>
              </div>
            </div>

            {/* ByteDance (需要输入 Key) */}
            <div className="flex flex-col gap-6 rounded-lg bg-white border-2 border-primary/50 p-6 shadow-md">
              <div className="flex items-start justify-between">
                <div className="flex items-center gap-4">
                  <div
                    className="bg-center bg-no-repeat aspect-square bg-cover size-14 rounded-full border border-secondary"
                    style={{
                      backgroundImage:
                        'url("https://lh3.googleusercontent.com/aida-public/AB6AXuAPbtgtG8SOAJLqCwENOBZQmtQykyHxE1e-Pj31lzfJ_EH5Za6bRFn_ogo9DEWjT2s1hY-LkSvMLCxc6ibU2vzfknsu_KzEsM73JtRHu3EUqfWu09yrh9eq1RoY4eC6fkpU20fJQmwk3Mnwchkn7yYqsZSBvlI8Cs6Kh-LC4f_ONntq614vqd2bzPS10U9OOO86Xf9FdIc6t16Dk5ODZL3Kodjf_A72ra24Oplj31m1NRw95xZWeZT70wt7a0P8DUBaKCXByRdEeaM")',
                    }}
                  ></div>
                  <div className="flex flex-col justify-center">
                    <div className="flex items-center gap-2">
                      <p className="text-text-primary text-xl font-bold leading-normal">
                        ByteDance TTS Sprite
                      </p>
                      <span className="flex items-center gap-1.5 text-xs font-bold text-yellow-600 border border-yellow-600/50 bg-yellow-100 px-2 py-0.5 rounded-full">
                        <span className="size-2 bg-yellow-600 rounded-full"></span>
                        Needs a key!
                      </span>
                    </div>
                    <p className="text-text-secondary text-sm font-normal">
                      Enter the secret key to awaken this sprite.
                    </p>
                  </div>
                </div>
              </div>

              {/* Input Area */}
              <div className="flex flex-col gap-4">
                <label className="flex flex-col w-full">
                  <div className="flex items-center pb-2 gap-1.5">
                    <p className="text-text-primary text-sm font-bold tracking-wide">
                      Secret Key
                    </p>
                  </div>
                  <div className="flex w-full flex-1 items-stretch relative">
                    <input
                      className="w-full text-text-primary focus:outline-none focus:ring-2 focus:ring-primary border-2 border-secondary/50 bg-background-light h-12 placeholder:text-text-secondary/50 p-3 pr-10 text-base rounded-lg transition-all"
                      type={showKey ? "text" : "password"}
                      placeholder="sk-.........................."
                    />
                    <button
                      onClick={() => setShowKey(!showKey)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-text-secondary hover:text-primary"
                    >
                      <span className="material-symbols-outlined text-xl">
                        {showKey ? "visibility_off" : "visibility"}
                      </span>
                    </button>
                  </div>
                </label>
                <div className="flex flex-wrap gap-3 justify-start">
                  <button className="px-6 py-2 rounded-lg border-2 border-primary text-primary font-bold hover:bg-primary/10 transition-colors">
                    Test
                  </button>
                  <button className="px-6 py-2 rounded-lg bg-primary text-white font-bold hover:bg-opacity-90 shadow-md transition-all transform active:scale-95">
                    Save
                  </button>
                </div>
              </div>
            </div>

            {/* TTSFM (连接错误) */}
            <div className="flex flex-col gap-6 rounded-lg bg-white/50 border border-red-200 p-6 shadow-sm">
              <div className="flex items-start justify-between">
                <div className="flex items-center gap-4">
                  <div
                    className="bg-center bg-no-repeat aspect-square bg-cover size-14 rounded-full border border-secondary"
                    style={{
                      backgroundImage:
                        'url("https://lh3.googleusercontent.com/aida-public/AB6AXuDlbhDmNtnaLvRAClhmQ5QKib6i9RF_JHmpHB3wGuexhoBlC4s_Ab8f1j2LYlvsUGDMMd6ns7adwjSfiafB2xUPZt8ODlCppQk6RYZM2p-0Vo9l7Roqq0YdhEsl_h3-89AIXSnnGYf3LzYOhDQE7sRch-qVmoNf9ZQip_rfxHSnpnWfCM0lC_VYXRXZd-e_vp_M4-UPU9LaCu1ht-dVjq6aL43GpvYibt2CGWvrGa0WWaX90P_3Lc0xKSNtLfVIXLHQYhxTfX8pYeE")',
                    }}
                  ></div>
                  <div className="flex flex-col justify-center">
                    <div className="flex items-center gap-2">
                      <p className="text-text-primary text-xl font-bold leading-normal">
                        TTSFM Sprite
                      </p>
                      <span className="flex items-center gap-1.5 text-xs font-bold text-red-500 border border-red-500/50 bg-red-100 px-2 py-0.5 rounded-full">
                        <span className="size-2 bg-red-500 rounded-full"></span>
                        Connection Error
                      </span>
                    </div>
                    <p className="text-text-secondary text-sm font-normal">
                      The key is wrong. Check the spell and try again.
                    </p>
                  </div>
                </div>
                <button className="text-sm font-bold text-primary hover:underline transition-colors">
                  Edit
                </button>
              </div>
            </div>
          </div>

          <div className="flex items-center justify-center mt-12 gap-2 text-text-secondary/60">
            <span className="material-symbols-outlined text-lg">lock</span>
            <p className="text-sm">
              Your secret keys are kept safe with powerful enchantment.
            </p>
          </div>
        </div>
      </div>
    </MainLayout>
  );
};
