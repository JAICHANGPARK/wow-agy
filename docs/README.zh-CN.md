# Antigravity AI 攻略与编程工作室 — WoW Forever (`Interface: 16001`)

🌐 **语言选择 (Languages)**: [English](../README.md) | [한국어](README.ko.md) | [日本語](README.ja.md) | **简体中文**

专为 **《魔兽世界：永恒》(World of Warcraft: Forever, `## Interface: 16001`)** 打造的游戏内 **AI 攻略问答助手** 与 **Google Antigravity (`google-antigravity` SDK / `agy` CLI) Lua 插件编程工作室**。无需切出游戏（Alt+Tab），即可在游戏内查询任务路线、BOSS 机制、对比装备属性，或实时编写与调试 Lua 插件。

---

## 严格遵守暴雪官方 UI 插件开发政策

本项目严格遵循 **暴雪娱乐 (Blizzard Entertainment) 官方 UI 插件开发政策** 与用户协议 (ToU)：

- **100% 免费与开源 ([MIT License](../LICENSE))**：无任何付费墙、订阅限制、游戏内广告或赞赏/捐款链接。
- **100% 明文 Lua/XML 代码**：绝不使用代码混淆、加密或任何外部二进制文件 (`.dll`/`.so`)。
- **无屏幕像素扫描、无内存读取、无模拟按键**：不采用屏幕像素条码抓取或音频/占位插件绕过沙盒的技巧，仅使用暴雪标准的 **`SavedVariables` 文件同步** 以及与 WeakAuras/SimC 相同的 **用户主动文本框复制粘贴 (`Ctrl+C`/`V`)**。
- **零战斗自动化 (反外挂合规)**：绝不自动控制角色移动、选定目标或自动释放技能，所有受保护操作严格遵守 `InCombatLockdown()` 与 `C_Secrets` 限制。
- **安全宏备份与一键撤销**：包含 `/run` 的宏会显示安全提示，并可通过 `/agy undo` 一键恢复被修改的宏。

---

## 核心功能

1. **游戏内魔兽 AI 攻略百科 (Q&A 问答模式)**
   - 随时在聊天框输入 `/wowask <问题>` 提问，或使用三大一键提问预设按钮
   - 自动附带角色等级/职业、当前地图坐标、**全身已装备物品 (1–18 栏位)**、**专业技能点数**、**当前目标信息 (名称与 NPC ID)** 及 **任务进度详情**
   - **官方 `C_TooltipInfo` 物品属性提取**：通过 **`Shift+点击` 或鼠标拖拽** 背包物品/技能至输入框，自动读取完整装备词条与技能说明，精准对比装备提升
   - **一键地图标记 (`📍 地图标记`) 与小队三行摘要分享**：将回答中的坐标直接设为原生地图标点与导航箭头 (`UiMapPoint` + `C_SuperTrack`)

2. **四标签页游戏内 Lua 编程 IDE**
   - **标签 1 (游戏问答 & 编程)** / **标签 2 (实时 Lua 编辑器：`Ctrl+Enter` 免重载运行)** / **标签 3 (Lua 报错堆栈捕获与一键 AI 修复)** / **标签 4 (代码片段库与官方 `/api`、`/fstack` 工具)**

3. **全球 12 种语言实时切换 (默认英语 `enUS`，原生支持简/繁体中文)**
   - 自动识别 `zhCN` / `zhTW` 客户端并联动 NGA、178、巴哈姆特与 Wowhead 搜索；也可点击右上角 **`[🌐 Auto (...)]`** 或输入 `/agy lang zhCN` 免重载切换语言。

---

## 安装与启动步骤

### 第一步：安装插件到魔兽目录

**macOS / Linux:**
```bash
chmod +x ./scripts/install.sh
./scripts/install.sh "/Applications/World of Warcraft/_forever_"
```

**Windows (PowerShell):**
```powershell
.\scripts\install.ps1 "C:\Program Files (x86)\World of Warcraft\_forever_"
```

### 第二步：配置 Antigravity 身份认证（首次运行 — 支持 4 种方式）

可通过内置交互式向导一键完成配置或检查认证状态：

```bash
# 运行交互式认证配置向导（推荐使用 uv — 自动管理虚拟环境与 SDK）
uv run wow-agy-daemon --setup-auth

# 检查当前认证状态
uv run wow-agy-daemon --check-auth
```

- **方式 1（安装 `agy` CLI 并登录谷歌账号，免 API Key）**：
  - 若尚未安装 `agy` CLI，可一行命令安装（macOS/Linux: `curl -fsSL https://antigravity.google/cli/install.sh | bash` / Windows PS: `irm https://antigravity.google/cli/install.ps1 | iex`），随后在终端运行一次 `agy` 完成浏览器登录即可。
- **方式 2（Google AI Studio API Key）**：在 https://aistudio.google.com/app/api-keys 获取密钥，通过 `--setup-auth` 自动写入本地 `.env` 文件（`0600` 权限且已加入 `.gitignore`）。
- **方式 3（Google Cloud / Vertex AI ADC）**：运行 `gcloud auth application-default login` 并搭配 `--vertex --project <项目ID>`。
- **方式 4（纯本地模型，免认证/零费用）**：使用 LiteRT Gemma 4 (`--litert-model`) 或本地 Ollama / LM Studio (`--local-openai-url`)。

### 第三步：启动本地伴侣桥接守护进程（原生支持 `uv`）

```bash
# 方式 A（推荐）：使用 uv 一键同步环境并启动（无需手动 pip install！）
uv run wow-agy-daemon --wow-dir "/Applications/World of Warcraft/_forever_"

# 方式 B：本地 LiteRT / Ollama 模式（免 API Key）
uv run --extra litert wow-agy-daemon --backend sdk --litert-model ~/.litert-lm/models/gemma4-26b/model.litertlm
uv run wow-agy-daemon --backend sdk --local-openai-url http://localhost:11434/v1 --local-model gemma4:26b

# 方式 C：使用标准 python3 直接运行（搭配已登录的 agy CLI，零依赖）
python3 bridge/daemon.py --wow-dir "/Applications/World of Warcraft/_forever_"
```

---

## 游戏内使用方法

1. **免 `/reload` 即时问答与代码运行（剪贴板桥接模式）**：
   - 输入 `/agy` 打开窗口，输入问题后按 **`Ctrl+Enter`**（或点击 `[复制请求包 (免重载)]`）并按 **`Ctrl+C` (`Cmd+C`)**。
   - 收到桌面完成通知后，点击 **`[粘贴剪贴板回答/代码]`** → **`Ctrl+V` (`Cmd+V`)** → 点击 **`[在窗口显示回答]`** 即可免读条查看攻略并一键打地图标记！
2. **完整插件文件创建与修改（`SavedVariables` 同步模式）**：
   - 输入插件开发或报错修复需求，点击 **`[发送并同步 (/reload)]`**（`Alt+Enter`）；待收到完成通知后再次 `/reload` 即可加载新插件。
