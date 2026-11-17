# Antigravity AI 가이드 & 코딩 스튜디오 — WoW Forever (`Interface: 16001`)

🌐 **언어 선택**: [English](../README.md) | **한국어** | [日本語](README.ja.md) | [简体中文](README.zh-CN.md)

**월드 오브 워크래프트: 포에버(World of Warcraft: Forever)** 인게임에서 알트탭 없이 **Google Antigravity (`google-antigravity` SDK / `agy` CLI)** 에게 **퀘스트·보스 공략·아이템 비교 질문(Q&A)** 도 하고, **Lua 애드온 바이브 코딩·실시간 테스트·에러 디버깅**까지 수행할 수 있는 올인원 애드온 & 로컬 브릿지입니다.

---

## 블리자드 공식 UI 애드온 개발 정책 준수 안내

본 프로젝트는 **블리자드 엔터테인먼트의 공식 UI 애드온 개발 정책(UI Add-On Development Policy)** 및 이용 약관(EULA)을 엄격히 준수합니다:

- **100% 무료 오픈소스 ([MIT License](../LICENSE))**: 유료 결제, 구독 잠금, 인게임 광고 및 후원 유도 문구가 일절 없습니다.
- **100% 평문 Lua/XML 공개 코드**: 코드 난독화·암호화 및 외부 바이너리(`.dll`/`.so`)를 사용하지 않습니다.
- **화면 픽셀 스캔 / 메모리 변조 / 키 입력 조작 없음**: 화면 캡처 바코드나 사운드/더미 슬롯 우회 트릭을 쓰지 않으며, 와우 표준 **`SavedVariables` 파일 동기화**와 WeakAuras/SimC 방식의 **사용자 직접 복사·붙여넣기(`EditBox` `Ctrl+C`/`V`)** 만 사용합니다.
- **전투 자동화(봇) 금지 및 보안 준수**: 자동 이동·타겟팅·스킬 시전을 수행하지 않으며, 모든 보호 동작은 `InCombatLockdown()` 및 포에버 `C_Secrets` 규격을 준수합니다.
- **안전한 매크로 백업 및 되돌리기**: `/run` 이 포함된 매크로는 사전 안내를 표시하며, `/agy undo` 명령어로 직전 매크로 생성·수정을 즉시 되돌릴 수 있습니다.

---

## 핵심 기능

1. **인게임 와우 AI 공략 백과사전 (Q&A)**
   - `/와우질문 <질문>` (또는 `/wowask <질문>`) 슬래시 명령어 및 원클릭 질문 프리셋 3종 지원
   - 캐릭터 레벨·직업, 좌표, **착용 장비(1~18번 슬롯)**, **전문기술 숙련도**, **현재 타겟(이름·NPC ID)**, **진행 중인 퀘스트 목표** 자동 첨부
   - **공식 `C_TooltipInfo` 툴팁 스탯 자동 추출**: 가방 아이템이나 주문을 **`Shift+클릭` 또는 마우스 드래그 앤 드롭**하면 실제 인게임 툴팁 능력치 줄을 추출해 정확한 장비 비교 제공
   - **원클릭 지도 핀(`📍 좌표 핀`) & 파티 3줄 공유(`답변 공유/복사`)**: 답변 좌표를 순정 지도 핀(`UiMapPoint`)과 화살표로 표시하고 파티/공대 채팅으로 도배 없이 공유 (5초 쿨타임 적용)

2. **4탭 인게임 Lua 코딩 IDE 스튜디오**
   - **탭 1 (`질문 & 코딩`)**: 대화 로그 확인, 응답 스니펫 즉시 실행, 매크로 생성
   - **탭 2 (`Live Lua 에디터`)**: 리로드 없이 `loadstring` 즉시 실행(`Ctrl+Enter`) 및 `print()` 콘솔 확인
   - **탭 3 (`에러 디버거`)**: 런타임 Lua 에러 스택 트레이스 자동 수집 및 원클릭 AI 수정 요청
   - **탭 4 (`스니펫 & 공식 툴`)**: 스니펫 보관함 + `/api`, `/fstack`, `/etrace` 바로가기

3. **글로벌 12개 언어 실시간 전환 (기본 영어 `enUS` 폴백)**
   - 우측 상단 **`[🌐 Auto (...)]`** 버튼 또는 `/agy lang <코드>`(`koKR`, `enUS`, `jaJP`, `zhCN`, `zhTW`, `deDE`, `frFR`, `esES`, `esMX`, `ptBR`, `ruRU`, `itIT`)로 `/reload` 없이 즉시 전환

---

## 설치 및 실행 방법

### 1단계: 애드온 설치

**macOS / Linux:**
```bash
chmod +x ./scripts/install.sh
./scripts/install.sh "/Applications/World of Warcraft/_forever_"
```

**Windows (PowerShell):**
```powershell
.\scripts\install.ps1 "C:\Program Files (x86)\World of Warcraft\_forever_"
```

### 2단계: 로컬 브릿지 데몬 실행

```bash
# 1) 기본 실행 (설치된 agy CLI 자동 감지 — API 키 설정 불필요)
python3 bridge/daemon.py --wow-dir "/Applications/World of Warcraft/_forever_"

# 2) Google Antigravity Python SDK (클라우드 Gemini)
pip install -r requirements.txt
export GEMINI_API_KEY="발급받은_키"  # https://aistudio.google.com/app/api-keys
python3 bridge/daemon.py --backend sdk --wow-dir "/Applications/World of Warcraft/_forever_"

# 3) Google Antigravity SDK 온디바이스 / 로컬 서버 (API 키 불필요)
python3 bridge/daemon.py --backend sdk --litert-model ~/.litert-lm/models/gemma4-26b/model.litertlm
python3 bridge/daemon.py --backend sdk --local-openai-url http://localhost:11434/v1 --local-model gemma4:26b
```

---

## 인게임 사용법 요약

- **리로드 없는 빠른 질문/코드 실행 (클립보드 모드)**:
  1. `/agy` 창에서 질문 입력 후 **`Ctrl+Enter`** (또는 `[클립보드 질문/요청 복사]`) → `Cmd+C` / `Ctrl+C`
  2. 데스크톱 완료 알림이 뜨면 `[클립보드 답변/코드 붙여넣기]` → `Cmd+V` / `Ctrl+V` → **`[대화창에 답변 표시]`** 클릭!
- **실제 애드온 파일 생성·수정 (`/reload` 동기화 모드)**:
  1. 코딩/디버깅 지시 입력 후 **`[전송 / 답변 동기화 (/reload)]`** (`Alt+Enter`) 클릭
  2. 작업 완료 알림 후 한 번 더 `/reload` (`Shift+클릭` 미니맵 아이콘) 하면 수정된 애드온과 답변이 반영됩니다.

---

## 주요 명령어

| 명령어 | 설명 |
| :--- | :--- |
| `/agy` | 메인 스튜디오 창 열기/닫기 |
| `/와우질문 <질문>` / `/wowask <질문>` | 와우 공략·퀘스트·아이템 빠른 질문 |
| `/agy lang <코드\|auto>` | 표시 언어 및 AI 답변 언어 즉시 변경 |
| `/agy lua` / `/agy errors` | Live Lua 에디터 / 에러 디버거 탭 열기 |
| `/agy undo` | 방금 생성하거나 덮어쓴 매크로를 이전 상태로 복구 |
| `/agy sync` | 전투 외 상태에서 안전하게 `/reload` 실행 |
