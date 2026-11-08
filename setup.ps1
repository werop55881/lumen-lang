# Lumen Setup Wizard
# ==================
# A friendly, step-by-step installer for the Lumen programming language.
#
# Run this in PowerShell:
#   pwsh -NoProfile -ExecutionPolicy Bypass -File setup.ps1

$ErrorActionPreference = "Continue"

# Find where this script lives
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$lumenDir = Resolve-Path $scriptDir

# Helper to print section headers
function Write-Header($text) {
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host $text -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
}

# Helper for success messages
function Write-Success($text) {
    Write-Host ("✓ " + $text) -ForegroundColor Green
}

# Helper for info messages
function Write-Info($text) {
    Write-Host ("  " + $text) -ForegroundColor Gray
}

# ----------------------------------------------------------------------------
# Step 0: Welcome
# ----------------------------------------------------------------------------
Write-Host ""
Write-Host "  ╔═════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║                                       ║" -ForegroundColor Cyan
Write-Host "  ║   Welcome to Lumen! 🌟               ║" -ForegroundColor Cyan
Write-Host "  ║                                       ║" -ForegroundColor Cyan
Write-Host "  ║   A friendly programming language    ║" -ForegroundColor Cyan
Write-Host "  ║   that runs on PowerShell.          ║" -ForegroundColor Cyan
Write-Host "  ║                                       ║" -ForegroundColor Cyan
Write-Host "  ╚════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "This wizard will help you set up Lumen on your computer."
Write-Host "It should take less than 2 minutes."
Write-Host ""

# ----------------------------------------------------------------------------
# Step 1: Check PowerShell
# ----------------------------------------------------------------------------
Write-Header "Step 1 of 4 — Checking PowerShell"

$psVersion = $PSVersionTable.PSVersion
Write-Info "PowerShell version: $($psVersion.Major).$($psVersion.Minor)"

if ($psVersion.Major -ge 5) {
    Write-Success "PowerShell is ready to go."
} else {
    Write-Host "  ⚠ You have an older version of PowerShell." -ForegroundColor Yellow
    Write-Host "  Lumen works best with PowerShell 5.1 or newer." -ForegroundColor Yellow
    Write-Host "  Consider upgrading from the Microsoft Store."
    Write-Host ""
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Host "Setup cancelled." -ForegroundColor Yellow
        exit
    }
}

# ----------------------------------------------------------------------------
# Step 2: Choose install location
# ----------------------------------------------------------------------------
Write-Header "Step 2 of 4 — Choose install location"

Write-Host "Lumen files are currently at:"
Write-Info "$lumenDir"
Write-Host ""

$defaultInstall = Join-Path $env:USERPROFILE "Tools\lumen-lang"
Write-Host "Default install location:"
Write-Host "  $defaultInstall"
Write-Host ""
$installPath = Read-Host "Press Enter to accept, or type a new path"
if ($installPath -and $installPath.Trim() -ne "") {
    $installPath = $installPath.Trim()
} else {
    $installPath = $defaultInstall
}

# Expand ~ if used
if ($installPath.StartsWith("~")) {
    $installPath = $installPath.Replace("~", $env:USERPROFILE)
}

Write-Host ""
Write-Host "Lumen will be installed to:"
Write-Host "  $installPath"

# ----------------------------------------------------------------------------
# Step 3: Copy files
# ----------------------------------------------------------------------------
Write-Header "Step 3 of 4 — Copying files"

try {
    if (-not (Test-Path $installPath)) {
        New-Item -ItemType Directory -Path $installPath -Force | Out-Null
        Write-Info "Created folder: $installPath"
    }

    # Copy all Lumen files
    $files = @("lumen.ps1", "lumen.bat", "install.ps1", "README.md")
    foreach ($file in $files) {
        $src = Join-Path $lumenDir $file
        $dst = Join-Path $installPath $file
        if (Test-Path $src) {
            Copy-Item $src $dst -Force
            Write-Success "Copied $file"
        } else {
            Write-Host "  ⚠ $file not found, skipping." -ForegroundColor Yellow
        }
    }

    Write-Success "All files copied successfully."
} catch {
    Write-Host "  ✗ Error copying files: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Setup failed." -ForegroundColor Red
    exit 1
}

# ----------------------------------------------------------------------------
# Step 4: Add to PATH
# ----------------------------------------------------------------------------
Write-Header "Step 4 of 4 — Add to PATH (optional)"

Write-Host "Adding Lumen to your PATH lets you run 'lumen' from anywhere,"
Write-Host "without typing the full path."
Write-Host ""

$currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
$pathEntries = $currentPath -split ';'

$alreadyThere = $false
foreach ($entry in $pathEntries) {
    if ($entry.Trim() -eq $installPath) {
        $alreadyThere = $true
        break
    }
}

if ($alreadyThere) {
    Write-Success "Lumen is already in your PATH."
} else {
    $addPath = Read-Host "Add Lumen to your PATH? (y/n)"
    if ($addPath -eq "y" -or $addPath -eq "Y") {
        $newPath = if ($currentPath) { "$currentPath;$installPath" } else { $installPath }
        [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)
        Write-Success "Added to PATH. Open a NEW PowerShell window to use 'lumen' from anywhere."
    } else {
        Write-Host "Skipped. You can still run Lumen with:" -ForegroundColor Gray
        Write-Host "  pwsh -NoProfile -ExecutionPolicy Bypass -File `"$installPath\lumen.ps1`" script.ln" -ForegroundColor Gray
    }
}

# ----------------------------------------------------------------------------
# Step 5: Test run
# ----------------------------------------------------------------------------
Write-Header "Step 5 of 5 — Test Lumen"

$testFile = Join-Path $installPath "test.ln"
Set-Content $testFile "print 'Lumen is working!';`nprint 2 + 3;`n" -Encoding UTF8

Write-Host "Running a quick test..."
Write-Host ""

try {
    $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File "$installPath\lumen.ps1" $testFile 2>&1
    foreach ($line in $output) {
        Write-Host "  $line"
    }
    Write-Success "Lumen is working!"
} catch {
    Write-Host "  ✗ Test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Clean up test file
if (Test-Path $testFile) {
    Remove-Item $testFile -Force
}

# ----------------------------------------------------------------------------
# Done
# ----------------------------------------------------------------------------
Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "  Setup complete! 🎉" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""
Write-Host "Your Lumen files are at:"
Write-Host "  $installPath"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Create a file called 'hello.ln' with this content:"
Write-Host "     print 'Hello, Lumen!';"
Write-Host ""
Write-Host "  2. Run it:"
Write-Host "     pwsh -NoProfile -ExecutionPolicy Bypass -File `"$installPath\lumen.ps1`" hello.ln"
Write-Host ""
if (-not $alreadyThere -and ($addPath -eq "y" -or $addPath -eq "Y")) {
    Write-Host "  3. (Or open a new PowerShell window and just type:)"
    Write-Host "     lumen hello.ln"
}
Write-Host ""
Write-Host "For more examples, open README.md in the Lumen folder."
Write-Host ""
Write-Host "Happy coding with Lumen! 🚀" -ForegroundColor Cyan
Write-Host ""
