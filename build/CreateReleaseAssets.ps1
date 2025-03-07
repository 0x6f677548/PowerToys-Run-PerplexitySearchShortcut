param(
    [Parameter(Mandatory=$false)]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [string]$ArchOverride,
    
    [Parameter(Mandatory=$false)]
    [string]$WixToolsetPath = "C:\Program Files (x86)\WiX Toolset v3.14\bin"
)

$ErrorActionPreference = "Stop"

# Define core paths and project-specific constants
$projectRoot = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $projectRoot "dist"
$wixDir = Join-Path $projectRoot "build\wix"
$wixObjDir = Join-Path $outputDir "wixobj"
$projectName = "PerplexitySearchShortcut"
$projectOutputDir = Join-Path $outputDir $projectName
$projectFilesPrefix= "Community.PowerToys.Run.Plugin.$projectName"
$pluginDll = "$projectFilesPrefix.dll"
$pluginDepsJson = "$projectFilesPrefix.deps.json"
$pluginJson = "plugin.json"
$packageIdentifier = "$projectName.PowerToysRunPlugin"
$buildArch = "x64" # Default to x64

# Detect system architecture
$architecture = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
if ($architecture -eq "ARM64") {
    $buildArch = "ARM64"
}
# Allow override through parameter
if ($ArchOverride) {
    $buildArch = $ArchOverride
}
Write-Host "Detected processor architecture: $architecture" -ForegroundColor Cyan
Write-Host "Using build architecture: $buildArch" -ForegroundColor Cyan


# Version detection code
if (-not $Version) {
    # Find plugin.json
    $pluginsJsonPath = Get-ChildItem -Path $projectRoot -Recurse -Filter "plugin.json" | Select-Object -First 1
    
    if ($null -ne $pluginsJsonPath) {
        try {
            $pluginData = Get-Content -Path $pluginsJsonPath.FullName -Raw | ConvertFrom-Json
            $Version = $pluginData.Version
            Write-Host "Using version $Version from plugin.json"
        }
        catch {
            Write-Error "⚠️ Failed to read version from plugin.json: $_"
            exit 1
        }
    }
    
    if (-not $Version) {
        Write-Error "⚠️ Version not specified and could not be found in plugin.json"
        exit 1
    }
}
$zipFileName = "$projectFilesPrefix-$Version-$buildArch.zip"
$msiFileName = "$projectName-$Version-$buildArch.msi"



# Verify WiX toolset exists
if (-not (Test-Path $WixToolsetPath)) {
    Write-Error "⚠️ WiX Toolset not found at path: $WixToolsetPath. Please install WiX Toolset or specify the correct path using the -WixToolsetPath parameter."
    Write-Host "You can download WiX Toolset v3.14 or later from https://wixtoolset.org/releases/"
    exit 1
}

# Check if required WiX tools exist
$requiredTools = @("candle.exe", "light.exe")
$missingTools = $requiredTools | Where-Object { !(Test-Path (Join-Path $WixToolsetPath $_)) }
if ($missingTools.Count -gt 0) {
    Write-Error "⚠️ The following required WiX tools are missing from $WixToolsetPath`: $($missingTools -join ', ')"
    exit 1
}

Write-Host "Using WiX Toolset from: $WixToolsetPath" -ForegroundColor Cyan

# Create the wix directory if it doesn't exist (needed for license.rtf)
If (!(Test-Path $wixDir)) {
    Write-Host "Creating wix directory for license file..."
    New-Item -ItemType Directory -Path $wixDir -Force | Out-Null
}

# Ensure output directories exist
If (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}
If (!(Test-Path $wixObjDir)) {
    New-Item -ItemType Directory -Path $wixObjDir | Out-Null
}
If (!(Test-Path $projectOutputDir)) {
    New-Item -ItemType Directory -Path $projectOutputDir | Out-Null
}

# Find the compiled DLL - look for architecture-specific build
$dllPath = Get-ChildItem -Path $projectRoot -Recurse -Filter $pluginDll | 
    Where-Object { 
        $_.Directory -like "*\bin\*" -and 
        ($_.FullName -like "*\$buildArch\*" -or $_.Directory.Name -eq $buildArch)
    } | 
    Select-Object -First 1

# If not found, try the default search as fallback
if ($null -eq $dllPath) {
    Write-Host "No architecture-specific build found for $buildArch, trying default build paths..." -ForegroundColor Yellow
    $dllPath = Get-ChildItem -Path $projectRoot -Recurse -Filter $pluginDll | Where-Object { $_.Directory -like "*\bin\*" } | Select-Object -First 1
}

if ($null -eq $dllPath) {
    Write-Error "⚠️ Could not find the compiled DLL for architecture $buildArch. Have you built the project?"
    exit 1
}

$dllDir = $dllPath.Directory.FullName
Write-Host "Found DLL at: $($dllPath.FullName)" -ForegroundColor Green

# Output path variables - defined at point of use for clarity
$zipPath = Join-Path $outputDir $zipFileName
$msiPath = Join-Path $outputDir $msiFileName
$licenseFile = Join-Path $projectRoot "LICENSE"
$licenseRtfFile = Join-Path $wixDir "license.rtf"

# Copy all required files to dist folder
# DLL file
Copy-Item -Path $dllPath.FullName -Destination $projectOutputDir
Write-Host "✅ Copied DLL file"

# Dependencies JSON file
$depsJsonPath = Join-Path $dllDir $pluginDepsJson
if (Test-Path $depsJsonPath) {
    Copy-Item -Path $depsJsonPath -Destination $projectOutputDir
    Write-Host "✅ Copied dependencies JSON file"
} else {
    Write-Error "⚠️ Dependencies JSON file not found: $depsJsonPath. This file is required."
    exit 1
}

# Plugin JSON file
$pluginJsonPath = Get-ChildItem -Path $projectRoot -Recurse -Filter $pluginJson | Select-Object -First 1
if ($null -ne $pluginJsonPath) {
    Copy-Item -Path $pluginJsonPath.FullName -Destination $projectOutputDir
    Write-Host "✅ Copied plugin JSON file"
} else {
    Write-Error "⚠️ Plugin JSON file not found. This file is required."
    exit 1
}

# Images folder
$imagesDir = Join-Path $projectRoot "Images"
if (Test-Path $imagesDir) {
    $imagesOutputDir = Join-Path $projectOutputDir "Images"
    if (!(Test-Path $imagesOutputDir)) {
        New-Item -ItemType Directory -Path $imagesOutputDir | Out-Null
    }
    Copy-Item -Path "$imagesDir\*" -Destination $imagesOutputDir -Recurse
    Write-Host "✅ Copied Images folder"
} else {
    # Try to create sample images if the directory doesn't exist
    Write-Host "⚠️ Images directory not found: $imagesDir. Trying to create sample images..." -ForegroundColor Yellow
    & "$PSScriptRoot\CreateSampleImages.ps1"
    
    # Check again if images directory exists after running the script
    if (Test-Path $imagesDir) {
        $imagesOutputDir = Join-Path $projectOutputDir "Images"
        if (!(Test-Path $imagesOutputDir)) {
            New-Item -ItemType Directory -Path $imagesOutputDir | Out-Null
        }
        Copy-Item -Path "$imagesDir\*" -Destination $imagesOutputDir -Recurse
        Write-Host "✅ Created and copied Images folder"
    } else {
        Write-Error "⚠️ Failed to create Images directory. This directory is required."
        exit 1
    }
}

# Create zip file 
$zipPath = Join-Path $outputDir $zipFileName
# Compress from plugin output dir to maintain folder structure in the zip
Compress-Archive -Path "$projectOutputDir" -DestinationPath $zipPath -Force
Write-Host "✅ Created ZIP file: $zipPath"

# Calculate zip SHA256 hash
$zipHash = Get-FileHash -Path $zipPath -Algorithm SHA256

# Create a license.rtf file for WiX installer
# If LICENSE exists, convert it to RTF, otherwise create a basic RTF
if (Test-Path $licenseFile) {
    # Read license content as plain text
    $licenseContent = Get-Content -Path $licenseFile -Raw
    
    # Create the most basic RTF document possible
    $rtfContent = "{\rtf1\ansi\deff0{\fonttbl{\f0\fnil\fcharset0 Arial;}}\viewkind4\uc1\pard\f0\fs20 "
    
    # Simply escape any special RTF characters and append the text
    $rtfText = $licenseContent -replace '\\', '\\\\' -replace '{', '\{' -replace '}', '\}' -replace '\r\n|\n', '\line '
    $rtfContent += $rtfText
    $rtfContent += "}"
    
    # Write to file with correct encoding
    [System.IO.File]::WriteAllText($licenseRtfFile, $rtfContent)
    
    Write-Host "Created license.rtf from LICENSE file"
} elseif (!(Test-Path $licenseRtfFile)) {
    # Create a basic license.rtf if LICENSE doesn't exist and rtf doesn't already exist
    Write-Host "Creating basic license.rtf..."
    
    $licenseContent = @'
{\rtf1\ansi\ansicpg1252\deff0\nouicompat\deflang1033{\fonttbl{\f0\fnil\fcharset0 Calibri;}}
{\*\generator Riched20 10.0.19041}\viewkind4\uc1 
\pard\sa200\sl276\slmult1\f0\fs22\lang9 MIT License\par
Copyright (c) 2023 0x6f677548\par
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:\par
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.\par
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.\par
}
'@
    $licenseContent | Out-File -FilePath $licenseRtfFile -Encoding ascii
}

# Build MSI using WiX Toolset
Write-Host "Building MSI with WiX Toolset from $WixToolsetPath..."

# Compile the WiX source files
& "$WixToolsetPath\candle.exe" -arch $buildArch -ext WixUIExtension -out "$wixObjDir\" (Join-Path $projectRoot "installer\wix\$projectName.wxs") `
    -dVersion="$Version" -dSourceDir="$projectOutputDir\" -dPluginDllName="$pluginDll" -dPluginDepsJsonName="$pluginDepsJson" -dPluginJsonName="$pluginJson"

if ($LASTEXITCODE -ne 0) {
    Write-Error "⚠️ Failed to compile WiX source files"
    exit 1
}

# Link the MSI
& "$WixToolsetPath\light.exe" -ext WixUIExtension `
    -sval `
    $(if (Test-Path $licenseRtfFile) {"-dWixUILicenseRtf=$licenseRtfFile"}) `
    -out "$msiPath" -pdbout "$wixObjDir\$projectName.wixpdb" "$wixObjDir\$projectName.wixobj"

if ($LASTEXITCODE -ne 0) {
    Write-Error "⚠️ Failed to link MSI"
    exit 1
}
Write-Host "✅ Created MSI file: $msiPath"

# Calculate MSI SHA256 hash
$msiHash = Get-FileHash -Path $msiPath -Algorithm SHA256

# write zip hash to zip.sha256 file
$zipHash | Out-File -FilePath "$zipPath.sha256" -Encoding ascii

# write msi hash to msi.sha256 file
$msiHash | Out-File -FilePath "$msiPath.sha256" -Encoding ascii

Write-Host "Release packages created for architecture: $buildArch"
Write-Host "ZIP: $zipPath"
Write-Host "ZIP SHA256: $($zipHash.Hash)"
Write-Host "MSI: $msiPath"
Write-Host "MSI SHA256: $($msiHash.Hash)"

# Now create the winget manifests from templates
$manifestTemplatesFolder = Join-Path $projectRoot "installer\winget\manifest_templates"
$distWingetFolder = Join-Path $outputDir "winget\manifests"
$manifestVersionFolder = Join-Path $distWingetFolder "$Version"

if (Test-Path $manifestTemplatesFolder) {
    Write-Host "`nCreating winget manifests from templates..."
    
    # Create the destination folder structure
    if (-not (Test-Path $manifestVersionFolder)) {
        New-Item -ItemType Directory -Path $manifestVersionFolder -Force | Out-Null
        Write-Host "Created manifest folder structure for version $Version"
    }
    
    # Get all YAML files from the templates directory
    $templateFiles = Get-ChildItem -Path $manifestTemplatesFolder -Filter "*.yaml"
    
    if ($templateFiles.Count -eq 0) {
        Write-Host "No manifest templates found in $manifestTemplatesFolder" -ForegroundColor Yellow
    }
    else {
        foreach ($templateFile in $templateFiles) {
            $content = Get-Content -Path $templateFile.FullName -Raw
            
            # Replace variables in the format $var$ with their values
            $content = $content.Replace('$version$', $Version)
            $content = $content.Replace('$buildarch$', $buildArch)
            $content = $content.Replace('$sha256$', $msiHash.Hash)
            
            # Create the output filename with the correct version
            $outputFileName = $templateFile.Name -replace '\.yaml$', ".yaml"
            $outputPath = Join-Path $manifestVersionFolder $outputFileName
            
            # Save the updated content to the destination folder
            Set-Content -Path $outputPath -Value $content
            Write-Host "Created $outputFileName from template"
        }
        
        Write-Host "`n ✅ Winget manifests created successfully in $manifestVersionFolder"
        Write-Host "You can submit these manifests to the winget-pkgs repository after release."
    }
}
else {
    Write-Host "`nNo manifest templates folder found at $manifestTemplatesFolder" -ForegroundColor Yellow
    Write-Host "To automatically generate winget manifests, create a templates directory at:"
    Write-Host "$manifestTemplatesFolder"
    Write-Host "with the following files:"
    Write-Host "- $packageIdentifier.yaml"
    Write-Host "- $packageIdentifier.installer.yaml"
    Write-Host "- $packageIdentifier.locale.en-US.yaml"
    Write-Host "`nIn template files, use the following variables:"
    Write-Host "- \$version\$ - will be replaced with the package version"
    Write-Host "- \$buildarch\$ - will be replaced with the build architecture (x64 or ARM64)"
    Write-Host "- \$sha256\$ - will be replaced with the MSI SHA256 hash"
}
