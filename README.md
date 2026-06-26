# PokeFetch

A Pokemon fetch CLI for your terminal. It works like neofetch, but with random Pokemon sprites.

Sprites come from the original project:

- https://gitlab.com/phoneybadger/pokemon-colorscripts

Thanks to `phoneybadger/pokemon-colorscripts`. This repository only includes its `colorscripts/` folder.

## Preview

![PokeFetch preview](assets/image.png)

Put more screenshots in the `assets/` folder.

## Install

### Windows

Requires Python 3.9+.

```powershell
git clone https://github.com/Yanzz231/PokeFetch.git
cd PokeFetch
powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1
```

The installer will:

- install the `pokefetch` command
- create a default config at `%USERPROFILE%\.config\pokefetch\config.json`
- add startup hooks for PowerShell and CMD

Restart your terminal after installing.

### Linux / macOS

```sh
git clone https://github.com/Yanzz231/PokeFetch.git
cd PokeFetch
sh ./scripts/install-unix.sh
```

Add PokeFetch to your shell startup file:

```sh
pokefetch show
```

Examples:

```sh
echo 'pokefetch --shell-name zsh show' >> ~/.zshrc
echo 'pokefetch --shell-name bash show' >> ~/.bashrc
```

## Usage

Running `pokefetch` without a command prints a help hint. Use `pokefetch show` to render the Pokemon fetch output.

```sh
pokefetch --help
pokefetch --version
pokefetch show
pokefetch --list-themes
pokefetch menu
pokefetch paths
pokefetch paths --menu
pokefetch paths --open config
pokefetch --theme side-unicode show
pokefetch --theme side-nerd show
pokefetch --theme dracula-side show
pokefetch --theme stacked-minimal show
pokefetch --pokemon pikachu show
pokefetch --pokemon charizard --size large show
pokefetch --layout side show
pokefetch --layout stack show
pokefetch --shiny show
pokefetch update
pokefetch uninstall --keep-package
pokefetch uninstall
```

## Paths and menu

`paths --open ...` opens File Explorer/Finder on that path.

```sh
pokefetch menu
pokefetch paths
pokefetch paths --menu
pokefetch paths --open config
pokefetch paths --open themes
pokefetch paths --open colorscripts
```

## Themes

Themes are stored in:

```txt
src/themes/
```

Pokemon sprites are stored in:

```txt
src/colorscripts/
```

Themes are plain JSON files, so they are easy to edit.

Example theme:

```json
{
  "name": "side-unicode",
  "layout": "side",
  "align": "center",
  "gap": 4,
  "sprite": {
    "size": "small",
    "variant": "regular",
    "pokemon": null
  },
  "info": {
    "label_width": 8,
    "separator": " ",
    "fields": ["os", "shell", "uptime", "cpu", "ram", "disk"],
    "icons": {
      "os": "⊞",
      "shell": "❯",
      "uptime": "◷",
      "cpu": "⚙",
      "ram": "▣",
      "disk": "◧"
    },
    "colors": {
      "os": "#50fa7b",
      "shell": "#bd93f9",
      "uptime": "#f1fa8c",
      "cpu": "#8be9fd",
      "ram": "#ff79c6",
      "disk": "#ffb86c"
    }
  }
}
```

## Built-in themes

- `side-unicode`
- `side-nerd`
- `dracula-side`
- `pastel-side`
- `matrix-side`
- `ocean-side`
- `sunset-side`
- `compact-side`
- `large-side`
- `stacked-minimal`
- `stacked-nerd`

If Nerd Font icons show as boxes, use `side-unicode`.

## Config

Default config:

```json
{
  "theme": "side-unicode",
  "sprites_dir": null,
  "show_on_cls": true
}
```

Config path:

- Windows: `%USERPROFILE%\.config\pokefetch\config.json`
- Linux/macOS: `~/.config/pokefetch/config.json`

`show_on_cls` controls whether PokeFetch appears again after running `cls`.

Change the default theme like this:

```json
{
  "theme": "dracula-side",
  "sprites_dir": null
}
```

## Disable temporarily

PowerShell:

```powershell
$env:POKEFETCH_DISABLE = '1'
```

CMD:

```bat
set POKEFETCH_DISABLE=1
```

## Credits

Pokemon colorscripts come from the original project:

- https://gitlab.com/phoneybadger/pokemon-colorscripts
