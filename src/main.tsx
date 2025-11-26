import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App.tsx";
import "./index.css";

// ▼▼▼ 新增：直接获取 root 元素并暴力设置样式 ▼▼▼
const rootElement = document.getElementById("root")!;
rootElement.style.width = "100vw"; // 强制视口宽度
rootElement.style.height = "100vh"; // 强制视口高度
rootElement.style.margin = "0";
rootElement.style.padding = "0";
rootElement.style.maxWidth = "none"; // 清除任何最大宽度限制
rootElement.style.display = "flex"; // 设为 Flex 容器
rootElement.style.flexDirection = "column";
// ▲▲▲▲▲▲

ReactDOM.createRoot(rootElement).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
