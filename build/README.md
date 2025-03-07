# PowerToys Run Perplexity Search Plugin Installer

This directory contains scripts and configuration files for creating installation packages for the PowerToys Run Perplexity Search Plugin.

## Prerequisites

To build the MSI installer, you need:

1. WiX Toolset v3.11 or later (https://wixtoolset.org/releases/)
   - Download and install the WiX toolset
   - Create a `wix` subfolder in the installer directory:
     ```powershell
     New-Item -ItemType Directory -Path ".\wix" -Force
     ```
   - Copy the required WiX binaries to the `.\wix` folder:
     ```powershell
     # Assuming default WiX installation path - adjust if needed
     $wixPath = "C:\Program Files (x86)\WiX Toolset v3.11\bin"
     Copy-Item "$wixPath\candle.exe" ".\wix\"
     Copy-Item "$wixPath\light.exe" ".\wix\"
     Copy-Item "$wixPath\*.dll" ".\wix\"
     ```

2. Create a license RTF file:
   ```powershell
   New-Item -ItemType File -Path ".\wix\license.rtf" -Force
   ```
   Then add your license text to this file in RTF format.

## Building Installation Packages

Run the PowerShell script to build both ZIP and MSI packages:

```powershell
.\create_release_package.ps1 -Version 0.1.0
```

This will:
1. Find the compiled plugin DLL
2. Create a ZIP package for manual installation
3. Build an MSI installer using WiX Toolset
4. Calculate SHA256 hashes for both packages

The outputs will be in the `dist` folder:
- `Community.PowerToys.Run.Plugin.PerplexitySearchShortcut.dll.zip` - For manual installation
- `PerplexitySearchShortcut-PowerToysRunPlugin.msi` - MSI installer for automated installation

## Troubleshooting WiX Installation

If you encounter errors during the MSI build process:

1. **Missing WiX binaries**: Ensure the `candle.exe` and `light.exe` files are in the `.\wix` folder
2. **Missing DLLs**: WiX executables require several DLLs to run. Copy all DLLs from the WiX bin folder
3. **Missing license file**: Ensure there's a `license.rtf` file in the `.\wix` folder
4. **Path issues**: Use absolute paths if the relative paths cause problems:
   ```powershell
   $wixPath = "C:\Program Files (x86)\WiX Toolset v3.11\bin"
   & "$wixPath\candle.exe" -arch x64 [other parameters]
   & "$wixPath\light.exe" [other parameters]
   ```

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
