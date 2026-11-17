# Antigravity AI Guide & Code Studio for WoW Forever (`Interface: 16001`)

**월드 오브 워크래프트: 포에버(World of Warcraft: Forever)** 게임 안에서 알트탭 없이 **Google Antigravity (`agy` CLI / Antigravity SDK)** 에게 **와우 공략·퀘스트·아이템 질문(Q&A)** 도 하고, **나만의 Lua 애드온 바이브 코딩·실시간 실행·에러 디버깅**까지 할 수 있는 올인원 애드온 & 로컬 브릿지 풀세트입니다.

- **포에버 최신 규격 완벽 대응**: `## Interface: 16001` 매니페스트 및 최신 리테일/Midnight 기반 `C_*` 네임스페이스(`C_Spell`, `C_Item`, `C_UnitAuras`, `C_Map`, `Settings`) 100% 준수
- **글로벌 12개 언어 다국어 지원 (기본 영어 `enUS`)**: 와우가 공식 서비스되는 모든 클라이언트 로케일(`enUS`/`enGB`, `koKR`, `zhCN`, `zhTW`, `deDE`, `frFR`, `esES`, `esMX`, `ptBR`/`ptPT`, `ruRU`, `itIT`) 자동 감지 **+** 일본어(`jaJP`) 수동 전환 지원
- **블리자드 공식 UI 애드온 개발 정책 준수**: 순수 평문 Lua/XML 구성, 메모리 변조·봇·전투 자동화 없음, `InCombatLockdown()` 보호 규칙 적용

---

## 주요 기능 한눈에 보기

### 1. 인게임 와우 AI 공략 백과사전 (Q&A 모드)
- **빠른 질문 명령어**: 채팅창에 `/와우질문 <궁금한 점>` 또는 `/wowask <질문>` 입력
- **자동 컨텍스트 인식**: 내 캐릭터(레벨·직업·종족), 현재 지역/좌표, **착용 장비(1~18번 슬롯)**, **전문기술 숙련도**, **현재 타겟 몬스터/NPC(이름·레벨·NPC ID)**, **진행 중인 퀘스트 세부 목표**를 자동 첨부해 내 상황에 딱 맞는 답변 제공
- **아이템·스킬 비교**: 가방의 장비나 스킬북, 퀘스트를 **`Shift+클릭`** 하거나 입력창에 **마우스로 드래그 앤 드롭**하여 첨부 가능
- **원클릭 지도 핀(`📍 좌표 핀`) & 파티 공유(`답변 공유/복사`)**: 답변에 포함된 좌표를 와우 순정 지도 핀(`UiMapPoint`)과 화면 상단 화살표(`C_SuperTrack`)로 즉시 표시하고, 던전/레이드 중 파티·공대 채팅으로 3줄 핵심 요약을 공유

### 2. 인게임 Antigravity 코딩 스튜디오 (Coding 모드)
- **로컬 애드온 직접 생성·수정**: 자연어로 지시하면 로컬 Antigravity 에이전트가 `Interface/AddOns/` 폴더 안에 실제 `.toc`/`.lua` 파일을 생성하거나 수정
- **Live Lua 에디터 (`2번 탭`)**: `/reload` 없이 인게임에서 Lua 코드를 작성하고 **`Ctrl+Enter`** 또는 **`[▶ 즉시 실행]`** 으로 실행 결과(`print()` 출력 및 소요 시간 `ms`)를 즉시 확인
- **실시간 Lua 에러 디버거 (`3번 탭`)**: 다른 애드온에서 발생한 런타임 Lua 에러와 스택 트레이스를 자동 캡처하고, 버튼 하나로 Antigravity에게 원인 분석 및 코드 수정을 요청
- **원클릭 매크로 생성**: AI가 만들어준 매크로나 작성한 Lua 코드를 클릭 한 번으로 공용 매크로 슬롯에 등록하고 마우스 커서에 집어 액션바에 바로 배치

---

## 사전 준비 사항 (Prerequisites)

1. **월드 오브 워크래프트: 포에버 (WoW Forever)** 클라이언트 설치
2. **Python 3.10 이상** (`macOS` / `Windows` 지원, 별도 외부 패키지 설치 불필요)
3. **Google Antigravity CLI (`agy`)** 로그인 완료 상태  
   *(또는 `pip install google-antigravity` + `GEMINI_API_KEY` 환경변수로 SDK 모드 사용 가능)*

---

## 설치 방법 (Step-by-Step)

### 1단계: 저장소 클론
```bash
git clone https://github.com/JAICHANGPARK/wow-addon-agy.git
cd wow-addon-agy
```

### 2단계: 와우 포에버 `AddOns` 폴더에 애드온 설치

#### macOS / Linux (자동 경로 탐색 또는 직접 지정)
```bash
chmod +x ./scripts/install.sh
./scripts/install.sh "/Applications/World of Warcraft/_forever_"
```
> **참고**: macOS에서는 심볼릭 링크로 연결되므로 브릿지 데몬이 응답 파일(`Inbox.lua`)을 갱신하면 별도 복사 없이 게임에 바로 반영됩니다.

#### Windows (PowerShell)
```powershell
.\scripts\install.ps1 "C:\Program Files (x86)\World of Warcraft\_forever_"
```

#### 수동으로 설치하고 싶다면?
1. `AddOn/AntigravityWoW` 폴더를 와우 포에버 설치 경로의 `_forever_/Interface/AddOns/AntigravityWoW` 로 복사(또는 심볼릭 링크)합니다.
2. `AGENTS.md` 파일을 `_forever_/Interface/AddOns/AGENTS.md` 로 복사합니다.

---

## 실행 및 사용 방법

와우 클라이언트는 보안상 외부 인터넷이나 터미널을 직접 호출할 수 없으므로, 게임을 켜기 전(또는 켠 상태)에 PC에서 **가벼운 브릿지 데몬(`bridge/daemon.py`)** 을 함께 실행합니다.

### 1. 백그라운드 브릿지 데몬 실행
```bash
python3 bridge/daemon.py --wow-dir "/Applications/World of Warcraft/_forever_"
```
*(설치된 `agy` CLI를 자동 감지해 별도 API 키 설정 없이 바로 대기 상태로 진입합니다.)*

<details>
<summary><b>선택 옵션: Google Antigravity Python SDK 모드로 실행하기</b></summary>

```bash
pip install google-antigravity
export GEMINI_API_KEY="발급받은_API_키"  # https://aistudio.google.com/app/api-keys
python3 bridge/daemon.py --backend sdk --wow-dir "/Applications/World of Warcraft/_forever_"
```
</details>

<details>
<summary><b>선택 옵션: Antigravity CLI / IDE에 WoW Forever MCP 서버 등록하기</b></summary>

터미널의 `agy`나 Antigravity IDE 안에서 인게임 상태·에러 로그를 조회하고 싶다면 아래 명령으로 MCP 서버를 등록하세요:
```bash
agy mcp add wow-forever -- env WOW_FOREVER_DIR="/Applications/World of Warcraft/_forever_" python3 "$(pwd)/bridge/mcp_server.py"
```
</details>

---

### 2. 인게임 사용 시나리오 2가지

게임에 접속한 뒤 미니맵의 **`AGY` 아이콘**을 클릭하거나 채팅창에 **`/agy`** 를 입력해 창을 엽니다.

#### 방법 A: 리로드(`/reload`) 없이 즉시 질문하고 답변 보기 (추천! 클립보드 브릿지)
던전이나 필드 사냥 중 화면 로딩 없이 바로 답을 얻거나 스니펫을 실행할 때 가장 빠릅니다:
1. `/agy` 창을 열고 질문을 입력합니다 (또는 **`[🎯 현재 타겟 공략·드랍 질문]`** 클릭, 아이템 **`Shift+클릭` / 드래그**).
2. 입력창에서 **`Ctrl+Enter`** 를 누르거나 하단 **`[클립보드 질문/요청 복사 (무-리로드)]`** 클릭 → **`Cmd+C` (Windows는 `Ctrl+C`)** 로 복사합니다.
3. 백그라운드 `daemon.py`가 자동으로 감지해 Antigravity를 실행하고, 완료되면 **데스크톱 알림**과 함께 답변을 클립보드에 자동 넣어줍니다.
4. 게임 창에서 **`[클립보드 답변/코드 붙여넣기]`** 클릭 → **`Cmd+V` (`Ctrl+V`)** → **`[대화창에 답변 표시]`** (또는 **`[▶ Lua 코드 즉시 실행]`**) 를 누르면 로딩 없이 즉시 결과가 반영됩니다!
   - 답변에 좌표가 있다면 **`[📍 좌표 핀]`** 버튼을 눌러 지도에 핀과 화살표를 띄우세요.

#### 방법 B: 실제 애드온 파일(`.lua`/`.toc`) 자동 생성·수정하기 (`SavedVariables` 동기화)
새 애드온을 통째로 만들거나 기존 애드온의 에러를 고칠 때 사용합니다:
1. `/agy` 창(또는 `3. 에러 디버거` 탭의 **`[선택한 에러 자동 수정 요청]`**)에 요청을 적고 **`[전송 / 답변 동기화 (/reload)]`** (단축키 **`Alt+Enter`**) 를 누릅니다.
2. UI가 리로드되면서 와우가 요청을 디스크(`SavedVariables`)로 내보내고, 로컬 `daemon.py`가 즉시 작업을 시작합니다.
3. 잠시 후 **데스크톱 완료 알림**이 뜨면 한 번 더 `/reload` (또는 미니맵 `AGY` 버튼 **`Shift+클릭`**) 를 실행해 수정된 애드온과 `Inbox.lua` 답변을 게임으로 불러옵니다.

---

## 인게임 명령어 & 단축키 안내

### 슬래시 명령어
| 명령어 | 설명 |
| :--- | :--- |
| `/agy` 또는 `/antigravity` | Antigravity AI 가이드 & 코딩 스튜디오 메인 창 열기/닫기 |
| `/와우질문 <질문>` 또는 `/wowask <질문>` | 와우 공략·퀘스트·아이템·빌드 빠른 질문 등록 및 창 열기 |
| `/agy lang <코드\|auto>` | UI 및 AI 답변 언어 즉시 전환 (예: `/agy lang enUS`, `/agy lang koKR`, `/agy lang jaJP`, `/agy lang zhCN`) |
| `/agy lua` | `2. Live Lua 에디터` 탭 바로 열기 |
| `/agy errors` | `3. 에러 디버거` 탭 바로 열기 |
| `/agy run <Lua코드>` | 채팅창에서 한 줄 Lua 코드 즉시 실행 (예: `/agy run print(GetRealZoneText())`) |
| `/agy sync` | 전투 중이 아닐 때 안전하게 `/reload` 동기화 실행 |
| `/agy help` | 인게임 명령어 도움말 출력 |

### 키보드 단축키 & 공식 설정 메뉴
- **게임 단축키 지정**: `ESC → 설정 → 단축키 → 애드온` 의 **Antigravity AI 가이드 & 코딩 스튜디오** 항목에서 `창 열기/닫기`, `현재 타겟 즉시 질문`, `Live Lua 에디터 열기` 단축키 지정 가능
- **애드온 옵션 설정**: `ESC → 설정 → 애드온 → Antigravity AI` 에서 미니맵 버튼 숨김, 컨텍스트 첨부 옵션, 창 위치 초기화 지원
- **에디터 내 단축키**:
  - 질문 입력창 **`Ctrl+Enter`**: 무-리로드 클립보드 패킷 복사 창 열기
  - 질문 입력창 **`Alt+Enter`**: 큐 등록 및 즉시 `/reload` 전송
  - Live Lua 에디터 **`Ctrl+Enter`**: 작성한 Lua 코드 즉시 실행 (`Run`)
  - **`Tab`**: 에디터 내 공백 4칸 들여쓰기 삽입

---

## 다국어 지원 (Multilingual Support — 12 Languages)

기본 폴백(Default Fallback) 언어는 **영어(`enUS`)** 이며, 와우 클라이언트의 `GetLocale()` 값을 자동 감지하여 **블리자드가 공식 지원하는 전 지역 언어 + 일본어(`jaJP`)** 까지 UI와 AI 응답 언어가 자동 동기화됩니다.

창 우측 상단의 **`[🌐 Auto (...)]`** 버튼을 클릭하거나 `/agy lang <코드>` 명령어를 입력하면 `/reload` 없이 실시간으로 언어가 바뀝니다:

| 코드 | 언어 / 권역 | 클라이언트 자동 감지 (`GetLocale()`) | 지역별 AI 검색 레퍼런스 연동 |
| :--- | :--- | :---: | :--- |
| **`enUS` / `enGB`** | **English (Default Fallback)** | ✅ 공식 지원 | Wowhead, Warcraft Wiki |
| **`koKR`** | **한국어 (Korean)** | ✅ 공식 지원 | 와우 인벤(Inven), Wowhead |
| **`jaJP`** | **日本語 (Japanese)** | 수동 전환 (`/agy lang jaJP`) \* | Wowhead, 일본어 공략 위키 |
| **`zhCN`** | **简体中文 (중국어 간체)** | ✅ 공식 지원 | NGA, 178, Wowhead |
| **`zhTW`** | **繁體中文 (중국어 번체)** | ✅ 공식 지원 | 巴哈姆特(Bahamut), Wowhead |
| **`deDE`** | **Deutsch (독일어)** | ✅ 공식 지원 | de.wowhead.com, Buffed |
| **`frFR`** | **Français (프랑스어)** | ✅ 공식 지원 | fr.wowhead.com, JudgeHype |
| **`esES`** | **Español — España (유럽 스페인어)** | ✅ 공식 지원 | es.wowhead.com |
| **`esMX`** | **Español — América Latina (중남미 스페인어)** | ✅ 공식 지원 | es.wowhead.com |
| **`ptBR` / `ptPT`** | **Português (포르투갈어)** | ✅ 공식 지원 | pt.wowhead.com |
| **`ruRU`** | **Русский (러시아어)** | ✅ 공식 지원 | ru.wowhead.com, Noob-Club |
| **`itIT`** | **Italiano (이탈리아어)** | ✅ 공식 지원 | it.wowhead.com |

> **\* 참고 (일본어 `jaJP` 관련)**: 월드 오브 워크래프트는 블리자드 공식 `jaJP` 클라이언트가 존재하지 않아 영문(`enUS`) 클라이언트에서는 기본 폰트에 일본어 글리프가 없습니다. 영문 클라이언트에서 `jaJP` 모드를 사용할 때는 일본어 폰트 애드온(*NihongoPlus* 등)을 함께 활성화하는 것을 권장합니다.

---

## 프로젝트 구조

```text
wow-addon-agy/
├── AGENTS.md                        # WoW Forever (16001) 공식 API & Q&A 가이드 지침서
├── AddOn/
│   └── AntigravityWoW/              # 100% 순수 Lua/XML 인게임 애드온
│       ├── AntigravityWoW.toc       # ## Interface: 16001 + 다국어 Title/Notes 매니페스트
│       ├── Locales.lua              # 12개 언어 다국어 엔진 (기본 영어 enUS 폴백 + 실시간 전환)
│       ├── Bindings.xml             # ESC -> 단축키 설정 공식 바인딩 정의
│       ├── Core.lua                 # 초기화, 슬래시 명령어(/agy, /와우질문), Outbox/Inbox 동기화
│       ├── Inbox.lua                # 로컬 브릿지 -> 인게임 응답 수신 데이터 파일
│       ├── Context.lua              # 캐릭터/장비/전문기술/타겟/퀘스트 수집 & Shift+클릭·드래그 훅
│       ├── ErrorCatcher.lua         # 실시간 런타임 Lua 에러 체인 수집기
│       ├── Sandbox.lua              # Live Lua 실행기, 매크로 빌더, 지도 핀, 파티 공유, 클립보드 코덱
│       ├── UI.lua                   # 다크모드 4탭 인게임 질문 & 코딩 스튜디오 UI
│       ├── MinimapButton.lua        # 드래그 가능한 미니맵 런처 & 에러/대기 배지
│       └── Settings.lua             # ESC -> 설정 -> 애드온 공식 옵션 카테고리 등록
├── bridge/
│   ├── lua_serde.py                 # SavedVariables Lua 파서(한글 UTF-8 / \ddd 완벽 지원) & 시리얼라이저
│   ├── agy_runner.py                # 질문/코딩 자동 판별 + agy CLI & Antigravity SDK 듀얼 실행기
│   ├── daemon.py                    # SavedVariables + 무-리로드 클립보드 백그라운드 워처 데몬
│   └── mcp_server.py                # WoW Forever 전용 표준 MCP (JSON-RPC stdio) 서버
├── scripts/
│   ├── install.sh                   # macOS / Linux 원클릭 설치 스크립트
│   └── install.ps1                  # Windows PowerShell 설치 스크립트
└── tests/
    └── test_bridge_and_lua.py       # Lua 16001 규격 검증, 파서, 브릿지, MCP 통합 테스트
```

## 테스트 실행 방법

```bash
python3 -m unittest discover -s tests -v
```
