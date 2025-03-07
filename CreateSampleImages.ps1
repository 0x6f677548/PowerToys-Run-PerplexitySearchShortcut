# Create sample PNG files only if they don't exist
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$imageDir = Join-Path $PSScriptRoot "Images"
New-Item -ItemType Directory -Force -Path $imageDir | Out-Null

function Create-SamplePNG {
    param (
        [string]$path,
        [string]$color
    )
    
    # Only create the image if it doesn't exist
    if (-not (Test-Path $path)) {
        # Create a simple colored PNG using .NET
        $bitmap = New-Object System.Drawing.Bitmap 32, 32
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        
        # Fill with color
        $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromName($color))
        $graphics.FillRectangle($brush, 0, 0, 32, 32)
        
        # Draw a 'P' letter
        $font = New-Object System.Drawing.Font("Arial", 18, [System.Drawing.FontStyle]::Bold)
        $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $graphics.DrawString("P", $font, $textBrush, 8, 2)
        
        # Save the bitmap
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        
        $graphics.Dispose()
        $bitmap.Dispose()
        
        Write-Host "Created icon at $path" -ForegroundColor Green
    } else {
        Write-Host "Icon file already exists at $path" -ForegroundColor Yellow
    }
}

Create-SamplePNG -path "$imageDir\pluginicon.dark.png" -color "Black"
Create-SamplePNG -path "$imageDir\pluginicon.light.png" -color "Gray"

# Verify the files exist
if ((Test-Path "$imageDir\pluginicon.light.png") -and (Test-Path "$imageDir\pluginicon.dark.png")) {
    Write-Host "Icon files exist and are ready to use." -ForegroundColor Green
} else {
    Write-Host "Failed to verify icon files!" -ForegroundColor Red
}
