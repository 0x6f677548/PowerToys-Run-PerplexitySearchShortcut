param(
    [Parameter(Mandatory=$false)]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [string]$Architecture = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
)

$ErrorActionPreference = "Stop"

# Define core paths and project-specific constants
$projectRoot = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $projectRoot "dist"
$buildDir = $PSScriptRoot
$projectName = "PerplexitySearchShortcut"
$projectOutputDir = Join-Path $outputDir $projectName
$projectFilesPrefix= "Community.PowerToys.Run.Plugin.$projectName"
$pluginDll = "$projectFilesPrefix.dll"
$pluginDepsJson = "$projectFilesPrefix.deps.json"
$pluginJson = "plugin.json"
$packageIdentifier = "$projectName.PowerToysRunPlugin"
if ($Architecture -eq "AMD64") {
    $Architecture = "x64"
} 

Write-Host "Using build architecture: $Architecture" -ForegroundColor Cyan

# Check if WiX .NET tool is installed
$wixInstalled = $false
try {
    $wixVersion = & dotnet tool list -g | Select-String "wix" | Out-String
    if ($wixVersion -match "wix") {
        $wixInstalled = $true
        Write-Host "✅ WiX .NET tool is installed: $($wixVersion.Trim())" -ForegroundColor Green
    }
} catch {
    $wixInstalled = $false
}

if (-not $wixInstalled) {
    Write-Host "❌ WiX .NET tool is not installed" -ForegroundColor Yellow
    Write-Host "Would you like to install it now? (y/n)" -ForegroundColor Cyan
    $install = Read-Host
    if ($install -eq "y") {
        Write-Host "Installing WiX .NET tool..." -ForegroundColor Cyan
        & dotnet tool install -g wix
        if ($LASTEXITCODE -ne 0) {
            Write-Error "⚠️ Failed to install WiX .NET tool"
            exit 1
        }
        Write-Host "✅ WiX .NET tool installed successfully" -ForegroundColor Green
    } else {
        Write-Error "⚠️ WiX .NET tool is required to build the MSI"
        exit 1
    }
}

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
$zipFileName = "$projectName-$Version-$Architecture.zip"
$msiFileName = "$projectName-$Version-$Architecture.msi"

# Ensure output directories exist
If (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}
If (!(Test-Path $projectOutputDir)) {
    New-Item -ItemType Directory -Path $projectOutputDir | Out-Null
}

# Find the compiled DLL - look for architecture-specific build
$dllPath = Get-ChildItem -Path $projectRoot -Recurse -Filter $pluginDll | 
    Where-Object { 
        $_.Directory -like "*\bin\*" -and 
        ($_.FullName -like "*\$Architecture\*" -or $_.Directory.Name -eq $Architecture)
    } | 
    Select-Object -First 1

# If not found, try the default search as fallback
if ($null -eq $dllPath) {
    Write-Host "No architecture-specific build found for $Architecture, trying default build paths..." -ForegroundColor Yellow
    $dllPath = Get-ChildItem -Path $projectRoot -Recurse -Filter $pluginDll | Where-Object { $_.Directory -like "*\bin\*" } | Select-Object -First 1
}

if ($null -eq $dllPath) {
    Write-Error "⚠️ Could not find the compiled DLL for architecture $Architecture. Have you built the project?"
    exit 1
}

$dllDir = $dllPath.Directory.FullName
Write-Host "Found DLL at: $($dllPath.FullName)" -ForegroundColor Green

# Output path variables - defined at point of use for clarity
$zipPath = Join-Path $outputDir $zipFileName
$msiPath = Join-Path $outputDir $msiFileName

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

# Build MSI using WiX .NET tool
Write-Host "Building MSI with WiX .NET tool..." -ForegroundColor Cyan

# Build MSI directly using the WiX file from the build directory
$wxsPath = Join-Path $buildDir "$projectName.wxs"

# Construct command string with proper formatting for Invoke-Expression
# Using define instead of bindvariable for WiX v5 compatibility
$buildCommand = "wix build ""$wxsPath"" -arch $Architecture -d Version=""$Version"" -d SourceDir=""$projectOutputDir"" -d PluginDllName=""$pluginDll"" -d PluginDepsJsonName=""$pluginDepsJson"" -d PluginJsonName=""$pluginJson"" -o ""$msiPath"""

# Display the command for the user and execute it
Write-Host "Executing: $buildCommand" -ForegroundColor DarkCyan
Invoke-Expression $buildCommand

if ($LASTEXITCODE -ne 0) {
    Write-Error "⚠️ Failed to build MSI with WiX .NET tool"
    exit 1
}

if (Test-Path $msiPath) {
    Write-Host "✅ Created MSI file: $msiPath" -ForegroundColor Green
} else {
    Write-Error "⚠️ Failed to create MSI file"
    exit 1
}

# Calculate MSI SHA256 hash
$msiHash = Get-FileHash -Path $msiPath -Algorithm SHA256

# write zip hash to zip.sha256 file
$zipHash | Out-File -FilePath "$zipPath.sha256" -Encoding ascii

# write msi hash to msi.sha256 file
$msiHash | Out-File -FilePath "$msiPath.sha256" -Encoding ascii

Write-Host "Release packages created for architecture: $Architecture"
Write-Host "ZIP: $zipPath"
Write-Host "ZIP SHA256: $($zipHash.Hash)"
Write-Host "MSI: $msiPath"
Write-Host "MSI SHA256: $($msiHash.Hash)"

# Now create the winget manifests from templates
$manifestTemplatesFolder = Join-Path $projectRoot "build\winget\manifest_templates"
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
            $content = $content.Replace('$architecture$', $Architecture)
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
    Write-Host "- \$Architecture\$ - will be replaced with the build architecture (x64 or ARM64)"
    Write-Host "- \$sha256\$ - will be replaced with the MSI SHA256 hash"
}
