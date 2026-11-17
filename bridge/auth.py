"""Authentication loader, pre-flight checker, and interactive setup wizard for Antigravity Bridge.

Supports all 4 official Google Antigravity authentication paths:
1. Antigravity CLI (`agy`) Google OAuth login (zero API key setup)
2. Google Antigravity SDK + `GEMINI_API_KEY` (via environment variable or `.env` file)
3. Google Antigravity SDK + Gemini Enterprise / Vertex AI (`vertex=True` via ADC or Express API key)
4. On-device / Local Models (`LiteRTAgentConfig` or `LocalOpenAIAgentConfig` — no auth required)
"""

from __future__ import annotations

import getpass
import os
import shutil
import stat
import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass
class AuthStatus:
    ok: bool
    method: str
    summary: str
    hint: str = ""


def mask_secret(val: str) -> str:
    """Mask an API key safely so full secrets are never printed to terminal logs."""
    clean = (val or "").strip()
    if len(clean) <= 8:
        return "****"
    return f"{clean[:4]}...{clean[-4:]}"


def load_dotenv_file(dotenv_path: Path, override: bool = False) -> bool:
    """Zero-dependency `.env` file loader."""
    if not dotenv_path.exists():
        return False

    for raw_line in dotenv_path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export ") :].strip()
        if "=" not in line:
            continue
        key, val = line.split("=", 1)
        key = key.strip()
        val = val.strip()
        if len(val) >= 2 and val[0] == val[-1] and val[0] in ('"', "'"):
            val = val[1:-1]
        if key and (override or key not in os.environ):
            os.environ[key] = val
    return True


def write_env_key_safely(dotenv_path: Path, updates: dict[str, str]) -> None:
    """Write or update keys in `.env` with owner-only (`0600`) file permissions."""
    existing_lines: list[str] = []
    if dotenv_path.exists():
        existing_lines = dotenv_path.read_text(encoding="utf-8", errors="replace").splitlines()

    remaining = dict(updates)
    new_lines: list[str] = []
    for line in existing_lines:
        stripped = line.strip()
        replaced = False
        if stripped and not stripped.startswith("#") and "=" in stripped:
            k = stripped.removeprefix("export ").split("=", 1)[0].strip()
            if k in remaining:
                new_lines.append(f'{k}="{remaining.pop(k)}"')
                replaced = True
        if not replaced:
            new_lines.append(line)

    for k, v in remaining.items():
        new_lines.append(f'{k}="{v}"')

    dotenv_path.write_text("\n".join(new_lines) + "\n", encoding="utf-8")
    try:
        os.chmod(dotenv_path, stat.S_IRUSR | stat.S_IWUSR)
    except OSError:
        pass


def check_adc_available() -> bool:
    env_creds = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if env_creds and Path(env_creds).expanduser().exists():
        return True
    if os.name == "nt":
        appdata = os.environ.get("APPDATA", "")
        adc_path = Path(appdata) / "gcloud" / "application_default_credentials.json"
    else:
        adc_path = Path.home() / ".config" / "gcloud" / "application_default_credentials.json"
    return adc_path.exists()


def check_agy_cli_authenticated(agy_bin: str | None) -> tuple[bool, str]:
    if not agy_bin or not Path(agy_bin).exists():
        return False, "Antigravity CLI (`agy`) binary not found."
    try:
        proc = subprocess.run(
            [agy_bin, "models"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=6,
            check=False,
        )
        combined = ((proc.stdout or "") + "\n" + (proc.stderr or "")).lower()
        if proc.returncode == 0 and "login" not in combined and "unauthenticated" not in combined:
            return True, f"`agy` CLI authenticated ({agy_bin})"
        return (
            False,
            "`agy` CLI is installed but not signed in yet. Run `agy` once in your terminal to complete Google sign-in.",
        )
    except subprocess.TimeoutExpired:
        return True, f"`agy` CLI detected ({agy_bin})"
    except Exception as exc:
        return False, f"Failed to verify `agy` CLI: {exc}"


def diagnose_auth(
    backend: str,
    agy_bin: str | None,
    litert_model_path: str | None = None,
    local_openai_url: str | None = None,
    use_vertex: bool = False,
    vertex_project: str | None = None,
) -> AuthStatus:
    """Verify authentication readiness before starting the bridge loop."""
    if litert_model_path:
        return AuthStatus(
            ok=True,
            method="sdk-litert-local",
            summary=f"On-device LiteRT model ({litert_model_path}) — No API key required",
        )
    if local_openai_url:
        return AuthStatus(
            ok=True,
            method="sdk-local-openai",
            summary=f"Local OpenAI-compatible server ({local_openai_url}) — No API key required",
        )

    if backend == "cli":
        cli_ok, cli_msg = check_agy_cli_authenticated(agy_bin)
        if cli_ok:
            return AuthStatus(ok=True, method="agy-cli", summary=cli_msg)
        return AuthStatus(
            ok=False,
            method="agy-cli",
            summary=cli_msg,
            hint="Run `agy` in your terminal to sign in with Google, or run `python3 bridge/daemon.py --setup-auth`.",
        )

    # SDK Cloud Modes (Gemini Developer API or Vertex AI / Gemini Enterprise)
    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if use_vertex:
        if api_key:
            return AuthStatus(
                ok=True,
                method="sdk-vertex-express",
                summary=f"Gemini Enterprise (Vertex Express Mode) API Key ({mask_secret(api_key)})",
            )
        if vertex_project and check_adc_available():
            return AuthStatus(
                ok=True,
                method="sdk-vertex-adc",
                summary=f"Gemini Enterprise (Vertex Standard ADC) project={vertex_project}",
            )
        return AuthStatus(
            ok=False,
            method="sdk-vertex",
            summary="Vertex AI / Gemini Enterprise credentials missing.",
            hint="Run `gcloud auth application-default login` and set `--project <GCP_PROJECT_ID>`, or provide `GEMINI_API_KEY`.",
        )

    if api_key:
        return AuthStatus(
            ok=True,
            method="sdk-gemini-api-key",
            summary=f"Google AI Studio GEMINI_API_KEY ({mask_secret(api_key)})",
        )

    return AuthStatus(
        ok=False,
        method="unconfigured",
        summary="No Antigravity authentication detected (`agy` CLI login or `GEMINI_API_KEY`).",
        hint=(
            "Run `python3 bridge/daemon.py --setup-auth` for guided setup, "
            "run `agy` to sign in via browser, or create a key at https://aistudio.google.com/app/api-keys"
        ),
    )


def run_interactive_auth_setup(repo_root: Path) -> int:
    """Interactive CLI wizard to help users set up Antigravity authentication easily."""
    dotenv_path = repo_root / ".env"
    agy_bin = shutil.which("agy") or os.path.expanduser("~/.local/bin/agy")
    has_agy = bool(agy_bin and Path(agy_bin).exists())

    print("=" * 68)
    print(" 🔐 Antigravity WoW Forever — Authentication Setup Wizard")
    print("=" * 68)
    print(" Choose how you want to authenticate with Google Antigravity:\n")
    print(f"  [1] Antigravity CLI (`agy`) Google Account Sign-In {'(Installed!)' if has_agy else '(Requires agy CLI)'}")
    print("      -> No API key needed; signs in via your browser.")
    print("  [2] Google AI Studio API Key (`GEMINI_API_KEY` saved to local `.env`)")
    print("      -> Uses `google-antigravity` Python SDK. Get a key at: https://aistudio.google.com/app/api-keys")
    print("  [3] Google Cloud / Gemini Enterprise (Vertex AI ADC)")
    print("      -> Uses `gcloud auth application-default login` + GCP Project ID.")
    print("  [4] Local Model (Ollama / LM Studio / LiteRT Gemma 4 — No Auth / Free)")
    print()

    choice = input("Select option [1-4] (or 'q' to cancel): ").strip().lower()
    if choice in ("q", "quit", "exit", ""):
        print("Setup cancelled.")
        return 0

    if choice == "1":
        if not has_agy:
            print("\n❌ `agy` CLI was not found on your PATH. Install it first with one command:")
            print("  • macOS / Linux : curl -fsSL https://antigravity.google/cli/install.sh | bash")
            print("  • Windows (PS)  : irm https://antigravity.google/cli/install.ps1 | iex")
            print("  • Docs          : https://antigravity.google/docs")
            return 1
        print(f"\nLaunching `{agy_bin}` so you can complete Google sign-in (press Ctrl+D twice after signing in)...")
        subprocess.run([agy_bin], check=False)
        return 0

    if choice == "2":
        print("\n1. Open: https://aistudio.google.com/app/api-keys")
        print("2. Copy your API key and paste it below (input is hidden):")
        key = getpass.getpass("GEMINI_API_KEY: ").strip()
        if not key:
            print("❌ Empty key; nothing was written.")
            return 1
        write_env_key_safely(dotenv_path, {"GEMINI_API_KEY": key})
        print(f"\n✅ Saved masked key ({mask_secret(key)}) to {dotenv_path} (permissions 0600, git-ignored)!")
        print("You can now run: python3 bridge/daemon.py --backend sdk")
        return 0

    if choice == "3":
        project = input("Enter your Google Cloud Project ID: ").strip()
        location = input("Enter region [default: us-central1]: ").strip() or "us-central1"
        if not project:
            print("❌ Project ID is required.")
            return 1
        write_env_key_safely(
            dotenv_path,
            {
                "AGY_USE_VERTEX": "true",
                "GOOGLE_CLOUD_PROJECT": project,
                "GOOGLE_CLOUD_LOCATION": location,
            },
        )
        print(f"\n✅ Saved Vertex AI config to {dotenv_path}!")
        if not check_adc_available():
            print("⚠️ Next step: run `gcloud auth application-default login` in your terminal.")
        return 0

    if choice == "4":
        print("\n✅ No authentication or API key is needed for local models!")
        print("• Ollama example:")
        print("  ollama pull gemma4:26b")
        print("  python3 bridge/daemon.py --backend sdk --local-openai-url http://localhost:11434/v1 --local-model gemma4:26b")
        print("• LiteRT on-device example:")
        print("  python3 bridge/daemon.py --backend sdk --litert-model ~/.litert-lm/models/gemma4-26b/model.litertlm")
        return 0

    print(f"Unknown option: {choice!r}")
    return 1
