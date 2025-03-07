#
# PowerToys Run Perplexity Search Plugin - Build and Deploy Script
# This script builds the plugin and deploys it to the PowerToys Run plugins directory
#

# Configuration
$projectDir = Split-Path -Parent $PSScriptRoot
$buildConfiguration = "Release"
$projectName = "PerplexitySearchShortcut"
$dotnetframework = "net9.0-windows10.0.22621.0"

# Find the correct PowerToys Run plugin directory
$possiblePluginDirs = @(
    "$env:LOCALAPPDATA\Microsoft\PowerToys\PowerToys Run\Plugins",
    "$env:ProgramFiles\PowerToys\PowerToys Run\Plugins",
    "$env:ProgramFiles (x86)\PowerToys\PowerToys Run\Plugins",
    "$env:LOCALAPPDATA\PowerToys\PowerToys Run\Plugins"
)

$powerToysPluginDir = $null
foreach ($dir in $possiblePluginDirs) {
    if (Test-Path $dir) {
        $powerToysPluginDir = "$dir\$projectName"
        Write-Host "Found PowerToys Run plugins directory at: $dir" -ForegroundColor Cyan
        break
    }
}

if (-not $powerToysPluginDir) {
    Write-Host "Could not find PowerToys Run plugins directory. Please enter the path manually:" -ForegroundColor Yellow
    $userPath = Read-Host "PowerToys Run plugins directory path"
    if (Test-Path $userPath) {
        $powerToysPluginDir = "$userPath\$projectName"
    } else {
        Write-Host "Invalid path. Exiting." -ForegroundColor Red
        exit 1
    }
}

# Ensure we're in the project directory
Set-Location $projectDir

# Before building, ensure we have icon files
Write-Host "Ensuring icon files exist..." -ForegroundColor Cyan
& "$PSScriptRoot\CreateSampleImages.ps1"

# Detect system architecture
$architecture = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
$architecture = "x64" # Default to x64
if ($architecture -eq "ARM64") {
    $architecture = "ARM64"
}
Write-Host "Detected processor architecture: $architecture" -ForegroundColor Cyan
Write-Host "Using build architecture: $architecture" -ForegroundColor Cyan

# Step 1: Check if solution file exists and build accordingly
$solutionFile = Get-ChildItem -Path $projectDir -Filter "*.sln" | Select-Object -First 1
if ($solutionFile) {
    Write-Host "Found solution file: $($solutionFile.Name)" -ForegroundColor Cyan
    Write-Host "Building solution in $buildConfiguration configuration for $architecture..." -ForegroundColor Cyan
    dotnet build $solutionFile.FullName -c $buildConfiguration -p:Platform=$architecture
} else {
    Write-Host "No solution file found. Building project $projectName in $buildConfiguration configuration for $architecture..." -ForegroundColor Cyan
    dotnet build -c $buildConfiguration -p:Platform=$architecture
}

if ($LASTEXITCODE -ne 0) {
    # If the specified architecture build fails, try without specific architecture
    Write-Host "Build for specific architecture failed, trying default architecture..." -ForegroundColor Yellow
    
    if ($solutionFile) {
        dotnet build $solutionFile.FullName -c $buildConfiguration
    } else {
        dotnet build -c $buildConfiguration
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed! Exiting." -ForegroundColor Red
        exit 1
    }
}

# Get the build output directory - support both solution-based and project-based builds, including architecture-specific folders
$possibleBuildDirs = @(
    # For solution build with architecture-specific paths (ARM64, x64, AnyCPU, x86)
    (Join-Path $projectDir "*\bin\*\$buildConfiguration\"$dotnetframework),
    # For solution build (plugin might be in a project subfolder)
    (Join-Path $projectDir "*\bin\$buildConfiguration\"$dotnetframework),
    # For direct project build
    (Join-Path $projectDir "bin\*\$buildConfiguration\"$dotnetframework),
    (Join-Path $projectDir "bin\$buildConfiguration\"$dotnetframework)
)

$buildOutputDir = $null
foreach ($dir in $possibleBuildDirs) {
    Write-Host "Checking directory pattern: $dir" -ForegroundColor DarkGray
    # Using Get-Item with -Path and wildcard support
    $matchingDirs = Get-Item -Path $dir -ErrorAction SilentlyContinue
    if ($matchingDirs) {
        foreach ($matchDir in $matchingDirs) {
            Write-Host "Checking build output in: $($matchDir.FullName)" -ForegroundColor DarkGray
            # Check if the directory contains our plugin DLL
            if (Test-Path (Join-Path $matchDir.FullName "Community.PowerToys.Run.Plugin.$projectName.dll")) {
                $buildOutputDir = $matchDir.FullName
                Write-Host "Found build output directory with plugin: $buildOutputDir" -ForegroundColor Cyan
                break
            }
        }
        if ($buildOutputDir) { break }
    }
}

if (-not $buildOutputDir) {
    Write-Host "Could not find build output directory containing the plugin. Please check the build logs." -ForegroundColor Red
    
    # Additional diagnostic information
    Write-Host "`nDiagnostic information:" -ForegroundColor Yellow
    Write-Host "Looking for plugin DLL: Community.PowerToys.Run.Plugin.$projectName.dll" -ForegroundColor Yellow
    
    # Search entire bin directory for the DLL
    Write-Host "Searching for the plugin DLL in all bin directories..." -ForegroundColor Yellow
    $foundDlls = Get-ChildItem -Path (Join-Path $projectDir "*\bin") -Recurse -Filter "Community.PowerToys.Run.Plugin.$projectName.dll" -ErrorAction SilentlyContinue
    
    if ($foundDlls) {
        Write-Host "Found potential plugin DLLs in the following locations:" -ForegroundColor Green
        foreach ($dll in $foundDlls) {
            Write-Host "  $($dll.FullName)" -ForegroundColor Green
            # Use the first found DLL's directory
            if (-not $buildOutputDir) {
                $buildOutputDir = $dll.Directory.FullName
                Write-Host "Using directory: $buildOutputDir" -ForegroundColor Cyan
            }
        }
    } else {
        Write-Host "No plugin DLL found in any bin directory." -ForegroundColor Red
        exit 1
    }
}

# Step 2: Create the plugin directory if it doesn't exist
Write-Host "Creating plugin directory: $powerToysPluginDir" -ForegroundColor Cyan
New-Item -Path $powerToysPluginDir -ItemType Directory -Force | Out-Null
New-Item -Path "$powerToysPluginDir\Images" -ItemType Directory -Force | Out-Null

# Step 3: Copy files to the PowerToys Run plugins directory
Write-Host "Copying plugin files..." -ForegroundColor Cyan

# Function to safely copy files with retry logic when they're locked
function Safe-Copy-Item {
    param (
        [string]$Source,
        [string]$Destination,
        [string]$Description,
        [int]$MaxRetries = 3,
        [int]$RetryDelay = 2 # seconds
    )

    $retryCount = 0
    $copied = $false

    while (-not $copied -and $retryCount -lt $MaxRetries) {
        try {
            Copy-Item $Source $Destination -Force -ErrorAction Stop
            Write-Host "Copied $Description" -ForegroundColor Green
            $copied = $true
        }
        catch {
            $retryCount++
            if ($retryCount -lt $MaxRetries) {
                Write-Host "Cannot copy $Description - file is locked. Retrying in $RetryDelay seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $RetryDelay
            }
            else {
                Write-Host "Warning: Failed to copy $Description after $MaxRetries attempts. You may need to stop PowerToys first." -ForegroundColor Red
                $stopPowerToys = Read-Host "Do you want to stop PowerToys now and retry? (y/n)"
                if ($stopPowerToys -eq "y") {
                    Stop-Process -Name "PowerToys" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 3 # Give it time to fully close
                    
                    try {
                        Copy-Item $Source $Destination -Force -ErrorAction Stop
                        Write-Host "Copied $Description after stopping PowerToys" -ForegroundColor Green
                        $copied = $true
                    }
                    catch {
                        Write-Host "Error: Still cannot copy $Description. Please close PowerToys and try again." -ForegroundColor Red
                    }
                }
            }
        }
    }
    
    return $copied
}

# Main DLL - use safe copy
$mainDllCopied = Safe-Copy-Item `
    -Source "$buildOutputDir\Community.PowerToys.Run.Plugin.$projectName.dll" `
    -Destination $powerToysPluginDir `
    -Description "Community.PowerToys.Run.Plugin.$projectName.dll"

# Plugin.json - use safe copy
Safe-Copy-Item `
    -Source "$buildOutputDir\plugin.json" `
    -Destination $powerToysPluginDir `
    -Description "plugin.json"

#deps.json - use safe copy
Safe-Copy-Item `
    -Source "$buildOutputDir\Community.PowerToys.Run.Plugin.$projectName.deps.json" `
    -Destination $powerToysPluginDir `
    -Description "Community.PowerToys.Run.Plugin.$projectName.deps.json"

# Images - Create directory if needed and copy
if (-not (Test-Path "$powerToysPluginDir\Images")) {
    New-Item -Path "$powerToysPluginDir\Images" -ItemType Directory -Force | Out-Null
}

try {
    Copy-Item "$buildOutputDir\Images\*" "$powerToysPluginDir\Images\" -Force
    Write-Host "Copied image files" -ForegroundColor Green
}
catch {
    Write-Host "Warning: Could not copy image files. You may need to stop PowerToys first." -ForegroundColor Yellow
}

# After copying image files, verify they're valid
Write-Host "Verifying image files..." -ForegroundColor Cyan
$lightIconPath = "$powerToysPluginDir\Images\pluginicon.light.png"
$darkIconPath = "$powerToysPluginDir\Images\pluginicon.dark.png"

if (Test-Path $lightIconPath) {
    try {
        Add-Type -AssemblyName System.Drawing
        $image = [System.Drawing.Image]::FromFile($lightIconPath)
        $image.Dispose()
        Write-Host "✅ Light icon verified" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️ Light icon file exists but may be corrupt or invalid" -ForegroundColor Yellow
        # Try to recreate and copy the icon
        & "$PSScriptRoot\CreateSampleImages.ps1"
        Copy-Item "$projectDir\Images\pluginicon.light.png" $lightIconPath -Force
    }
}

if (Test-Path $darkIconPath) {
    try {
        Add-Type -AssemblyName System.Drawing
        $image = [System.Drawing.Image]::FromFile($darkIconPath)
        $image.Dispose()
        Write-Host "✅ Dark icon verified" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️ Dark icon file exists but may be corrupt or invalid" -ForegroundColor Yellow
        # Try to recreate and copy the icon
        & "$PSScriptRoot\CreateSampleImages.ps1"
        Copy-Item "$projectDir\Images\pluginicon.dark.png" $darkIconPath -Force
    }
}

# If main DLL couldn't be copied, warn the user
if (-not $mainDllCopied) {
    Write-Host "`n⚠️ WARNING: Could not copy the main plugin DLL. The plugin may not be updated correctly." -ForegroundColor Red
    Write-Host "Please stop PowerToys completely and run this script again." -ForegroundColor Red
}



Write-Host "`nVerifying plugin installation..." -ForegroundColor Cyan
$installedFiles = @(
    "$powerToysPluginDir\Community.PowerToys.Run.Plugin.$projectName.dll",
    "$powerToysPluginDir\Community.PowerToys.Run.Plugin.$projectName.deps.json",
    "$powerToysPluginDir\plugin.json",
    "$powerToysPluginDir\Images\pluginicon.light.png",
    "$powerToysPluginDir\Images\pluginicon.dark.png"
)

$allFilesExist = $true
foreach ($file in $installedFiles) {
    if (Test-Path $file) {
        Write-Host "✅ $file" -ForegroundColor Green
    } else {
        Write-Host "❌ $file" -ForegroundColor Red
        $allFilesExist = $false
    }
}

if (-not $allFilesExist) {
    Write-Host "`nSome plugin files are missing. Plugin may not work correctly." -ForegroundColor Red
}

# Create or update settings.json file to ensure the plugin is enabled
$powerToysSettingsDir = "$env:LOCALAPPDATA\Microsoft\PowerToys\PowerToys Run"
$settingsFile = "$powerToysSettingsDir\Settings.json"

if (Test-Path $settingsFile) {
    Write-Host "`nUpdating PowerToys Run settings to ensure plugin is enabled..." -ForegroundColor Cyan
    try {
        $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
        
        # Add our plugin to disabled plugins if not already present
        $pluginId = "5594ADCDFB534049A3060DCFAF3E9B01"
        $disabledPlugins = $settings.PluginSettings.DisabledPlugins

        if ($disabledPlugins -contains $pluginId) {
            $settings.PluginSettings.DisabledPlugins = $disabledPlugins | Where-Object { $_ -ne $pluginId }
            $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile
            Write-Host "Plugin was disabled. It has been enabled in the settings." -ForegroundColor Green
        } else {
            Write-Host "Plugin is already enabled in settings." -ForegroundColor Green
        }
    } catch {
        Write-Host "Could not modify settings file: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "Could not find PowerToys Run settings file. Make sure PowerToys Run has been launched at least once." -ForegroundColor Yellow
}

# Step 4: Check if PowerToys is running and handle startup/restart
$powerToysProcess = Get-Process "PowerToys" -ErrorAction SilentlyContinue
$powerToysShouldBeStarted = $true  # Set this to control whether PowerToys should be started

# Look for PowerToys.exe in the expected locations
$powerToysExePaths = @(
    "$env:LOCALAPPDATA\Microsoft\PowerToys\PowerToys.exe",  # Standard location
    "$env:LOCALAPPDATA\PowerToys\PowerToys.exe",            # Alternative location
    "C:\Program Files\PowerToys\PowerToys.exe",             # Possible installed location
    "C:\Program Files (x86)\PowerToys\PowerToys.exe"        # Another possible location
)

$powerToysExe = $powerToysExePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $powerToysExe) {
    Write-Host "Could not find PowerToys.exe in any of the expected locations." -ForegroundColor Red
    $customPath = Read-Host "Enter the path to PowerToys.exe or press Enter to skip starting PowerToys"
    if (-not [string]::IsNullOrWhiteSpace($customPath) -and (Test-Path $customPath)) {
        $powerToysExe = $customPath
    } else {
        $powerToysShouldBeStarted = $false
        Write-Host "PowerToys will not be started automatically." -ForegroundColor Yellow
    }
}

if ($powerToysProcess) {
    Write-Host "PowerToys is currently running." -ForegroundColor Yellow
    
    # If we already tried to stop PowerToys due to file locks, don't ask again
    if ($stopPowerToys -eq "y") {
        $restart = "y"
    } else {
        $restart = Read-Host "Do you want to restart PowerToys to load the new plugin? (y/n)"
    }
    
    if ($restart -eq "y") {
        Write-Host "Stopping PowerToys..." -ForegroundColor Cyan
        Stop-Process -Name "PowerToys" -Force
        
        # Wait a moment to ensure PowerToys fully closes
        Write-Host "Waiting for PowerToys to close completely..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        
        # Look for any remaining PowerToys processes
        $remainingProcesses = Get-Process | Where-Object { $_.Name -like "*PowerToys*" }
        if ($remainingProcesses) {
            Write-Host "Found remaining PowerToys processes. Attempting to close them..." -ForegroundColor Yellow
            $remainingProcesses | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
            Start-Sleep -Seconds 2
        }
        
        if ($powerToysShouldBeStarted -and $powerToysExe) {
            # Start PowerToys with correct path
            Write-Host "Starting PowerToys..." -ForegroundColor Cyan
            Start-Process $powerToysExe
            Write-Host "PowerToys started successfully." -ForegroundColor Green
        } else {
            Write-Host "Please start PowerToys manually to use the plugin." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Please restart PowerToys manually to load the plugin." -ForegroundColor Yellow
    }
} else {
    Write-Host "PowerToys is not running." -ForegroundColor Yellow
    
    if ($powerToysShouldBeStarted -and $powerToysExe) {
        $start = Read-Host "Do you want to start PowerToys now to use the plugin? (y/n)"
        
        if ($start -eq "y") {
            Write-Host "Starting PowerToys..." -ForegroundColor Cyan
            Start-Process $powerToysExe
            Write-Host "PowerToys started successfully." -ForegroundColor Green
        } else {
            Write-Host "You can start PowerToys manually later to use the plugin." -ForegroundColor Yellow
        }
    } else {
        Write-Host "You will need to start PowerToys manually to use the plugin." -ForegroundColor Yellow
    }
}

Write-Host "`nDeployment complete!" -ForegroundColor Green
Write-Host "Plugin is now available in PowerToys Run using the ':p' keyword." -ForegroundColor Green
Write-Host "Example usage: :p What is PowerToys Run?" -ForegroundColor Cyan

$pluginVisibilityCheck = @"

---------------------------------------------
TROUBLESHOOTING TIPS:
---------------------------------------------
1. Make sure PowerToys Run is enabled in PowerToys settings
2. Check if Plugin appears in PowerToys Run settings (Settings > PowerToys Run > Plugins)
3. If plugin is not visible, you may need to:
   - Clear PowerToys cache folder: %LOCALAPPDATA%\Microsoft\PowerToys\PowerToys Run\.cache
   - Make sure the Plugin ID in plugin.json matches the GUID in the AssemblyInfo.cs
   - Verify all required DLLs are properly copied

"@

Write-Host $pluginVisibilityCheck -ForegroundColor Yellow
