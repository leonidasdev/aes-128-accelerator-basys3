<#
.SYNOPSIS
    Setup Python virtual environment for AES-128 HIL development.

.DESCRIPTION
    Creates a Python virtual environment, activates it, and installs
    required dependencies (pycryptodome, pyserial) for HIL testing.

.NOTES
    Run from the repository root directory.
    Requires Python 3.7+ in PATH.

.EXAMPLE
    .\setup_venv.ps1
#>

param(
    [switch]$Force
)

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$VenvPath = Join-Path $RepoRoot ".venv"
$RequirementsFile = Join-Path $RepoRoot "requirements.txt"
$PythonExe = if (Test-Path (Join-Path $VenvPath "Scripts\python.exe")) {
    Join-Path $VenvPath "Scripts\python.exe"
} else {
    "python"
}

Write-Host ""
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "AES-128 HIL Virtual Environment Setup" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

# Check if venv already exists
if ((Test-Path $VenvPath) -and -not $Force) {
    Write-Host "✓ Virtual environment already exists at $VenvPath" -ForegroundColor Green
    Write-Host "  To recreate, run: .\setup_venv.ps1 -Force" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Activating existing environment..." -ForegroundColor Cyan
    & (Join-Path $VenvPath "Scripts\Activate.ps1")
    Write-Host ""
    Write-Host "Environment activated. Installing/upgrading dependencies..." -ForegroundColor Cyan
    & $PythonExe -m pip install -q --upgrade pip
    & $PythonExe -m pip install -r $RequirementsFile
    Write-Host "✓ Dependencies installed" -ForegroundColor Green
    Write-Host ""
    return
}

# Create new venv
Write-Host "Creating virtual environment..." -ForegroundColor Cyan
try {
    & python -m venv $VenvPath
    Write-Host "✓ Virtual environment created" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to create virtual environment" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}

# Activate venv
Write-Host "Activating virtual environment..." -ForegroundColor Cyan
& (Join-Path $VenvPath "Scripts\Activate.ps1")
Write-Host "✓ Virtual environment activated" -ForegroundColor Green

# Upgrade pip
Write-Host "Upgrading pip..." -ForegroundColor Cyan
& $PythonExe -m pip install -q --upgrade pip
Write-Host "✓ pip upgraded" -ForegroundColor Green

# Install dependencies
Write-Host "Installing dependencies..." -ForegroundColor Cyan
if (Test-Path $RequirementsFile) {
    & $PythonExe -m pip install -r $RequirementsFile
    Write-Host "✓ Dependencies installed" -ForegroundColor Green
} else {
    Write-Host "✗ requirements.txt not found" -ForegroundColor Red
    exit 1
}

# Verify installation
Write-Host "Verifying installation..." -ForegroundColor Cyan
& $PythonExe -c "import Crypto; print('  ✓ pycryptodome available')" 2>$null
& $PythonExe -c "import serial; print('  ✓ pyserial available')" 2>$null

Write-Host ""
Write-Host "=" * 80 -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Verify HIL setup:  python hil/hil_verify.py" -ForegroundColor Gray
Write-Host "  2. Run HIL tests:     .\hil\run_hil_tests.ps1 -Port COM3" -ForegroundColor Gray
Write-Host ""
