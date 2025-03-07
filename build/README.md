# PowerToys Run Perplexity Search Plugin Installer

This directory contains scripts and configuration files for creating installation packages for the PowerToys Run Perplexity Search Plugin.

## Prerequisites

To build the MSI installer, you need:

1. .NET SDK 9.0 or later (https://dotnet.microsoft.com/download)
   - Download and install the .NET SDK

## Building Installation Packages

Run the PowerShell script to build both ZIP and MSI packages:

```powershell
.\CreateReleaseAssets.ps1 -Version <version> -Architecture <architecture>
```

Replace `<version>` with the actual version number you are building and `<architecture>` with the target architecture (e.g., x64, ARM64).

This will:
1. Find the compiled plugin DLL
2. Create a ZIP package for manual installation
3. Build an MSI installer using WiX .NET tool
4. Calculate SHA256 hashes for both packages

The outputs will be in the `dist` folder:
- `Community.PowerToys.Run.Plugin.PerplexitySearchShortcut-<version>-<architecture>.zip` - For manual installation
- `PerplexitySearchShortcut-<version>-<architecture>.msi` - MSI installer for automated installation

## Installation Methods

### Manual Installation (ZIP)
Extract the DLL file from the ZIP archive and place it in:
`%LOCALAPPDATA%\Microsoft\PowerToys\PowerToys Run\Plugins`

### Automated Installation (MSI)
Run the MSI installer and follow the prompts. The plugin will be installed to the appropriate location.

### Winget Installation
Once the package is submitted to the winget repository, users can install it with:
```
winget install PerplexitySearchShortcut.PowerToysRunPlugin
```
