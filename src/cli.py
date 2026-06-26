from __future__ import annotations

import argparse
import ctypes
import json
import os
import platform
import random
import re
import shutil
import sys
import time
from dataclasses import dataclass
from importlib import resources
from pathlib import Path
from typing import Any

ESC = "\033"
RESET = f"{ESC}[0m"
ANSI_PATTERN = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]")
@dataclass(frozen=True)
class Field:
    key: str
    label: str
    value: str


def user_config_path() -> Path:
    if os.name == "nt":
        return Path.home() / ".config" / "pokefetch" / "config.json"
    return Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "pokefetch" / "config.json"


def user_data_dir() -> Path:
    if os.name == "nt":
        return Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local")) / "PokeFetch"
    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "pokefetch"


def package_root() -> Path:
    return Path(__file__).resolve().parents[1]


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def deep_merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    result = dict(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result


def load_theme(name_or_path: str) -> dict[str, Any]:
    path = Path(name_or_path).expanduser()
    if path.exists():
        return load_json(path)

    resource = resources.files("src").joinpath("themes", f"{name_or_path}.json")
    if not resource.is_file():
        names = ", ".join(list_themes())
        raise SystemExit(f"Unknown theme '{name_or_path}'. Available themes: {names}")

    with resource.open("r", encoding="utf-8") as file:
        return json.load(file)


def list_themes() -> list[str]:
    themes_dir = resources.files("src").joinpath("themes")
    return sorted(path.name.removesuffix(".json") for path in themes_dir.iterdir() if path.name.endswith(".json"))


def load_config(path: Path | None) -> dict[str, Any]:
    config_path = path or user_config_path()
    if not config_path.exists():
        return {}
    return load_json(config_path)


def hex_to_ansi(value: str) -> str:
    clean = value.strip().lstrip("#")
    if len(clean) != 6:
        return ""
    red = int(clean[0:2], 16)
    green = int(clean[2:4], 16)
    blue = int(clean[4:6], 16)
    return f"{ESC}[38;2;{red};{green};{blue}m"


def strip_ansi(text: str) -> str:
    return ANSI_PATTERN.sub("", text)


def display_width(text: str) -> int:
    return len(strip_ansi(text).rstrip())


def trim_ansi_line_end(text: str) -> str:
    return re.sub(rf"\s+((?:{ANSI_PATTERN.pattern})*)$", r"\1", text)


def normalize_art(lines: list[str]) -> list[str]:
    cleaned = [trim_ansi_line_end(line) for line in lines if strip_ansi(line).strip()]
    if not cleaned:
        return []

    leading_counts = []
    for line in cleaned:
        plain = strip_ansi(line)
        if plain.strip():
            leading_counts.append(len(plain) - len(plain.lstrip()))

    leading = min(leading_counts) if leading_counts else 0
    if leading <= 0:
        return cleaned
    return [line[leading:] if len(line) >= leading else line for line in cleaned]


def find_sprite_root(config: dict[str, Any], override: str | None) -> Path | None:
    candidates = [override, os.environ.get("POKEFETCH_SPRITES_DIR"), config.get("sprites_dir")]
    candidates.extend(
        [
            str(Path(__file__).resolve().parent),
            str(user_data_dir()),
            str(Path.home() / ".local" / "share" / "pokemon-colorscripts"),
            str(package_root() / "pokemon-colorscripts"),
        ]
    )
    for candidate in candidates:
        if not candidate:
            continue
        root = Path(candidate).expanduser()
        if (root / "colorscripts").exists():
            return root
    return None


def read_sprite(root: Path, theme: dict[str, Any], args: argparse.Namespace) -> list[str]:
    sprite_config = theme.get("sprite", {})
    size = args.size or os.environ.get("POKEFETCH_SIZE") or sprite_config.get("size", "small")
    variant = "shiny" if args.shiny or os.environ.get("POKEFETCH_SHINY") == "1" else sprite_config.get("variant", "regular")
    directory = root / "colorscripts" / size / variant
    if not directory.exists():
        raise SystemExit(f"Sprite directory not found: {directory}")

    pokemon = args.pokemon or os.environ.get("POKEFETCH_POKEMON") or sprite_config.get("pokemon")
    if pokemon:
        file = directory / pokemon.lower()
        if not file.exists():
            raise SystemExit(f"Pokemon '{pokemon}' not found in {directory}")
    else:
        files = [path for path in directory.iterdir() if path.is_file()]
        if not files:
            raise SystemExit(f"No sprites found in {directory}")
        file = random.choice(files)

    return normalize_art(file.read_text(encoding="utf-8").splitlines())


def windows_cpu_name() -> str:
    if os.name != "nt":
        return platform.processor() or platform.machine()
    try:
        import winreg

        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"HARDWARE\DESCRIPTION\System\CentralProcessor\0") as key:
            return str(winreg.QueryValueEx(key, "ProcessorNameString")[0]).strip()
    except OSError:
        return platform.processor() or platform.machine()


def memory_info() -> tuple[int, int]:
    if os.name == "nt":
        class MemoryStatus(ctypes.Structure):
            _fields_ = [
                ("dwLength", ctypes.c_ulong),
                ("dwMemoryLoad", ctypes.c_ulong),
                ("ullTotalPhys", ctypes.c_ulonglong),
                ("ullAvailPhys", ctypes.c_ulonglong),
                ("ullTotalPageFile", ctypes.c_ulonglong),
                ("ullAvailPageFile", ctypes.c_ulonglong),
                ("ullTotalVirtual", ctypes.c_ulonglong),
                ("ullAvailVirtual", ctypes.c_ulonglong),
                ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
            ]

        status = MemoryStatus()
        status.dwLength = ctypes.sizeof(status)
        ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status))
        return int(status.ullTotalPhys - status.ullAvailPhys), int(status.ullTotalPhys)

    meminfo = Path("/proc/meminfo")
    if meminfo.exists():
        values = {}
        for line in meminfo.read_text(encoding="utf-8").splitlines():
            key, value = line.split(":", 1)
            values[key] = int(value.strip().split()[0]) * 1024
        total = values.get("MemTotal", 0)
        available = values.get("MemAvailable", 0)
        return total - available, total

    return 0, 0


def uptime_seconds() -> int:
    if os.name == "nt":
        return int(ctypes.windll.kernel32.GetTickCount64() / 1000)
    uptime = Path("/proc/uptime")
    if uptime.exists():
        return int(float(uptime.read_text(encoding="utf-8").split()[0]))
    return int(time.monotonic())


def format_bytes(value: int) -> str:
    if value <= 0:
        return "unknown"
    gib = value / 1024 / 1024 / 1024
    return f"{gib:.1f} GiB"


def format_uptime(seconds: int) -> str:
    days, remainder = divmod(seconds, 86400)
    hours, remainder = divmod(remainder, 3600)
    minutes, _ = divmod(remainder, 60)
    if days:
        return f"{days}d {hours}h {minutes}m"
    if hours:
        return f"{hours}h {minutes}m"
    return f"{minutes}m"


def shell_name(args: argparse.Namespace) -> str:
    if args.shell_name:
        return args.shell_name
    if os.environ.get("POKEFETCH_SHELL"):
        return os.environ["POKEFETCH_SHELL"]
    if os.name == "nt" and os.environ.get("PROMPT"):
        return "CMD"
    return Path(os.environ.get("SHELL", "Shell")).name or "Shell"


def collect_fields(args: argparse.Namespace) -> dict[str, Field]:
    used_ram, total_ram = memory_info()
    disk = shutil.disk_usage(Path.cwd().anchor or Path.home().anchor or Path.home())
    os_name = platform.platform(terse=True)
    if os.name == "nt":
        os_name = platform.win32_edition() or platform.platform(terse=True)
        os_name = f"Windows {platform.release()} {os_name}".strip()

    return {
        "user": Field("user", "USR", f"{os.environ.get('USERNAME') or os.environ.get('USER') or 'user'}"),
        "os": Field("os", "OS", os_name),
        "shell": Field("shell", "Shell", shell_name(args)),
        "cpu": Field("cpu", "CPU", windows_cpu_name()),
        "ram": Field("ram", "RAM", f"{format_bytes(used_ram)} / {format_bytes(total_ram)}"),
        "disk": Field("disk", "Disk", f"{format_bytes(disk.used)} / {format_bytes(disk.total)}"),
        "uptime": Field("uptime", "Up", format_uptime(uptime_seconds())),
    }


def render_info(theme: dict[str, Any], args: argparse.Namespace) -> list[str]:
    info = theme.get("info", {})
    icons = info.get("icons", {})
    colors = info.get("colors", {})
    fields = collect_fields(args)
    selected = info.get("fields", ["os", "shell", "cpu", "ram", "disk", "uptime"])
    label_width = int(info.get("label_width", 6))
    separator = info.get("separator", " ")
    lines = []

    for key in selected:
        field = fields.get(key)
        if not field:
            continue
        color = hex_to_ansi(colors.get(key, "#ffffff"))
        icon = icons.get(key, "")
        prefix = f"{icon} {field.label}".strip().ljust(label_width)
        lines.append(f"{color}{prefix}{RESET}{separator}{field.value}")

    return lines


def render_side(art: list[str], info: list[str], theme: dict[str, Any]) -> str:
    art_width = max((display_width(line) for line in art), default=0)
    gap = " " * int(theme.get("gap", 4))
    align = theme.get("align", "center")
    offset = 0
    if align == "center" and len(art) > len(info):
        offset = (len(art) - len(info)) // 2
    elif align == "bottom" and len(art) > len(info):
        offset = len(art) - len(info)

    rows = max(len(art), offset + len(info))
    output = []
    for index in range(rows):
        left = art[index] if index < len(art) else ""
        info_index = index - offset
        right = info[info_index] if 0 <= info_index < len(info) else ""
        padding = " " * max(0, art_width - display_width(left))
        output.append(f"{left}{RESET}{padding}{gap}{right}".rstrip())
    return "\n".join(output)


def render_stack(art: list[str], info: list[str]) -> str:
    return "\n".join([*art, "", *info])


def render(theme: dict[str, Any], config: dict[str, Any], args: argparse.Namespace) -> str:
    root = find_sprite_root(config, args.sprites_dir)
    if not root:
        raise SystemExit("colorscripts data not found")

    art = read_sprite(root, theme, args)
    info = render_info(theme, args)
    layout = args.layout or theme.get("layout", "side")
    body = render_stack(art, info) if layout == "stack" else render_side(art, info, theme)
    return f"\n{body}\n"


def write_default_config(args: argparse.Namespace) -> None:
    path = Path(args.path or user_config_path()).expanduser()
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not args.force:
        raise SystemExit(f"Config already exists: {path}")
    config = {
        "theme": "side-unicode",
        "sprites_dir": None,
    }
    path.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    print(path)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="pokefetch", description="Themeable Pokemon terminal fetch")
    parser.add_argument("--theme", help="Theme name or JSON path")
    parser.add_argument("--config", type=Path, help="Config JSON path")
    parser.add_argument("--layout", choices=["side", "stack"], help="Override theme layout")
    parser.add_argument("--size", choices=["small", "large"], help="Sprite size")
    parser.add_argument("--pokemon", help="Pokemon name")
    parser.add_argument("--shiny", action="store_true", help="Use shiny sprites")
    parser.add_argument("--sprites-dir", help="Path to pokemon-colorscripts repo")
    parser.add_argument("--shell-name", help="Displayed shell name")
    parser.add_argument("--list-themes", action="store_true", help="List bundled themes")

    subparsers = parser.add_subparsers(dest="command")
    config_parser = subparsers.add_parser("init-config", help="Write a default config JSON")
    config_parser.add_argument("--path", help="Config output path")
    config_parser.add_argument("--force", action="store_true", help="Overwrite existing config")
    return parser


def main(argv: list[str] | None = None) -> None:
    reconfigure = getattr(sys.stdout, "reconfigure", None)
    if callable(reconfigure):
        reconfigure(encoding="utf-8")
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.list_themes:
        print("\n".join(list_themes()))
        return

    if args.command == "init-config":
        write_default_config(args)
        return

    config = load_config(args.config)
    theme_name = args.theme or config.get("theme", "side-unicode")
    theme = load_theme(theme_name)
    print(render(theme, config, args), end="")


if __name__ == "__main__":
    main()
