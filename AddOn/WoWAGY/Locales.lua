local addonName, ns = ...

-- ============================================================================
-- Locales.lua
-- Multilingual Localization Engine for World of Warcraft: Forever (16001)
-- Default Fallback: English (enUS / enGB)
-- Supported Official WoW Locales: enUS, koKR, zhCN, zhTW, deDE, frFR, esES, esMX, ptBR, ruRU, itIT
-- Additional Community Locale: jaJP (Japanese, selectable via UI / `/agy lang jaJP`)
-- ============================================================================

ns.LOCALE_ORDER = {
    "auto",
    "enUS",
    "koKR",
    "jaJP",
    "zhCN",
    "zhTW",
    "deDE",
    "frFR",
    "esES",
    "esMX",
    "ptBR",
    "ruRU",
    "itIT",
}

ns.LOCALE_LABELS = {
    auto = "Auto (Client)",
    enUS = "English",
    koKR = "한국어",
    jaJP = "日本語",
    zhCN = "简体中文",
    zhTW = "繁體中文",
    deDE = "Deutsch",
    frFR = "Français",
    esES = "Español (EU)",
    esMX = "Español (AL)",
    ptBR = "Português",
    ruRU = "Русский",
    itIT = "Italiano",
}

local LOCALES = {}

-- 1. Default Fallback: English (enUS / enGB)
LOCALES.enUS = {
    APP_SUBTITLE = "(WoW Forever)",
    TAB_1 = "1. Q&A & Coding",
    TAB_2 = "2. Live Lua Studio",
    TAB_3 = "3. Error Debugger",
    TAB_4 = "4. Snippets & Tools",

    STATUS_BAR = "TOC: |cff34A85316001|r  |  Pending: |cffFBBC05%d|r  |  Errors: |cffEA4335%d|r",
    ROLE_USER = "|cffFBBC05[Me]|r ",

    BTN_WAYPOINT = "📍 Map Pin",
    BTN_RUN_REPLY = "▶ Run Code",
    BTN_TO_EDITOR = "To Editor",
    BTN_MAKE_MACRO = "Make Macro",
    BTN_SHARE = "Share / Copy",
    BTN_PASTE_CLIP = "Paste Reply / Code",

    MODE_AUTO = "Mode: |cffFBBC05Auto (Q&A+Code)|r",
    MODE_QA   = "Mode: |cff34A853WoW Q&A Guide|r",
    MODE_CODE = "Mode: |cff4285F4Lua Coding|r",

    PRESET_TARGET = "🎯 Ask About Target",
    PRESET_QUEST  = "📜 Quest Route Help",
    PRESET_BUILD  = "⚔️ Class & Gear Tips",

    OPT_ATTACH_CTX   = "Attach Player/Gear/Target/Quests",
    OPT_ATTACH_ERR   = "Attach Lua Errors (Code)",
    OPT_ATTACH_MOUSE = "Attach Mouseover Frame",

    BTN_SEND_RELOAD = "Send / Sync (/reload)",
    BTN_QUEUE_ONLY  = "Queue Only (Reload Later)",
    BTN_COPY_CLIP   = "Copy Request (No-Reload)",
    BTN_CLEAR_CHAT  = "Clear",

    EDITOR_HEADER = "|cff4285F4Live Lua Studio|r: Test WoW Forever (16001) Lua APIs instantly without /reload. (Ctrl+Enter to Run)",
    BTN_RUN_LUA = "▶ Run Lua Now",
    BTN_SAVE_SNIPPET = "Save Snippet",
    BTN_RUN_MACRO = "Create /run Macro",
    BTN_ASK_REFACTOR = "Ask AGY to Improve / Addonize",
    OUTPUT_LABEL = "Execution Console:",
    OUTPUT_PLACEHOLDER = "-- Click [▶ Run Lua Now] or press Ctrl+Enter to view print() output and execution time.",

    ERR_NONE = "|cff34A853No runtime Lua errors captured.|r",
    ERR_PLACEHOLDER = "-- Runtime Lua errors and stack traces from any addon are captured here automatically.\n-- Click [Trigger Test Error] at top-right to test.",
    ERR_SUMMARY = "Error |cffFBBC05%d / %d|r  |  Addon: |cffEA4335%s|r  |  Count: %dx  (%s)",
    BTN_PREV_ERR = "◀ Prev",
    BTN_NEXT_ERR = "Next ▶",
    BTN_TEST_ERR = "Test Error",
    BTN_ASK_FIX_ERR = "Ask Antigravity to Analyze & Fix Error",
    BTN_CLEAR_ERR = "Clear All Errors",

    TOOLS_HEADER = "Official Blizzard In-Game Developer Tools (WoW Forever 16001)",
    BTN_OPEN_API = "Open /api Browser",
    BTN_OPEN_FSTACK = "Toggle /fstack",
    BTN_OPEN_ETRACE = "Toggle /etrace",
    BTN_RELOAD_UI = "Reload UI (/reload)",
    SNIPPETS_HEADER = "Saved Lua Snippets Library (Top 8)",
    BTN_LOAD_SNIPPET = "Load in Editor",
    BTN_EXEC_SNIPPET = "▶ Run",
    BTN_DEL_SNIPPET = "Del",

    CLIP_COPY_TITLE = "|cff4285F4Clipboard Bridge: Copy Request Packet (Zero-Reload)|r",
    CLIP_COPY_HINT  = "The packet below is highlighted. Press |cffFBBC05Ctrl+C (Cmd+C on Mac)|r; the background daemon will process it and copy the reply back.",
    CLIP_PASTE_TITLE = "|cff34A853Clipboard Bridge: Paste Antigravity Reply / Code (Zero-Reload)|r",
    CLIP_PASTE_HINT  = "Press |cffFBBC05Ctrl+V (Cmd+V)|r, then click [Show Reply in Chat] for Q&A answers or [▶ Run Lua Code] for scripts.",
    BTN_SHOW_IN_CHAT = "Show Reply in Chat (No-Reload)",
    BTN_CLOSE = "Close",

    MINIMAP_TIP_LCLICK = "|cffFFFFFFLeft-Click:|r Toggle Studio Window",
    MINIMAP_TIP_RCLICK = "|cffFFFFFFRight-Click:|r Open Live Lua Editor",
    MINIMAP_TIP_SCLICK = "|cffFFFFFFShift-Click:|r Sync (/reload)",
    MINIMAP_TIP_DRAG   = "|cffFFFFFFDrag:|r Move Minimap Button",

    SETTINGS_DESC = "Ask WoW Forever gameplay/quest/item questions and vibe-code Lua addons in-game with Google Antigravity.",
    SETTINGS_AUTO_OPEN = "Auto-open Studio window when new AI replies arrive on login/reload",
    SETTINGS_HIDE_MINI = "Hide Minimap Launcher Button",
    SETTINGS_OPEN_BTN  = "Open Antigravity Studio (/agy)",
    SETTINGS_RESET_POS = "Reset Window Position",

    BINDING_HEADER = "wow-agy (AI Guide & Studio)",
    BINDING_TOGGLE = "Toggle wow-agy Q&A & Studio",
    BINDING_TARGET = "Quick Ask About Current Target",
    BINDING_LUA    = "Open Live Lua Studio",

    MSG_READY = "Ready! Type |cffFBBC05/agy|r (Studio) or |cff34A853/wowask <question>|r to ask anything.",
    MSG_NEW_REPLIES = "%d new Antigravity reply(s) received! Type |cffFBBC05/agy|r to view.",
    MSG_COMBAT_RELOAD = "|cffEA4335Cannot /reload during combat.|r Your request is queued; reload after combat.",
    MSG_COMBAT_MACRO = "|cffEA4335Cannot create or edit macros during combat.|r",
    MSG_EMPTY_PROMPT = "Please enter a question or coding request first.",
    MSG_QUEUED = "Request queued! Run /reload anytime (or wait for sync) to process via Antigravity daemon.",
    MSG_LANG_CHANGED = "Language set to: |cffFFD100%s|r (Effective: %s)",

    ERR_EMPTY_LUA      = "Lua code is empty. Enter code to execute first.",
    ERR_NO_LOADSTRING  = "loadstring() is unavailable in this client environment.",
    ERR_SYNTAX_PREFIX  = "[Syntax Error] ",
    ERR_RUNTIME_PREFIX = "[Runtime Error] ",
    ERR_OUTPUT_TRUNC   = "... (Output truncated at %d lines to prevent client freeze)",
    ERR_NO_WAYPOINT    = "No map coordinates attached to the latest AI reply.",
    ERR_BAD_COORDS     = "Coordinates (%.1f, %.1f) are outside the valid 0-100 map range.",
    ERR_WAYPOINT_UNSUP = "Coordinates: |cffFFD100%s|r (%.1f, %.1f) [User pins unsupported in this instance/map]",
    MSG_WAYPOINT_SET   = "📍 Map Pin set: |cffFFD100%s|r (%.1f, %.1f) %s",
    ERR_NO_CODE        = "No Lua code snippet is attached to the latest AI reply.",
    ERR_NO_MACRO       = "No macro body is attached to the latest AI reply.",
    ERR_MACRO_EMPTY    = "Macro body is empty.",
    ERR_MACRO_FULL     = "|cffEA4335General macro slots (120) are full.|r Delete an unused macro first.",
    ERR_MACRO_NO_UNDO  = "No recent macro creation/update to undo.",
    ERR_NO_SHARE_MSG   = "No recent AI reply available to share.",
    ERR_SHARE_COOLDOWN = "Please wait %.1fs before sharing to chat again.",
    ERR_CLIP_EMPTY     = "Clipboard input box is empty. Paste (Ctrl+V / Cmd+V) a reply or Lua snippet first.",

    WELCOME_BODY = table.concat({
        "|cff4285F4[Antigravity]|r Welcome to **Antigravity AI Guide & Code Studio** for WoW Forever (16001)!",
        "",
        "• |cffFFD100Ask Anything About WoW|r: Quest routes, boss tactics, item drops & builds! Target an NPC/mob or |cffFBBC05Shift+Click / Drag|r items & spells into the input box.",
        "• |cff34A853Zero-Reload Instant Answers|r: Click [Copy Request (No-Reload)] (Ctrl+C) -> wait for desktop notification -> click [Paste Reply / Code] (Ctrl+V)!",
        "• |cff4285F4Vibe-Code Addons & Live Lua|r: Build/fix `.lua` addons in `Interface/AddOns/` or run live Lua snippets without reloading.",
    }, "\n"),

    PROMPT_TARGET_WITH_NAME = "Tell me about my current target '%s' in WoW Forever: key mechanics/tactics, notable item drops, and related quests!",
    PROMPT_TARGET_NONE      = "What rare mobs, quest hubs, or farming spots should I watch out for in my current zone?",
    PROMPT_QUEST_ASK        = "Based on my active quests and objective progress, what is the most efficient route and target coordinates?",
    PROMPT_BUILD_ASK        = "For my current class, level, equipped gear, and professions in WoW Forever, what talents, rotation tips, and gear upgrades do you recommend?",
    PROMPT_REFACTOR         = "Review and improve this WoW Forever (16001) Lua snippet, or turn it into a standalone addon:\n```lua\n%s\n```",
    PROMPT_FIX_ERR          = "A runtime Lua error occurred in addon [%s]. Please diagnose and fix it for WoW Forever (Interface: 16001):\nError: %s\nStack:\n%s",
}

-- 2. Korean (koKR)
LOCALES.koKR = {
    APP_SUBTITLE = "(와우 포에버)",
    TAB_1 = "1. 질문(Q&A) & 코딩",
    TAB_2 = "2. Live Lua 에디터",
    TAB_3 = "3. 에러 디버거",
    TAB_4 = "4. 스니펫 & 공식 툴",

    STATUS_BAR = "TOC: |cff34A85316001|r  |  대기 질문: |cffFBBC05%d건|r  |  에러: |cffEA4335%d건|r",
    ROLE_USER = "|cffFBBC05[나]|r ",

    BTN_WAYPOINT = "📍 좌표 핀",
    BTN_RUN_REPLY = "▶ 코드 실행",
    BTN_TO_EDITOR = "에디터로",
    BTN_MAKE_MACRO = "매크로 생성",
    BTN_SHARE = "답변 공유/복사",
    BTN_PASTE_CLIP = "클립보드 답변/코드 붙여넣기",

    MODE_AUTO = "모드: |cffFBBC05자동 (질문+코딩)|r",
    MODE_QA   = "모드: |cff34A853와우 Q&A 공략|r",
    MODE_CODE = "모드: |cff4285F4Lua 코딩|r",

    PRESET_TARGET = "🎯 현재 타겟 공략·드랍 질문",
    PRESET_QUEST  = "📜 진행 중 퀘스트 길찾기",
    PRESET_BUILD  = "⚔️ 내 직업·장비 육성 팁",

    OPT_ATTACH_CTX   = "캐릭터·장비·타겟·퀘스트 첨부",
    OPT_ATTACH_ERR   = "Lua 에러 첨부(코딩 시)",
    OPT_ATTACH_MOUSE = "마우스오버 프레임 첨부",

    BTN_SEND_RELOAD = "전송 / 답변 동기화 (/reload)",
    BTN_QUEUE_ONLY  = "큐에만 추가 (나중에 리로드)",
    BTN_COPY_CLIP   = "클립보드 질문/요청 복사 (무-리로드)",
    BTN_CLEAR_CHAT  = "비우기",

    EDITOR_HEADER = "|cff4285F4Live Lua Studio|r: WoW Forever (16001) API를 리로드 없이 실시간 테스트하세요. (Ctrl+Enter 실행)",
    BTN_RUN_LUA = "▶ 즉시 실행 (Run Lua)",
    BTN_SAVE_SNIPPET = "스니펫 저장",
    BTN_RUN_MACRO = "/run 매크로 생성",
    BTN_ASK_REFACTOR = "이 코드 AGY에게 개선/애드온화 요청",
    OUTPUT_LABEL = "실행 결과 콘솔:",
    OUTPUT_PLACEHOLDER = "-- [▶ 즉시 실행] 또는 Ctrl+Enter를 누르면 print() 출력과 실행 시간이 표시됩니다.",

    ERR_NONE = "|cff34A853현재 캡처된 런타임 Lua 에러가 없습니다.|r",
    ERR_PLACEHOLDER = "-- 다른 애드온이나 스크립트에서 Lua 에러가 발생하면 이곳에 스택 트레이스가 자동 기록됩니다.\n-- 우측 상단 [테스트 에러] 버튼으로 동작을 확인해 볼 수 있습니다.",
    ERR_SUMMARY = "에러 |cffFBBC05%d / %d|r  |  애드온: |cffEA4335%s|r  |  횟수: %d회  (%s)",
    BTN_PREV_ERR = "◀ 이전 에러",
    BTN_NEXT_ERR = "다음 에러 ▶",
    BTN_TEST_ERR = "테스트 에러",
    BTN_ASK_FIX_ERR = "선택한 에러 Antigravity에게 원인 분석 & 자동 수정 요청",
    BTN_CLEAR_ERR = "에러 기록 모두 지우기",

    TOOLS_HEADER = "블리자드 공식 인게임 개발자 도구 바로가기 (WoW Forever 16001)",
    BTN_OPEN_API = "/api 공식 문서 열기",
    BTN_OPEN_FSTACK = "/fstack 프레임 인스펙터",
    BTN_OPEN_ETRACE = "/etrace 이벤트 추적",
    BTN_RELOAD_UI = "UI 새로고침 (/reload)",
    SNIPPETS_HEADER = "저장된 Lua 스니펫 라이브러리 (최대 8개)",
    BTN_LOAD_SNIPPET = "에디터로 열기",
    BTN_EXEC_SNIPPET = "▶ 실행",
    BTN_DEL_SNIPPET = "삭제",

    CLIP_COPY_TITLE = "|cff4285F4클립보드 브릿지: 질문/코딩 패킷 복사 (무-리로드)|r",
    CLIP_COPY_HINT  = "아래 패킷이 전체 선택되었습니다. |cffFBBC05Ctrl+C (Mac은 Cmd+C)|r 를 누르면 백그라운드 데몬이 답변을 클립보드로 즉시 돌려줍니다!",
    CLIP_PASTE_TITLE = "|cff34A853클립보드 브릿지: Antigravity 답변/코드 붙여넣기 (무-리로드)|r",
    CLIP_PASTE_HINT  = "|cffFBBC05Ctrl+V (Cmd+V)|r 로 붙여넣은 뒤, 질문 답변은 [대화창에 답변 표시]를, 코드는 [▶ 코드 실행]을 누르세요.",
    BTN_SHOW_IN_CHAT = "대화창에 답변 표시 (무-리로드)",
    BTN_CLOSE = "닫기",

    MINIMAP_TIP_LCLICK = "|cffFFFFFF좌클릭:|r 스튜디오 창 열기/닫기",
    MINIMAP_TIP_RCLICK = "|cffFFFFFF우클릭:|r Live Lua 에디터 열기",
    MINIMAP_TIP_SCLICK = "|cffFFFFFFShift+클릭:|r 동기화 (/reload)",
    MINIMAP_TIP_DRAG   = "|cffFFFFFF드래그:|r 미니맵 아이콘 이동",

    SETTINGS_DESC = "인게임에서 와우 퀘스트·공략·아이템 질문(Q&A)과 Antigravity Lua 애드온 코딩·디버깅을 함께 수행합니다.",
    SETTINGS_AUTO_OPEN = "새 AI 응답 수신 후 로그인/리로드 시 자동으로 창 열기",
    SETTINGS_HIDE_MINI = "미니맵 런처 아이콘 숨기기",
    SETTINGS_OPEN_BTN  = "Antigravity 스튜디오 열기 (/agy)",
    SETTINGS_RESET_POS = "창 위치 중앙 초기화",

    BINDING_HEADER = "wow-agy (AI 가이드 & 코딩 스튜디오)",
    BINDING_TOGGLE = "wow-agy 질문 & 코딩 창 열기/닫기",
    BINDING_TARGET = "현재 타겟 몬스터/NPC 즉시 공략·드랍 질문",
    BINDING_LUA    = "Live Lua 코드 에디터 바로 열기",

    MSG_READY = "준비 완료! |cffFBBC05/agy|r (스튜디오) 또는 |cff34A853/와우질문 <궁금한점>|r 을 입력해 보세요.",
    MSG_NEW_REPLIES = "새 Antigravity 답변 %d건이 도착했습니다! |cffFBBC05/agy|r 로 확인하세요.",
    MSG_COMBAT_RELOAD = "|cffEA4335전투 중에는 /reload를 실행할 수 없습니다.|r 요청은 큐에 저장되었으니 전투 종료 후 리로드해 주세요.",
    MSG_COMBAT_MACRO = "|cffEA4335전투 중에는 매크로를 생성하거나 수정할 수 없습니다.|r",
    MSG_EMPTY_PROMPT = "질문 또는 코딩 요청 내용을 먼저 입력해 주세요.",
    MSG_QUEUED = "요청이 큐에 저장되었습니다. 원할 때 /reload 하면 로컬 Antigravity 데몬이 처리합니다.",
    MSG_LANG_CHANGED = "언어가 변경되었습니다: |cffFFD100%s|r (적용 언어: %s)",

    ERR_EMPTY_LUA      = "실행할 Lua 코드가 비어 있습니다.",
    ERR_NO_LOADSTRING  = "현재 클라이언트에서 loadstring()을 사용할 수 없습니다.",
    ERR_SYNTAX_PREFIX  = "[문법 에러] ",
    ERR_RUNTIME_PREFIX = "[런타임 에러] ",
    ERR_OUTPUT_TRUNC   = "... (클라이언트 멈춤 방지를 위해 출력이 %d줄에서 생략되었습니다)",
    ERR_NO_WAYPOINT    = "최근 AI 답변에 포함된 지도 좌표가 없습니다.",
    ERR_BAD_COORDS     = "좌표(%.1f, %.1f)가 유효 범위(0~100)를 벗어났습니다.",
    ERR_WAYPOINT_UNSUP = "안내 좌표: |cffFFD100%s|r (%.1f, %.1f) [현재 던전/지역은 순정 핀 미지원]",
    MSG_WAYPOINT_SET   = "📍 지도 핀 설정 완료: |cffFFD100%s|r (%.1f, %.1f) %s",
    ERR_NO_CODE        = "최근 AI 답변에 첨부된 Lua 코드 스니펫이 없습니다.",
    ERR_NO_MACRO       = "최근 AI 답변에 첨부된 매크로 본문이 없습니다.",
    ERR_MACRO_EMPTY    = "매크로 본문이 비어 있습니다.",
    ERR_MACRO_FULL     = "|cffEA4335공용 매크로 슬롯(120개)이 가득 찼습니다.|r 사용하지 않는 매크로를 먼저 정리해 주세요.",
    ERR_MACRO_NO_UNDO  = "되돌릴 최근 매크로 생성/수정 내역이 없습니다.",
    ERR_NO_SHARE_MSG   = "채팅에 공유할 최근 AI 답변이 없습니다.",
    ERR_SHARE_COOLDOWN = "도배 방지를 위해 %.1f초 후에 다시 공유할 수 있습니다.",
    ERR_CLIP_EMPTY     = "붙여넣기 입력창이 비어 있습니다. 먼저 Ctrl+V (Cmd+V)로 내용을 붙여넣어 주세요.",

    WELCOME_BODY = table.concat({
        "|cff4285F4[Antigravity]|r 안녕하세요! **와우 포에버 실시간 질문(Q&A) 백과사전 & 코딩 스튜디오**입니다.",
        "",
        "• |cffFFD100와우 무엇이든 질문하기|r: 퀘스트 길찾기, 보스 공략, 드랍템, 육성 빌드를 물어보세요! (몬스터 타겟팅 또는 아이템·스킬 |cffFBBC05Shift+클릭 / 드래그|r 첨부 지원)",
        "• |cff34A853리로드 없이 바로 답변 보기|r: [클립보드 질문 복사] → 알림 후 [클립보드 답변 붙여넣기]를 누르면 `/reload` 없이 대화창에 답변이 바로 표시됩니다!",
        "• |cff4285F4애드온 & Live Lua 코딩|r: 원하는 UI 애드온 제작 지시 및 실시간 Lua 코드 실행을 지원합니다.",
    }, "\n"),

    PROMPT_TARGET_WITH_NAME = "지금 내가 타겟팅한 '%s' 몬스터/NPC의 주요 특징, 주의할 패턴(공략), 주요 드랍 아이템이나 관련 퀘스트를 알려줘!",
    PROMPT_TARGET_NONE      = "현재 내 지역에서 주의해야 할 희귀 몬스터나 주요 파밍 포인트를 알려줘!",
    PROMPT_QUEST_ASK        = "내 현재 진행 중인 퀘스트 목록과 목표를 보고, 가장 효율적인 동선과 목표 위치(좌표)를 알려줘!",
    PROMPT_BUILD_ASK        = "와우 포에버 기준으로 내 현재 직업, 레벨, 착용 장비, 전문기술 상태에서 추천하는 특성/스킬 운영법과 업그레이드 장비를 추천해줘!",
    PROMPT_REFACTOR         = "아래 WoW Forever (16001) Lua 코드를 검토해서 개선하거나 독립 애드온 파일로 만들어줘:\n```lua\n%s\n```",
    PROMPT_FIX_ERR          = "인게임에서 [%s] 애드온 관련 Lua 에러가 발생했어. WoW Forever (Interface: 16001) API 규격에 맞게 원인을 찾고 수정해줘:\n에러: %s\n스택:\n%s",
}

-- 3. Japanese (jaJP: selectable manually via UI button or `/agy lang jaJP`; CJK font addon recommended on enUS client)
LOCALES.jaJP = {
    APP_SUBTITLE = "(WoW Forever)",
    TAB_1 = "1. 質問(Q&A) & 開発",
    TAB_2 = "2. Live Lua エディタ",
    TAB_3 = "3. エラーデバッガ",
    TAB_4 = "4. スニペット & ツール",
    STATUS_BAR = "TOC: |cff34A85316001|r  |  待機中: |cffFBBC05%d件|r  |  エラー: |cffEA4335%d件|r",
    ROLE_USER = "|cffFBBC05[自分]|r ",
    BTN_WAYPOINT = "📍 マップピン",
    BTN_RUN_REPLY = "▶ コード実行",
    BTN_TO_EDITOR = "エディタへ",
    BTN_MAKE_MACRO = "マクロ作成",
    BTN_SHARE = "共有 / コピー",
    BTN_PASTE_CLIP = "回答/コードを貼り付け",
    MODE_AUTO = "モード: |cffFBBC05自動 (Q&A+開発)|r",
    MODE_QA   = "モード: |cff34A853WoW 攻略 Q&A|r",
    MODE_CODE = "モード: |cff4285F4Lua コーディング|r",
    PRESET_TARGET = "🎯 ターゲット攻略・ドロップ質問",
    PRESET_QUEST  = "📜 進行中クエストのルート案内",
    PRESET_BUILD  = "⚔️ クラス・装備育成アドバイス",
    OPT_ATTACH_CTX   = "キャラ・装備・ターゲット・クエスト添付",
    OPT_ATTACH_ERR   = "Luaエラー添付",
    OPT_ATTACH_MOUSE = "マウスオーバーUI添付",
    BTN_SEND_RELOAD = "送信 / 同期 (/reload)",
    BTN_QUEUE_ONLY  = "キューに追加のみ",
    BTN_COPY_CLIP   = "クリップボード要求コピー(リロード不要)",
    BTN_CLEAR_CHAT  = "クリア",
    BTN_SHOW_IN_CHAT = "チャットに回答を表示 (リロード不要)",
    BTN_CLOSE = "閉じる",
    MSG_READY = "準備完了！ |cffFBBC05/agy|r または |cff34A853/wowask <質問>|r を入力してください。",
    ERR_EMPTY_LUA = "実行するLuaコードが空です。",
    ERR_NO_WAYPOINT = "最新の回答にマップ座標が含まれていません。",
    ERR_NO_CODE = "最新の回答にLuaスニペットが含まれていません。",
    ERR_NO_MACRO = "最新の回答にマクロが含まれていません。",
    ERR_CLIP_EMPTY = "入力欄が空です。先に Ctrl+V (Cmd+V) で貼り付けてください。",
    WELCOME_BODY = table.concat({
        "|cff4285F4[Antigravity]|r **WoW Forever AI 攻略ガイド & コーディングスタジオ**へようこそ！",
        "• |cffFFD100WoWの疑問を何でも質問|r: クエスト手順、ボス攻略、ドロップ品、ビルドを質問できます（アイテムShift+クリック対応）。",
        "• |cff34A853リロード不要モード|r: [クリップボード要求コピー] → 通知後に[回答/コードを貼り付け]ですぐ確認可能！",
        "• |cff9aa0a6(※英語クライアントで日本語を表示する場合は日本語フォントアドオンの導入を推奨します)|r",
    }, "\n"),
    PROMPT_TARGET_WITH_NAME = "現在ターゲット中の『%s』の攻略法・注意点・主なドロップアイテムや関連クエストを日本語で教えて！",
    PROMPT_TARGET_NONE      = "現在のゾーンで注目すべきレアモブや効率的なファーミング場所を日本語で教えて！",
    PROMPT_QUEST_ASK        = "現在進行中のクエストと目標を見て、最も効率的なルートと座標を日本語で教えて！",
    PROMPT_BUILD_ASK        = "WoW Forever基準で、現在のクラス・レベル・装備・専門スキルに最適なビルドとおすすめ装備を教えて！",
}

-- 4. Simplified Chinese (zhCN)
LOCALES.zhCN = {
    APP_SUBTITLE = "(魔兽世界：永恒)",
    TAB_1 = "1. 游戏问答 & 编程",
    TAB_2 = "2. 实时 Lua 编辑器",
    TAB_3 = "3. Lua 报错调试",
    TAB_4 = "4. 代码片段 & 官方工具",
    STATUS_BAR = "TOC: |cff34A85316001|r  |  待处理: |cffFBBC05%d|r  |  报错: |cffEA4335%d|r",
    ROLE_USER = "|cffFBBC05[我]|r ",
    BTN_WAYPOINT = "📍 地图标记",
    BTN_RUN_REPLY = "▶ 运行代码",
    BTN_TO_EDITOR = "打开编辑器",
    BTN_MAKE_MACRO = "生成宏",
    BTN_SHARE = "分享 / 复制",
    BTN_PASTE_CLIP = "粘贴剪贴板回答/代码",
    MODE_AUTO = "模式: |cffFBBC05自动 (问答+编程)|r",
    MODE_QA   = "模式: |cff34A853魔兽攻略问答|r",
    MODE_CODE = "模式: |cff4285F4Lua 插件编程|r",
    PRESET_TARGET = "🎯 询问当前目标攻略与掉落",
    PRESET_QUEST  = "📜 当前任务路线指引",
    PRESET_BUILD  = "⚔️ 职业天赋与配装建议",
    OPT_ATTACH_CTX   = "附带角色·装备·目标·任务状态",
    OPT_ATTACH_ERR   = "附带 Lua 报错",
    OPT_ATTACH_MOUSE = "附带鼠标悬停框体",
    BTN_SEND_RELOAD = "发送并同步 (/reload)",
    BTN_QUEUE_ONLY  = "仅加入队列",
    BTN_COPY_CLIP   = "复制请求包 (免重载)",
    BTN_CLEAR_CHAT  = "清空",
    BTN_SHOW_IN_CHAT = "在窗口显示回答 (免重载)",
    BTN_CLOSE = "关闭",
    MSG_READY = "就绪！输入 |cffFBBC05/agy|r 打开工作室，或输入 |cff34A853/wowask <问题>|r 随时提问。",
    ERR_EMPTY_LUA = "要执行的 Lua 代码为空。",
    ERR_NO_WAYPOINT = "最新回答中未包含地图坐标。",
    ERR_NO_CODE = "最新回答中未附带 Lua 代码片段。",
    ERR_NO_MACRO = "最新回答中未附带宏内容。",
    ERR_CLIP_EMPTY = "粘贴框为空，请先按 Ctrl+V (Cmd+V) 粘贴内容。",
    WELCOME_BODY = table.concat({
        "|cff4285F4[Antigravity]|r 欢迎使用 **WoW Forever AI 攻略百科 & 插件编程工作室**！",
        "• |cffFFD100随时提问魔兽攻略|r：任务路线、BOSS机制、掉落装备、天赋配装（支持 Shift+点击 或拖拽物品/技能）。",
        "• |cff34A853免 /reload 剪贴板模式|r：点击[复制请求包] -> 收到桌面通知后点击[粘贴剪贴板回答]即可查看并一键标记地图坐标！",
    }, "\n"),
    PROMPT_TARGET_WITH_NAME = "请告诉我当前目标“%s”的机制打法、注意事项、主要掉落物品及相关任务！",
    PROMPT_TARGET_NONE      = "请告诉我当前区域值得注意的稀有精英或高效刷怪/采集点！",
    PROMPT_QUEST_ASK        = "根据我当前的任务列表与进度，请告诉我最高效的路线与目标坐标！",
    PROMPT_BUILD_ASK        = "在 WoW Forever 中，结合我当前的职业、等级、已穿戴装备和专业技能，推荐什么天赋手法与装备提升路线？",
}

-- 5. Traditional Chinese (zhTW)
LOCALES.zhTW = {
    APP_SUBTITLE = "(魔獸世界：永恆)",
    TAB_1 = "1. 遊戲問答 & 編程",
    TAB_2 = "2. 即時 Lua 編輯器",
    TAB_3 = "3. Lua 錯誤除錯",
    TAB_4 = "4. 程式碼片段 & 工具",
    STATUS_BAR = "TOC: |cff34A85316001|r  |  待處理: |cffFBBC05%d|r  |  錯誤: |cffEA4335%d|r",
    ROLE_USER = "|cffFBBC05[我]|r ",
    BTN_WAYPOINT = "📍 地圖標記",
    BTN_RUN_REPLY = "▶ 執行程式",
    BTN_TO_EDITOR = "開啟編輯器",
    BTN_MAKE_MACRO = "建立巨集",
    BTN_SHARE = "分享 / 複製",
    BTN_PASTE_CLIP = "貼上剪貼簿回答/程式",
    MODE_AUTO = "模式: |cffFBBC05自動 (問答+編程)|r",
    MODE_QA   = "模式: |cff34A853魔獸攻略問答|r",
    MODE_CODE = "模式: |cff4285F4Lua 插件編程|r",
    PRESET_TARGET = "🎯 詢問當前目標攻略與掉落",
    PRESET_QUEST  = "📜 進行中任務路線指引",
    PRESET_BUILD  = "⚔️ 職業天賦與配裝建議",
    OPT_ATTACH_CTX   = "附帶角色·裝備·目標·任務狀態",
    OPT_ATTACH_ERR   = "附帶 Lua 錯誤",
    OPT_ATTACH_MOUSE = "附帶滑鼠懸停框架",
    BTN_SEND_RELOAD = "傳送並同步 (/reload)",
    BTN_QUEUE_ONLY  = "僅加入佇列",
    BTN_COPY_CLIP   = "複製請求封包 (免重載)",
    BTN_CLEAR_CHAT  = "清空",
    BTN_SHOW_IN_CHAT = "在視窗顯示回答 (免重載)",
    BTN_CLOSE = "關閉",
    MSG_READY = "準備就緒！輸入 |cffFBBC05/agy|r 開啟工作室，或輸入 |cff34A853/wowask <問題>|r 提問。",
    PROMPT_TARGET_WITH_NAME = "請告訴我當前目標「%s」的攻略機制、主要掉落物品與相關任務！",
    PROMPT_QUEST_ASK        = "根據我目前進行中的任務與進度，請告訴我最有效率的路線與座標！",
    PROMPT_BUILD_ASK        = "在 WoW Forever 中，根據我目前的職業、等級、裝備與專業技能，推薦什麼天賦與裝備升級方向？",
}

-- 6. German (deDE)
LOCALES.deDE = {
    TAB_1 = "1. Q&A & Coding",
    TAB_2 = "2. Live-Lua-Editor",
    TAB_3 = "3. Fehler-Debugger",
    TAB_4 = "4. Snippets & Tools",
    BTN_WAYPOINT = "📍 Kartenpin",
    BTN_RUN_REPLY = "▶ Ausführen",
    BTN_MAKE_MACRO = "Makro",
    BTN_SHARE = "Teilen/Kop.",
    BTN_PASTE_CLIP = "Antwort/Code einfügen",
    PRESET_TARGET = "🎯 Ziel-Taktik & Drops",
    PRESET_QUEST  = "📜 Quest-Route",
    PRESET_BUILD  = "⚔️ Klassen- & Gear-Tipps",
    BTN_SEND_RELOAD = "Senden / Sync (/reload)",
    BTN_COPY_CLIP   = "Anfrage kopieren (Ohne Reload)",
    MSG_READY = "Bereit! Tippe |cffFBBC05/agy|r oder |cff34A853/wowask <Frage>|r ein.",
    PROMPT_TARGET_WITH_NAME = "Erkläre mir Taktik, Fähigkeiten, Drops und Quests für mein aktuelles Ziel '%s' in WoW Forever!",
    PROMPT_QUEST_ASK        = "Was ist die beste Route und wo sind die Koordinaten für meine aktiven Quests?",
    PROMPT_BUILD_ASK        = "Welche Talente, Rotation und Ausrüstungs-Upgrades empfiehlst du für meine Klasse und Stufe in WoW Forever?",
}

-- 7. French (frFR)
LOCALES.frFR = {
    TAB_1 = "1. Q&R & Code",
    TAB_2 = "2. Éditeur Lua Live",
    TAB_3 = "3. Débogueur Lua",
    TAB_4 = "4. Snippets & Outils",
    BTN_WAYPOINT = "📍 Repère",
    BTN_RUN_REPLY = "▶ Exécuter",
    BTN_MAKE_MACRO = "Macro",
    BTN_SHARE = "Partager",
    BTN_PASTE_CLIP = "Coller Réponse / Code",
    PRESET_TARGET = "🎯 Infos & Butin Cible",
    PRESET_QUEST  = "📜 Guide de Quêtes",
    PRESET_BUILD  = "⚔️ Conseils Classe & Stuff",
    BTN_SEND_RELOAD = "Envoyer / Sync (/reload)",
    BTN_COPY_CLIP   = "Copier Requête (Sans Reload)",
    MSG_READY = "Prêt ! Tapez |cffFBBC05/agy|r ou |cff34A853/wowask <question>|r.",
    PROMPT_TARGET_WITH_NAME = "Donne-moi la stratégie, le butin principal et les quêtes liés à ma cible actuelle '%s' sur WoW Forever !",
    PROMPT_QUEST_ASK        = "Quel est l'itinéraire optimal et les coordonnées pour mes quêtes actives ?",
    PROMPT_BUILD_ASK        = "Quels talents et améliorations d'équipement conseilles-tu pour ma classe et mon niveau sur WoW Forever ?",
}

-- 8. Spanish - Europe (esES)
LOCALES.esES = {
    TAB_1 = "1. Preguntas y Código",
    TAB_2 = "2. Editor Lua en Vivo",
    TAB_3 = "3. Depurador Lua",
    TAB_4 = "4. Snippets y Herram.",
    BTN_WAYPOINT = "📍 Mapa Pin",
    BTN_RUN_REPLY = "▶ Ejecutar",
    BTN_MAKE_MACRO = "Macro",
    BTN_SHARE = "Compartir",
    BTN_PASTE_CLIP = "Pegar Respuesta / Código",
    PRESET_TARGET = "🎯 Guía y Botín del Objetivo",
    PRESET_QUEST  = "📜 Ruta de Misiones",
    PRESET_BUILD  = "⚔️ Consejos de Clase y Equipo",
    BTN_SEND_RELOAD = "Enviar / Sinc (/reload)",
    BTN_COPY_CLIP   = "Copiar Solicitud (Sin Reload)",
    MSG_READY = "¡Listo! Escribe |cffFBBC05/agy|r o |cff34A853/wowask <pregunta>|r.",
    PROMPT_TARGET_WITH_NAME = "¡Dime las mecánicas, el botín principal y las misiones de mi objetivo actual '%s' en WoW Forever!",
    PROMPT_QUEST_ASK        = "¿Cuál es la mejor ruta y coordenadas para mis misiones activas?",
    PROMPT_BUILD_ASK        = "¿Qué talentos y mejoras de equipo recomiendas para mi clase y nivel actual en WoW Forever?",
}

-- 9. Spanish - Latin America (esMX)
LOCALES.esMX = setmetatable({}, { __index = LOCALES.esES })

-- 10. Portuguese - Brazil / Portugal (ptBR)
LOCALES.ptBR = {
    TAB_1 = "1. Perguntas & Código",
    TAB_2 = "2. Editor Lua ao Vivo",
    TAB_3 = "3. Depurador de Erros",
    TAB_4 = "4. Snippets & Ferram.",
    BTN_WAYPOINT = "📍 Pin Mapa",
    BTN_RUN_REPLY = "▶ Executar",
    BTN_MAKE_MACRO = "Macro",
    BTN_SHARE = "Compartilhar",
    BTN_PASTE_CLIP = "Colar Resposta / Código",
    PRESET_TARGET = "🎯 Tática e Saque do Alvo",
    PRESET_QUEST  = "📜 Rota de Missões",
    PRESET_BUILD  = "⚔️ Dicas de Classe e Equip.",
    BTN_SEND_RELOAD = "Enviar / Sinc (/reload)",
    BTN_COPY_CLIP   = "Copiar Pedido (Sem Reload)",
    MSG_READY = "Pronto! Digite |cffFBBC05/agy|r ou |cff34A853/wowask <pergunta>|r.",
    PROMPT_TARGET_WITH_NAME = "Quais são as mecânicas, principais saques e missões do meu alvo atual '%s' no WoW Forever?",
    PROMPT_QUEST_ASK        = "Qual é a melhor rota e coordenadas para minhas missões ativas?",
    PROMPT_BUILD_ASK        = "Quais talentos e melhorias de equipamento você recomenda para minha classe e nível no WoW Forever?",
}

-- 11. Russian (ruRU)
LOCALES.ruRU = {
    TAB_1 = "1. Вопросы и Код",
    TAB_2 = "2. Live Lua Редактор",
    TAB_3 = "3. Отладчик Ошибок",
    TAB_4 = "4. Сниппеты и Инстр.",
    BTN_WAYPOINT = "📍 Метка",
    BTN_RUN_REPLY = "▶ Запуск",
    BTN_MAKE_MACRO = "Макрос",
    BTN_SHARE = "Поделиться",
    BTN_PASTE_CLIP = "Вставить ответ / код",
    PRESET_TARGET = "🎯 Тактика и дроп цели",
    PRESET_QUEST  = "📜 Маршрут квестов",
    PRESET_BUILD  = "⚔️ Советы по классу и экип.",
    BTN_SEND_RELOAD = "Отправить / Синх (/reload)",
    BTN_COPY_CLIP   = "Копировать запрос (без Reload)",
    MSG_READY = "Готово! Введите |cffFBBC05/agy|r или |cff34A853/wowask <вопрос>|r.",
    PROMPT_TARGET_WITH_NAME = "Расскажи о тактике, способностях, добыче и квестах для моей текущей цели '%s' в WoW Forever!",
    PROMPT_QUEST_ASK        = "Какой самый оптимальный маршрут и координаты для моих текущих заданий?",
    PROMPT_BUILD_ASK        = "Какие таланты и улучшения экипировки ты рекомендуешь для моего класса и уровня в WoW Forever?",
}

-- 12. Italian (itIT)
LOCALES.itIT = {
    TAB_1 = "1. Domande & Codice",
    TAB_2 = "2. Editor Lua Live",
    TAB_3 = "3. Debug Errori Lua",
    TAB_4 = "4. Snippet & Strumenti",
    BTN_WAYPOINT = "📍 Segnaposto",
    BTN_RUN_REPLY = "▶ Esegui",
    BTN_MAKE_MACRO = "Macro",
    BTN_SHARE = "Condividi",
    BTN_PASTE_CLIP = "Incolla Risposta / Codice",
    PRESET_TARGET = "🎯 Strategia e Bottino Bersaglio",
    PRESET_QUEST  = "📜 Percorso Missioni",
    PRESET_BUILD  = "⚔️ Consigli Classe ed Equip.",
    BTN_SEND_RELOAD = "Invia / Sinc (/reload)",
    BTN_COPY_CLIP   = "Copia Richiesta (Senza Reload)",
    MSG_READY = "Pronto! Digita |cffFBBC05/agy|r o |cff34A853/wowask <domanda>|r.",
    PROMPT_TARGET_WITH_NAME = "Quali sono la strategia, il bottino principale e le missioni del mio bersaglio attuale '%s' in WoW Forever?",
    PROMPT_QUEST_ASK        = "Qual è il percorso migliore e le coordinate per le mie missioni attive?",
    PROMPT_BUILD_ASK        = "Quali talenti e miglioramenti d'equipaggiamento consigli per la mia classe e livello in WoW Forever?",
}

ns.LOCALES = LOCALES

local function NormalizeClientLocale(rawLoc)
    local loc = tostring(rawLoc or "enUS")
    if loc == "enGB" or loc == "enEU" then
        return "enUS"
    elseif loc == "ptPT" then
        return "ptBR"
    end
    if LOCALES[loc] then
        return loc
    end
    return "enUS"
end

function ns:GetEffectiveLocale()
    local pref = self.db and self.db.settings and self.db.settings.locale
    if pref and pref ~= "auto" and LOCALES[pref] then
        return pref
    end
    local clientLoc = GetLocale and GetLocale() or "enUS"
    return NormalizeClientLocale(clientLoc)
end

function ns:GetLocaleDisplayLabel()
    local pref = (self.db and self.db.settings and self.db.settings.locale) or "auto"
    local eff = self:GetEffectiveLocale()
    if pref == "auto" then
        return "🌐 Auto (" .. (self.LOCALE_LABELS[eff] or eff) .. ")"
    end
    return "🌐 " .. (self.LOCALE_LABELS[pref] or pref)
end

function ns:CycleLocale()
    if not self.db or not self.db.settings then return "enUS" end
    local cur = self.db.settings.locale or "auto"
    local nextLoc = "auto"
    for idx, code in ipairs(self.LOCALE_ORDER) do
        if code == cur then
            nextLoc = self.LOCALE_ORDER[(idx % #self.LOCALE_ORDER) + 1]
            break
        end
    end
    self.db.settings.locale = nextLoc
    self:ApplyBindingTranslations()
    if self.RebuildUIForLocale then
        self:RebuildUIForLocale()
    end
    local eff = self:GetEffectiveLocale()
    self:Print(string.format(self.L.MSG_LANG_CHANGED, self.LOCALE_LABELS[nextLoc] or nextLoc, eff))
    return eff
end

function ns:SetPreferredLocale(code)
    if not self.db or not self.db.settings then return false end
    local target = tostring(code or "auto")
    if target:lower() == "auto" then
        target = "auto"
    else
        -- Case-insensitive match against supported codes (e.g., jajp -> jaJP, kokr -> koKR)
        local matched = nil
        for _, valid in ipairs(self.LOCALE_ORDER) do
            if valid:lower() == target:lower() then
                matched = valid
                break
            end
        end
        if not matched then
            return false
        end
        target = matched
    end
    self.db.settings.locale = target
    self:ApplyBindingTranslations()
    if self.RebuildUIForLocale then
        self:RebuildUIForLocale()
    end
    local eff = self:GetEffectiveLocale()
    self:Print(string.format(self.L.MSG_LANG_CHANGED, self.LOCALE_LABELS[target] or target, eff))
    return true
end

-- Dynamic lookup proxy with guaranteed English (`enUS`) default fallback
ns.L = setmetatable({}, {
    __index = function(_, key)
        local eff = ns:GetEffectiveLocale()
        local tbl = LOCALES[eff]
        if tbl and tbl[key] ~= nil then
            return tbl[key]
        end
        if LOCALES.enUS[key] ~= nil then
            return LOCALES.enUS[key]
        end
        return tostring(key)
    end,
})

function ns:ApplyBindingTranslations()
    BINDING_HEADER_WOWAGY = self.L.BINDING_HEADER
    BINDING_NAME_WOWAGY_TOGGLE = self.L.BINDING_TOGGLE
    BINDING_NAME_WOWAGY_ASK_TARGET = self.L.BINDING_TARGET
    BINDING_NAME_WOWAGY_LIVE_LUA = self.L.BINDING_LUA
end

ns:ApplyBindingTranslations()
