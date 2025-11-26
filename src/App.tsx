import React from "react";
import { HashRouter as Router, Routes, Route } from "react-router-dom";
import { Workspace } from "./pages/Workspace";
import { Settings } from "./pages/Settings";

function App() {
  return (
    // Electron 环境推荐使用 HashRouter
    <Router>
      <Routes>
        <Route path="/" element={<Workspace />} />
        <Route path="/settings" element={<Settings />} />
      </Routes>
    </Router>
  );
}

export default App;
