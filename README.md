# MiniTranslate

macOS 菜单栏翻译工具 — 选中文本或截图，一键翻译。

基于 DeepL API，纯 Swift 实现，零外部依赖，最低支持 macOS 13.0。

## 功能

| 功能 | 快捷键 | 说明 |
|------|--------|------|
| **滑词翻译** | `Ctrl + Option + X` | 选中任意文本后按快捷键，弹出翻译窗口 |
| **截图翻译** | `Ctrl + Option + Z` | 框选屏幕区域，OCR 识别文字后翻译 |
| 设置 | 菜单栏 → 设置… (`Cmd + ,`) | 输入 DeepL API Key |
| 复制结果 | 翻译窗口中 `Cmd + C` | 复制原文和译文 |

### 智能目标语言

- 原文为**中文** → 自动翻译成**英文**
- 原文为**其他语言**（英文、韩文等） → 自动翻译成**中文**

翻译窗口中可以手动切换语言方向。

### OCR 双语识别

截图翻译使用 Apple Vision 框架，并行运行 CJK（中日韩）和 Latin（英法德西等）两路识别模型，按置信度合并结果，避免中文被误识别为英文乱码。

## 安装与构建

### 前置条件

- macOS 13.0+
- Xcode Command Line Tools（`xcrun`、`swiftc`、`iconutil`）
- DeepL API Key（在 [deepl.com](https://www.deepl.com/pro-api) 免费注册获取）

### 构建

```bash
# 1. 创建代码签名证书（仅首次，用于保持系统权限不丢失）
bash setup-codesign.sh

# 2. 构建并启动
bash build.sh
```

首次打开需要右键 `MiniTranslate.app` → 打开（绕过 Gatekeeper），并在 **系统设置 → 隐私与安全性** 中授权：
- **辅助功能**（读取选中文本 + 全局快捷键）
- **屏幕录制**（截图 OCR）

之后每次重编译不再需要重新授权。

### 打开设置

启动后点击菜单栏图标 → **设置…**，输入 DeepL API Key（Free 或 Pro 均可），点保存。

## 项目结构

```
MiniTranslate/
  build.sh                      # 构建脚本（swiftc 编译 + 图标生成 + 代码签名）
  setup-codesign.sh             # 创建自签名证书（一次性）
  Scripts/
    generate-icon.swift          # 应用图标生成器
  Sources/
    main.swift                   # 入口
    MiniTranslateApp.swift       # AppDelegate：菜单栏、热键、组件装配
    TranslationOrchestrator.swift # 翻译流程编排（滑词 / 截图）
    Translator/
      Language.swift             # 语言枚举 + 智能目标语言检测
      Translator.swift           # DeepL HTTP API 客户端
      TranslationServiceProtocol.swift
      DeepLError.swift
    Keychain/
      KeychainStore.swift        # macOS Keychain 封装
    Settings/
      SettingsView.swift         # SwiftUI 设置界面
    TranslationWindow/
      TranslationView.swift      # SwiftUI 翻译结果界面
      TranslationWindowController.swift
    Hotkey/
      HotkeyManager.swift        # Carbon 全局热键
    TextAccess/
      TextAccessor.swift         # 选中文本读取（AX + Cmd+C 双路径）
    OCR/
      OCRReader.swift            # Vision OCR（CJK + Latin 并行识别）
    ScreenCapture/
      ScreenshotOverlay.swift    # 截图区域框选
  Tests/
    TranslatorTests.swift        # Translator 单元测试
```

## 技术实现

- **零依赖**：仅使用系统框架（Cocoa、SwiftUI、Vision、Carbon、Security、ApplicationServices）
- **菜单栏应用**：`LSUIElement` 模式，无 Dock 图标
- **全局热键**：Carbon Event Manager 注册 `Ctrl+Option+X` / `Ctrl+Option+Z`
- **文本获取**：优先 Accessibility API，失败时模拟 `Cmd+C` 读取剪贴板
- **OCR**：Vision `VNRecognizeTextRequest` 双路并行（CJK + Latin），按置信度和 bounding box 合并去重
- **翻译**：DeepL API（`api-free.deepl.com`），源语言 auto，目标语言智能推断
- **安全存储**：API Key 存入 macOS Keychain
- **代码签名**：自签名证书确保权限在重编译后持久保留

## 许可

GNU General Public License v3.0
