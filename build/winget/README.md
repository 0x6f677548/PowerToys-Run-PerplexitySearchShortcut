# Winget Package Installation

This directory contains the necessary files for distributing the PowerToys Run Perplexity Search Shortcut plugin via the Windows Package Manager (winget).

## Steps to Submit to Winget Repository

1. Create a GitHub release for your plugin with the MSI installer
2. Calculate the SHA256 hash of the MSI file and update it in the installer manifest
3. Fork the [winget-pkgs repository](https://github.com/microsoft/winget-pkgs)
4. Add your manifests to the fork following the same directory structure
5. Submit a pull request to the winget-pkgs repository

## Update Process

When releasing a new version:
1. Update version numbers in all manifest files
2. Update the SHA256 hash in the installer manifest
3. Create a new release on GitHub with the updated MSI
4. Submit updated manifests to winget-pkgs

## Validation

Before submission, validate your manifest using the winget CLI:

```powershell
winget validate --manifest <path-to-manifest>
```

## Installation Instructions for Users

Once approved, users can install your plugin using:

```powershell
winget install PerplexitySearchShortcut.PowerToysRunPlugin
```
