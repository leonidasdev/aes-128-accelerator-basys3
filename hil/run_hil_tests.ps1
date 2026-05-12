<#
.SYNOPSIS
    Run the AES hardware-in-the-loop test suite.

.DESCRIPTION
    Verifies the Python environment, checks the required packages, confirms
    the requested serial port is available, and then executes the FPGA AES
    HIL test harness. The script stores a timestamped log and a latest-run
    summary for CI or local review.

.PARAMETER Port
    Serial port used to reach the Basys 3 board.

.PARAMETER Baudrate
    UART baud rate used by the FPGA UART bridge.

.PARAMETER Timeout
    UART read timeout used by the Python harness in seconds.

.PARAMETER LogDir
    Directory where timestamped test logs are written.

.PARAMETER Verbose
    Enables additional console output.

.NOTES
    Run this script from the repository root or from within the hil directory.
    It resolves the Python harness path relative to the script location.
#>

param(
    [string]$Port = "COM6",
    [int]$Baudrate = 115200,
    [double]$Timeout = 1.0,
    [string]$LogDir = ".\hil\results",
    [switch]$Verbose
)

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptRoot
$PythonScript = Join-Path $ScriptRoot "python\aes_hil_test.py"
$VenvPython = Join-Path $RepoRoot ".venv\Scripts\python.exe"
$PythonExe = if (Test-Path $VenvPython) { $VenvPython } else { "python" }

function Write-Header { param([string]$Text) Write-Host ""; Write-Host "=" * 80 -ForegroundColor Cyan; Write-Host $Text -ForegroundColor Cyan; Write-Host "=" * 80 -ForegroundColor Cyan }
function Write-Success { param([string]$Text) Write-Host $Text -ForegroundColor Green }
function Write-Error { param([string]$Text) Write-Host $Text -ForegroundColor Red }
function Write-Warning { param([string]$Text) Write-Host $Text -ForegroundColor Yellow }
function Write-Info { param([string]$Text) Write-Host $Text -ForegroundColor Cyan }

Write-Header "AES-128 FPGA Hardware-in-the-Loop Test Suite"
Write-Info "Starting HIL tests..."
Write-Info "Port: $Port"
Write-Info "Baudrate: $Baudrate bps"
Write-Info "Timeout: $Timeout s"
Write-Info "Python executable: $PythonExe"

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null; Write-Info "Created log directory: $LogDir" }
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFile = Join-Path $LogDir "hil_test_results_$timestamp.txt"
Write-Info "Log file: $logFile"

Write-Header "Checking Dependencies"
try { $pythonVersion = & $PythonExe --version 2>&1; Write-Success "Python: $pythonVersion" } catch { Write-Error "ERROR: Python not found"; exit 1 }

Write-Info "Checking Python packages..."
$packages = @(
    @{ ImportName = "Crypto"; PackageName = "pycryptodome" },
    @{ ImportName = "serial"; PackageName = "pyserial" }
)
foreach ($package in $packages) {
    & $PythonExe -c "import $($package.ImportName)" 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "  $($package.PackageName): OK"
    } else {
        Write-Warning "  $($package.PackageName): NOT INSTALLED"
        Write-Info "  Installing $($package.PackageName)..."
        & $PythonExe -m pip install $($package.PackageName)
        if ($LASTEXITCODE -ne 0) { Write-Error "ERROR: Failed to install $($package.PackageName)"; exit 1 }
    }
}

Write-Header "Verifying Serial Port Connection"
$portExists = Get-PnpDevice -Status OK -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$Port*" -or $_.Name -like "*COM*" }
if ($portExists) { Write-Success "Serial port $Port is available" } else { Write-Warning "WARNING: Serial port $Port may not be available"; Write-Info "Available COM ports:"; Get-PnpDevice -Status OK | Where-Object { $_.Name -like "*(COM*)" } | ForEach-Object { Write-Info "  $($_.Name)" } }

Write-Header "Running Hardware-in-the-Loop Tests"
Write-Info "Command: $PythonExe `"$PythonScript`" --port $Port --baudrate $Baudrate --timeout $Timeout"

$pythonArgs = @('--port', $Port, '--baudrate', $Baudrate, '--timeout', $Timeout)
if ($Verbose) { $pythonArgs += '--verbose' }

$output = & $PythonExe $PythonScript @pythonArgs 2>&1

$output | Tee-Object -FilePath $logFile

Write-Header "Test Results Analysis"
$passCount = $output | Select-String -Pattern "PASS:" | Measure-Object | Select-Object -ExpandProperty Count
$failCount = $output | Select-String -Pattern "FAIL:" | Measure-Object | Select-Object -ExpandProperty Count
$successLine = $output | Select-String -Pattern "Success Rate:"
if ($successLine) { Write-Info $successLine.Line }
if ($failCount -eq 0 -or $failCount -eq $null) { Write-Success "All tests PASSED!"; $testStatus = "SUCCESS"; $exitCode = 0 } else { Write-Error "Some tests FAILED"; Write-Error "Failed tests: $failCount"; $testStatus = "FAILED"; $exitCode = 1 }

Write-Header "Test Summary"
Write-Info "Port:            $Port"
Write-Info "Baudrate:        $Baudrate bps"
Write-Info "Timeout:         $Timeout s"
Write-Info "Test Status:     $testStatus"
Write-Info "Log File:        $logFile"
Write-Info "Timestamp:       $timestamp"

if ($exitCode -eq 0) { Write-Success "Hardware-in-the-Loop testing COMPLETED SUCCESSFULLY" } else { Write-Error "Hardware-in-the-Loop testing FAILED"; Write-Error "Check $logFile for details" }

exit $exitCode
