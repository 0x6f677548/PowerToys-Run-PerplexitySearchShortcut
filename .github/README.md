```
                                                               
 ____                 _           _ _         ____                      _     
|  _ \ ___ _ __ _ __ | | _____  _(_) |_ _   _/ ___|  ___  __ _ _ __ ___| |__  
| |_) / _ \ '__| '_ \| |/ _ \ \/ / | __| | | \___ \ / _ \/ _` | '__/ __| '_ \ 
|  __/  __/ |  | |_) | |  __/>  <| | |_| |_| |___) |  __/ (_| | | | (__| | | |
|_|   \___|_|  | .__/|_|\___/_/\_\_|\__|\__, |____/ \___|\__,_|_|  \___|_| |_|
               |_|                      |___/                                 
```

# Perplexity Search Shortcut - PowerToys Run Plugin

![GitHub repo size](https://img.shields.io/github/repo-size/0x6f677548/PowerToys-Run-PerplexitySearchShortcut)
![GitHub Release](https://img.shields.io/github/v/release/0x6f677548/PowerToys-Run-PerplexitySearchShortcut)
[![build_create_release](https://github.com/0x6f677548/PowerToys-Run-PerplexitySearchShortcut/actions/workflows/build-create-release.yml/badge.svg)](https://github.com/0x6f677548/PowerToys-Run-PerplexitySearchShortcut/actions/workflows/build-create-release.yml)

A [PowerToys Run](https://aka.ms/PowerToysOverview#powertoys-run) plugin that enables quick searching using [Perplexity AI](https://perplexity.ai/).

## Preview

![Preview of the plugin in action](./screenshots/perplexitysearchshortcut-demo1-zoom.gif)


## Description

This plugin allows you to quickly search the web using Perplexity AI directly from PowerToys Run. Simply type the activation keyword followed by your search query, and the plugin will open Perplexity AI with your search term.

## Requirements

- [PowerToys](https://github.com/microsoft/PowerToys) (version 0.88.0 or later)
- Windows 10 or 11
- .NET 9.0 Runtime

## Installation

### Via [ptr](https://github.com/8LWXpg/ptr)

```shell
ptr add PerplexitySearchShortcut 0x6f677548/PowerToys-Run-PerplexitySearchShortcut
```

### Manual Installation

1. Download the latest release from the [Releases page](https://github.com/0x6f677548/PowerToys-Run-PerplexitySearchShortcut/releases)
2. Extract the archive to `%LOCALAPPDATA%\Microsoft\PowerToys\PowerToys Run\Plugins`
3. Restart PowerToys Run

### Build and Deploy

If you want to build and deploy the plugin directly from source:

1. Clone this repository
2. Run the provided PowerShell script:

```powershell
.\BuildAndDeploy.ps1
```

This script will:
- Build the plugin for your platform
- Copy the built files to the PowerToys Run plugins directory
- Restart PowerToys to apply changes

## Usage

1. Open PowerToys Run with `Alt+Space` (default hotkey)
2. Type `:p` followed by your search query (e.g., `:p how does quantum computing work`)
3. Press Enter to open Perplexity AI with your query

You can change the activation keyword in PowerToys Run settings.

## License

This project is licensed under the [MIT License](LICENSE).
