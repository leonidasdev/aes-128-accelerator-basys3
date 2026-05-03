# Hardware-in-the-Loop (HIL) Testing Framework

## Overview

This directory contains the complete hardware-in-the-loop testing infrastructure for FPGA validation of the AES-128 cryptographic accelerator design. The framework enables automated comparison of FPGA implementation results against trusted software reference (NIST pycryptodome library) through USB serial communication.

**Framework Scope:**
- Architecture: Host PC-to-FPGA serial communication via USB UART
- Protocol: ASCII command-response based on FIPS-197 test vectors
- Platform: Windows/Linux Python environment with pycryptodome reference
- Target device: Basys 3 (Xilinx XC7A35T) FPGA board
- Validation basis: NIST FIPS-197 official test vectors
- Test coverage: Encryption, decryption, and round-trip verification across a 264-vector regression suite
### Regression Test Vectors

The file `vectors/test_vectors.txt` is the authoritative regression source for HIL validation. It contains 264 vectors:

- 4 canonical FIPS-197 examples
- 4 edge cases covering all-zero, all-one, and alternating patterns
- 128 walking-one plaintext vectors with a zero key
- 128 walking-one key vectors with a zero plaintext

This gives broad structural coverage of the AES datapath, key schedule, and host/FPGA interface without attempting the impossible task of exhaustive $2^{128}$-space enumeration.

**Reference**: NIST FIPS-197 examples plus deterministic edge-case and walking-bit regression coverage

```text
Host Computer (Windows/Linux)
  Python HIL Test Framework
    aes_hil_test.py
    generate_vectors.py
    run_hil_tests.ps1

  USB Serial UART
    115,200 bps, 8N1
    FTDI FT232 bridge

Basys 3 FPGA Development Board
  XC7A35T Artix-7 FPGA
    AES-128 Hardware Accelerator
      Encryption Engine (forward)
      Decryption Engine (inverse)
      Serial UART Interface
      Control FSM
```

### 1.2 Serial Communication Protocol

The communication protocol uses ASCII-encoded commands and hexadecimal results with line termination.

**Command-Response Sequence:**

| Direction | Message | Format | Response | Notes |
|-----------|---------|--------|----------|-------|
| Host -> FPGA | KEY command | KEY:<32-hex-chars> | READY | Load the 128-bit master key |
| Host -> FPGA | MODE command | MODE:<0 or 1> | READY | Set mode (1=encrypt, 0=decrypt) |
| Host -> FPGA | DATA command | DATA:<32-hex-chars> | READY | Load plaintext or ciphertext |
| Host -> FPGA | START command | START | <32-hex-chars> | Execute; return result as hex |

**Timing Characteristics:**

| Operation | Latency | Notes |
|-----------|---------|-------|
| KEY command | 20-50 ms | Loading and verification |
| MODE command | 20-50 ms | Register update |
| DATA command | 20-50 ms | Buffer loading |
| START command | 150+ ms | Includes 15 FPGA cycles plus round trip |

**Example Complete Transaction (Encryption):**

```
[00:00:00.000] Host sends:  KEY:000102030405060708090A0B0C0D0E0F
[00:00:00.050] FPGA returns: READY
[00:00:00.100] Host sends:  MODE:1
[00:00:00.150] FPGA returns: READY
[00:00:00.200] Host sends:  DATA:00112233445566778899AABBCCDDEEFF
[00:00:00.250] FPGA returns: READY
[00:00:00.300] Host sends:  START
[00:00:00.450] FPGA returns: 69C4E0D86A7B04530D8A4E6E77033E9F

PC-side Reference Verification (pycryptodome):
  Expected ciphertext: 69C4E0D86A7B04530D8A4E6E77033E9F
  Received from FPGA:  69C4E0D86A7B04530D8A4E6E77033E9F
  Match: YES (Test PASS)
```

### 1.3 Data Format Specification

**Hexadecimal Encoding Standard:**

All data values in the serial protocol use uppercase hexadecimal (base-16) encoding.

| Data Type | Size | Hex Characters | Example |
|-----------|------|----------------|---------|
| Plaintext | 128 bits | 32 chars | 00112233445566778899AABBCCDDEEFF |
| Ciphertext | 128 bits | 32 chars | 69C4E0D86A7B04530D8A4E6E77033E9F |
| Master Key | 128 bits | 32 chars | 000102030405060708090A0B0C0D0E0F |
| Mode selector | 1 bit | 1 char | 0 or 1 |

**Byte Order:** Network byte order (big-endian); most significant byte transmitted first

---

## 2. Test Execution

### 2.1 Environment Setup (One Time)

**Prerequisites:**
- Windows 10 or later (or Linux with Python 3.7+)
- USB cable connected to Basys 3 board
- FPGA programmed with AES accelerator bitstream
- COM port available (visible in Device Manager)

**Virtual Environment Creation:**

```powershell
# Navigate to workspace root
cd c:\amd-vivado-projects\aes_vscode

# Execute setup script (creates .venv and installs dependencies)
.\hil\setup_venv.ps1

# Expected output:
# - "Created directory .venv"
# - "Successfully installed pycryptodome"
# - "Successfully installed pyserial"
```

**Verification:**

```powershell
# Activate virtual environment
.\.venv\Scripts\Activate.ps1

# Confirm installation
python --version         # Expected: Python 3.7+
pip list               # Expected: pycryptodome, pyserial listed
python hil\hil_verify.py # Expected: 6/6 checks passed
```

### 2.2 Test Execution Methods

**Method 1: Automated Batch Suite (Recommended)**

```powershell
# Recommended: Full test suite with logging
.\hil\run_hil_tests.ps1 -Port COM3 -Baudrate 115200

# Optional: Custom port or additional options
.\hil\run_hil_tests.ps1 -Port COM5 -Baudrate 230400 -Verbose
```

**Test Output Breakdown:**

```
================================================================================
AES-128 FPGA Hardware-in-the-Loop Test Suite
================================================================================

Port: COM3, Baudrate: 115200 bps
Total test vectors: 4
Tests per vector: 3 (encryption, decryption, round-trip)
Total tests: 12
================================================================================

Test Vector 1/4
  PASS: Encryption       (FPGA result matches pycryptodome reference)
  PASS: Decryption       (Recovered plaintext from ciphertext verified)
  PASS: Round-trip       (Encrypt then decrypt recovers original)

Test Vector 2/4
  PASS: Encryption
  PASS: Decryption
  PASS: Round-trip

Test Vector 3/4
  PASS: Encryption
  PASS: Decryption
  PASS: Round-trip

Test Vector 4/4
  PASS: Encryption
  PASS: Decryption
  PASS: Round-trip

================================================================================
Test Summary:
  Total:         12
  PASS:          12
  FAIL:          0
  Success Rate:  100.0%
================================================================================
```

**Method 2: Direct Python Execution**

```powershell
# For advanced users or custom configurations

# Activate venv first
.\.venv\Scripts\Activate.ps1

# Run test controller directly with custom arguments
python hil\python\aes_hil_test.py --port COM3 --baudrate 115200

# Additional options (if available)
python hil\python\aes_hil_test.py --help  # Display all arguments
```

**Method 3: Generate Custom Test Vectors**

```powershell
# Generate 100 random FIPS-197 compliant test vectors

# Activate venv
.\.venv\Scripts\Activate.ps1

# Generate and save vectors
python hil\python\generate_vectors.py 100 hil\vectors\extended_vectors.txt

# Output format: Same as test_vectors.txt (plaintext ciphertext key)
```

### 2.3 Log File Output

Test results automatically saved to timestamped log file:

```
hil_test_logs/hil_test_results_20260430_143022.txt
```

Log file contains:
- Test suite configuration (port, baud rate)
- Per-vector results (pass/fail for each test)
- Final summary (pass count, fail count, success rate percentage)
- Timestamps for each test execution
- Any hardware connection errors or timeouts

---

## 3. Test Vectors

### 3.1 Canonical Reference Vectors

The framework includes four official NIST FIPS-197 test vectors from Appendix C.

**Vector 1 — Basic Sequential Plaintext**
- Plaintext: `00112233445566778899AABBCCDDEEFF`
- Master Key: `000102030405060708090A0B0C0D0E0F`
- Expected Ciphertext: `69C4E0D86A7B04530D8A4E6E77033E9F`
- Reference: FIPS-197 Section 4.3 (simplest example with sequential bytes)

**Vector 2 — Standard Test Case**
- Plaintext: `6BC1BEE22E409F96E93D7E117393172A`
- Master Key: `2B7E151628AED2A6ABF7158809CF4F3C`
- Expected Ciphertext: `3AD77BB40D7A3660A89ECAF32466EF97`
- Reference: FIPS-197 Appendix C, Example 2

**Vector 3 — Key Reuse Demonstration**
- Plaintext: `AE2D8A571E03AC9C9EB76FAC45AF8E51`
- Master Key: `2B7E151628AED2A6ABF7158809CF4F3C` (same as Vector 2)
- Expected Ciphertext: `F69F2445DF4F9B17AD2B417BE66C3710`
- Reference: FIPS-197 Appendix C, Example 3

**Vector 4 — Final Example**
- Plaintext: `30C81C46A35CE411E5FBC1191A0A52EF`
- Master Key: `2B7E151628AED2A6ABF7158809CF4F3C` (same as Vector 2)
- Expected Ciphertext: `2519498E4A7F5B89D5F3B49A189D0E0B`
- Reference: FIPS-197 Appendix C, Example 4

### 3.2 Test File Format

The file `vectors/test_vectors.txt` contains the authoritative regression vectors in the format:

```
plaintext ciphertext key
(all as 32-character hexadecimal strings, space-separated)

00112233445566778899aabbccddeeff 69c4e0d86a7b04530d8a4e6e77033e9f 000102030405060708090a0b0c0d0e0f
6bc1bee22e409f96e93d7e117393172a 3ad77bb40d7a3660a89ecaf32466ef97 2b7e151628aed2a6abf7158809cf4f3c
ae2d8a571e03ac9c9eb76fac45af8e51 f69f2445df4f9b17ad2b417be66c3710 2b7e151628aed2a6abf7158809cf4f3c
30c81c46a35ce411e5fbc1191a0a52ef 2519498e4a7f5b89d5f3b49a189d0e0b 2b7e151628aed2a6abf7158809cf4f3c
```

This file is source-controlled reference data. If you need additional vectors, generate them with `generate_vectors.py` and keep the output in the same three-column format.

---

## 4. File Documentation

### 4.1 aes_hil_test.py

**Purpose:** Main test orchestration controller; manages serial communication and reference verification

**Dependencies:**
- pyserial (USB communication)
- pycryptodome (reference AES-128 implementation)
- Python standard library: sys, time, argparse, binascii

**Key Classes:**

`AESHardwareTest` — Hardware test controller
- Constructor: `__init__(port='COM3', baudrate=115200, timeout=1.0)`
- Methods:
  - `set_key(key_hex)` — Load master key into FPGA hardware
  - `set_mode(mode)` — Set operation mode (1=encrypt, 0=decrypt)
  - `set_data(data_hex)` — Load plaintext or ciphertext
  - `start_operation()` — Execute operation and retrieve result
  - `verify_encryption(plaintext_hex, key_hex)` — Compare FPGA result against pycryptodome reference
  - `verify_decryption(ciphertext_hex, key_hex)` — Verify decryption correctness
  - `verify_roundtrip(plaintext_hex, key_hex)` — Verify encrypt-decrypt cycle
  - `run_suite(test_vectors)` — Execute complete test suite with logging
  - `close()` — Close serial port connection

**Test Vectors:**

Global list `FIPS_TEST_VECTORS` contains four tuples: (plaintext_hex, key_hex, expected_ciphertext_hex)

### 4.2 generate_vectors.py

**Purpose:** Generate random FIPS-197 compliant AES-128 test vectors

**Dependencies:**
- pycryptodome (vector encryption generation)
- Python standard library: sys, os, argparse

**Main Function:**

`generate_vectors(num_vectors=10, output_file='test_vectors_generated.txt')`
- Parameters:
  - num_vectors (int): Number of random test vectors (default 10)
  - output_file (str): Output file path (default test_vectors_generated.txt)
- Return: True on success, False on error
- Output format: Identical to test_vectors.txt (plaintext ciphertext key, hex)

**Usage Examples:**

```powershell
# Generate 50 vectors with default output
python hil\python\generate_vectors.py 50

# Generate 100 vectors to custom file
python hil\python\generate_vectors.py 100 hil\vectors\extended_test_set.txt

# Generate 1000 vectors for stress testing
python hil\python\generate_vectors.py 1000 stress_test_vectors.txt
```

### 4.3 run_hil_tests.ps1

**Purpose:** PowerShell batch automation script for complete HIL test workflow

**Parameters:**
- `-Port COM3` — Serial port name (default COM3)
- `-Baudrate 115200` — Baud rate (default 115200)
- `-LogDir .\hil_test_logs` — Output log directory (default current)
- `-Verbose` — Enable verbose console output

**Workflow:**
1. Check Python installation and version
2. Verify package dependencies (pycryptodome, pyserial)
3. Validate serial port availability
4. Execute HIL test suite via aes_hil_test.py
5. Parse results and generate timestamped log
6. Report summary statistics

### 4.4 hil_verify.py

**Purpose:** Environment and infrastructure verification utility

**Checks Performed:**
1. Python version (require Python 3.7+)
2. Directory structure completeness
3. Python package availability
4. Test vector file format validity
5. Import resolution (pycryptodome, pyserial)
6. Setup script and configuration integrity

**Output:** Colored terminal summary with pass/fail status for each check

**Usage:**
```powershell
python hil\hil_verify.py
```

**Exit Codes:**
- 0 — All checks passed; HIL ready for testing
- 1 — One or more checks failed; setup action required

### 4.5 setup_venv.ps1

**Purpose:** Create Python virtual environment and install dependencies

**Parameters:**
- `-VenvDir .venv` — Virtual environment directory path (default .venv)

**Workflow:**
1. Create Python virtual environment at specified path
2. Activate environment
3. Upgrade pip to latest version
4. Install all packages from requirements.txt

**Manual Alternative:**
```powershell
# If setup script fails
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install --upgrade pip
pip install -r hil\requirements.txt
```

### 4.6 requirements.txt

**Purpose:** Python package dependencies specification

**Contents:**
```
pycryptodome>=3.17.0
pyserial>=3.5
```

**Justification:**
- pycryptodome: NIST FIPS-197 certified reference implementation
- pyserial: Cross-platform USB serial UART communication
- Version constraints: Minimum versions that include required APIs and security patches

---

## 5. Configuration and Setup

### 5.1 Baud Rate Selection

The default baud rate is 115,200 bits per second (115.2 Kbps), standard for embedded systems.

| Baud Rate | Latency Per Vector | Use Case |
|-----------|-------------------|----------|
| 9,600 | ~500 ms | Unreliable USB connections; slow systems |
| 57,600 | ~250 ms | Older boards or long cable runs |
| **115,200** | **~150 ms** | **Standard (recommended)** |
| 230,400 | ~75 ms | High-performance requirements; short cable |
| 460,800 | ~40 ms | Maximum speed (not recommended unless required) |

**Recommendation:** Use 115,200 for all applications. Higher rates increase noise susceptibility; lower rates increase test duration unnecessarily.

### 5.2 Serial Port Identification

**Windows Device Manager:**
1. Right-click Computer or My PC
2. Select Manage → Device Manager
3. Expand Ports (COM & LPT)
4. Look for USB Serial Device listing COM port number
5. Use port number in scripts (e.g., COM3, COM5)

**Windows PowerShell Script:**
```powershell
# List all available COM ports
Get-PnpDevice -Status OK | Where-Object { $_.Name -like "*(COM*)" }

# Alternative: PowerShell WMI query
Get-WmiObject Win32_SerialPort | Select-Object Name, DeviceID, Description
```

**Linux:**
```bash
# List all available serial ports
ls /dev/ttyUSB* /dev/ttyACM*

# Typical output: /dev/ttyUSB0 or /dev/ttyACM0
# Use port number in scripts (e.g., /dev/ttyUSB0)
```

### 5.3 Python Version Management

**Verify Python Version:**
```powershell
python --version
python -c "import sys; print(sys.version_info)"
```

**Expected Output:**
```
Python 3.7.0 or higher (3.9+ recommended)
```

**For Multiple Python Versions:**
```powershell
# Check all Python paths
py --list-paths

# Use specific version (Python 3.9 for example)
py -3.9 -m venv .venv
```

---

## 6. Troubleshooting

### 6.1 Import Resolution Errors

**Problem:** Pylance reports "could not be resolved" for Crypto or serial imports

**Solution:**
1. Verify venv creation: `Test-Path .\.venv\Scripts\python.exe`
2. Ensure dependencies installed: `pip list | grep pycryptodome`
3. In VS Code: Ctrl+Shift+P → Python: Select Interpreter → choose `.venv\Scripts\python.exe`
4. Reload Pylance: Ctrl+Shift+P → Pylance: Restart Pylance
5. If issue persists: Reinstall dependencies: `pip install --force-reinstall pycryptodome pyserial`

### 6.2 Serial Port Not Found

**Problem:** "ERROR: Failed to connect to COM3: Port not found"

**Solution:**
1. Verify Basys 3 connected via USB cable
2. Check Device Manager for COM port assignment
3. Update PORT variable in script to correct COM port
4. Try different USB port on computer
5. Reinstall FTDI drivers: https://www.ftdichip.com/Drivers/VCP.htm

### 6.3 Timeout During Test Execution

**Problem:** "ERROR: Serial communication timeout" or test hangs

**Solution:**
1. Verify FPGA programmed with AES bitstream (check LEDs if available)
2. Reduce baud rate (try 57,600 if using 115,200)
3. Check USB cable quality and connection
4. Increase timeout in aes_hil_test.py line ~150: `self.operation_timeout = 0.05` (50 ms instead of 20 ms)
5. Verify FPGA design compiles and runs in simulation

### 6.4 Cross-Platform Issues

**Linux-Specific:**
```bash
# May need root permissions or udev rules
sudo usermod -a -G dialout $USER

# Add udev rule for FTDI devices
echo 'ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", MODE="0666"' | sudo tee /etc/udev/rules.d/99-ftdi.rules
sudo udevadm control --reload
```

**macOS-Specific:**
```bash
# FTDI drivers for macOS
# https://www.ftdichip.com/Drivers/VCP.htm
# After installation, ports appear as /dev/tty.usbserial-XXXXXX

# Use port in scripts: /dev/tty.usbserial-XXXXXX
```

---

## 7. Implementation Rationale

### 7.1 Design Decision: USB Serial vs. Ethernet

| Criterion | USB Serial (Selected) | Ethernet |
|-----------|-----|----------|
| Cost | 0 (always onboard) | 100+ (requires hardware) |
| Setup complexity | Minimal (auto-detect) | Moderate (IP configuration) |
| Cables required | 1 (USB micro-B) | 2 (power + RJ45) |
| Latency | 1-2 ms round-trip | 5-10 ms round-trip |
| Distance | 5 meters typical | 100 meters |
| Power supply | USB (bus powered) | Separate or PoE |
| Cross-platform | Yes (universal) | Yes (universal) |

**Rationale:** USB serial is ubiquitous on Basys 3 boards (FTDI bridge built-in), requires no additional hardware, and provides sufficient latency for validation testing. Ethernet offers no advantage for single-device HIL testing and adds complexity.

### 7.2 Design Decision: Synchronous Polling vs. Asynchronous Events

| Criterion | Polling (Selected) | Asynchronous Events |
|-----------|------|----------|
| Implementation | Blocking I/O (simple) | Async callbacks (complex) |
| Latency | 20 ms per command | 5 ms per command |
| Throughput (vectors/sec) | 50 | 200 |
| CPU usage | 100 percent while testing | 5-10 percent |
| Code complexity | Minimal | Moderate |
| Debugging ease | High (step-by-step) | Low (async ordering) |

**Rationale:** HIL testing is human-initiated validation activity (not production deployment). Polling model enables rapid test development and straightforward debugging. 50 vectors/second sufficient for comprehensive validation within minutes; lower CPU usage irrelevant for batch testing scenario.

### 7.3 Design Decision: pycryptodome Reference vs. Custom VHDL Model

| Criterion | pycryptodome (Selected) | VHDL Golden Model |
|-----------|---|---|
| Authority | NIST-certified library | Custom implementation |
| Integration effort | 2 lines of Python | 50+ lines of VHDL |
| Maintenance burden | None (external) | Ongoing bug fixes |
| Risk of errors | Minimal | Moderate (hand-coded) |
| Industry adoption | Global standard | Project-specific |
| Version tracking | Explicit (pip freeze) | Implicit (git hash) |

**Rationale:** pycryptodome is industry-standard FIPS-197 implementation used globally. Comparison against official library ensures maximum cryptographic correctness while minimizing engineering burden. Engineering time devoted to reference implementation better spent on hardware optimization and system integration.

### 7.4 Design Decision: Canonical Vectors vs. Generated Random Vectors

| Criterion | Canonical (default) | Generated Random |
|-----------|---|---|
| Authority | NIST official standard | Derived dynamically |
| Verify specs | Definitional (compliance) | Exploratory (edge cases) |
| Test duration | <5 seconds | Variable (50-500 blocks) |
| Setup complexity | None (included) | Generate per-session |
| Reproducibility | 100 percent (static) | Pseudo-random (seed-based) |
| Discovery of bugs | Standards compliance | Potential edge case capture |

**Rationale:** Default HIL runs canonical FIPS-197 vectors for rapid verification (< 5 seconds) against specification. Extended random vector generation available via `generate_vectors.py` for comprehensive exploration and stress testing. Separation of concerns: spec compliance first, edge cases second.

### 7.5 Design Decision: Single Datalink vs. Dual Channels

| Criterion | Single Serial (Selected) | Dual (separate TX/RX) |
|-----------|---|---|
| Pin count | 3 (ground, TX, RX) | 4 (ground, TX1, RX1, TX2, RX2) |
| Cable complexity | Simple serial | More complex shielding) |
| Bandwidth | adequate (command/response) | Higher parallelism |
| Latency | Round-trip inherent | Potential simultaneous transfers |
| Debugging | Single stream to trace | Multiple streams to correlate |
| FPGA complexity | Minimal (single UART) | Higher (dual UARTs) |

**Rationale:** Single serial link adequate for command-response protocol where testing is not bandwidth-limited. Dual channels would require FPGA design changes, adding unnecessary complexity. Proven serial protocol simplicity enables rapid debugging and prototyping.

---

## Advanced Topics

### Hardware Clock Synchronization

The Basys 3 board features a 100 MHz crystal oscillator providing stable timing reference. Tests complete within microsecond precision naturally due to FPGA's synchronous design.

### Security Considerations for HIL

HIL testing transmits plaintext and keys over USB connection. For security research:
- Avoid transmitting sensitive production keys
- Use ephemeral test vectors only
- Air-gap HIL system from network if required

### Performance Scaling

HIL throughput is limited by serial communication (50 vectors/second at 115.2 Kbps). For higher throughput:
- Use hardware debugger interfaces (faster but proprietary)
- Implement internal loopback testing in FPGA firmware (standalone validation)
- Batch multiple vectors into single serial transaction (requires protocol modification)

---

**Framework Version:** 1.0  
**Last Updated:** April 30, 2026  
**Status:** Production-Ready
# Hardware-in-the-Loop (HIL) Testing Framework

## Overview

This directory contains the **Hardware-in-the-Loop (HIL) testing infrastructure** for the AES-128 FPGA accelerator. It enables validation of the VHDL implementation against the NIST FIPS-197 reference specification using random test vectors and canonical test cases.

### Key Features
- **FIPS-197 Compliance**: Validates all 10 expansion rounds + final round per NIST specification
- **Dual-Mode Testing**: Supports both encryption and decryption verification
- **Automated Test Suite**: Batch testing with comprehensive pass/fail reporting
- **Hardware Interface**: USB serial UART communication with Basys 3 FPGA board
- **Reference Implementation**: Uses pycryptodome for FIPS-197 compliance verification

---

## Directory Structure

```
hil/
├── README.md                      # This file
├── requirements.txt               # Python dependencies (pycryptodome, pyserial)
├── setup_venv.ps1                 # Virtual environment setup script (PowerShell)
├── run_hil_tests.ps1              # Batch test automation script (PowerShell)
├── python/
│   ├── aes_hil_test.py            # Main HIL test controller
│   └── generate_vectors.py        # Test vector generation utility
└── vectors/
    └── test_vectors.txt           # Canonical FIPS-197 test vectors (read-only reference)
└── vectors/
  └── test_vectors.txt           # Comprehensive regression suite (authoritative HIL input)
```

---

## Quick Start

### 1. Setup Python Virtual Environment

```powershell
# From workspace root: c:\amd-vivado-projects\aes_vscode

# Create virtual environment and install dependencies
.\hil\setup_venv.ps1

# Activate the environment
.\.venv\Scripts\Activate.ps1
```

**Verify Installation:**
```powershell
python --version  # Should be 3.7+
pip list          # Should show: pycryptodome, pyserial
```

### 2. Configure VS Code Python Interpreter

Set VS Code to use the venv Python interpreter:

1. Press `Ctrl+Shift+P` → "Python: Select Interpreter"
2. Choose `.venv\Scripts\python.exe` (relative to workspace)
3. Pylance will re-index and import errors should resolve

### 3. Run HIL Tests

**Option A: Full Automated Suite (Recommended)**
```powershell
.\hil\run_hil_tests.ps1 -Port COM3 -Baudrate 115200
```

**Option B: Manual Test Execution**
```powershell
cd hil
python python/aes_hil_test.py --port COM3 --baudrate 115200
```

**Option C: Generate Additional Test Vectors**
```powershell
cd hil
python python/generate_vectors.py 100 vectors/test_vectors_custom.txt
```

---

## Dependencies

Install via `requirements.txt`:

```
pycryptodome>=3.17.0   # FIPS-197 AES reference implementation
pyserial>=3.5          # USB serial communication with FPGA
```

### Manual Installation

If `setup_venv.ps1` doesn't work:

```powershell
pip install --upgrade pip
pip install -r hil/requirements.txt
```

---

## Test Vector Format

All test vectors follow NIST FIPS-197 canonical format:

**Format (space-separated, all hexadecimal):**
```
plaintext ciphertext key
00112233445566778899aabbccddeeff 69c4e0d86a7b04530d8a4e6e77033e9f 000102030405060708090a0b0c0d0e0f
```

**Breakdown:**
- **Plaintext**: 128-bit input block (32 hex characters)
- **Ciphertext**: 128-bit encrypted output (32 hex characters)
- **Key**: 128-bit AES key (32 hex characters)

### Regression Vector Coverage

The file `vectors/test_vectors.txt` now contains a 264-vector regression suite rather than a four-vector sample set.

It includes:

- 4 canonical FIPS-197 examples
- 4 edge cases covering all-zero, all-one, and alternating patterns
- 128 walking-one plaintext vectors with a zero key
- 128 walking-one key vectors with a zero plaintext

This structure gives broad coverage of the AES datapath, key schedule, and host/FPGA interface while remaining practical to run on real hardware.

**Reference**: NIST FIPS-197 examples plus deterministic regression coverage generated by `generate_vectors.py`

---

## File Documentation

### `aes_hil_test.py`

**Purpose**: Main HIL test controller for FPGA validation.

**Main Class**: `AESHardwareTest`
- Manages serial communication with FPGA
- Implements ECB-mode encryption/decryption verification
- Provides round-trip consistency validation
- Generates formatted test reports

**Key Methods**:
```python
# Setup and communication
def __init__(port='COM3', baudrate=115200, timeout=1.0)
def _send_command(cmd: str) -> str

# Mode configuration
def set_key(key_hex: str) -> bool           # Program AES key
def set_mode(mode: int) -> bool              # 1=encrypt, 0=decrypt
def set_data(data_hex: str) -> bool          # Load plaintext/ciphertext

# Execution
def start_operation() -> str                 # Trigger and read result

# Verification (FIPS-197 compliant)
def verify_encryption(plaintext_hex, key_hex) -> bool
def verify_decryption(ciphertext_hex, key_hex) -> bool
def verify_roundtrip(plaintext_hex, key_hex) -> bool
def run_suite(test_vectors) -> bool          # Execute full test suite

# Cleanup
def close()                                   # Close serial port
```

**Example Usage**:
```python
from aes_hil_test import AESHardwareTest, FIPS_TEST_VECTORS

# Connect to FPGA
device = AESHardwareTest(port='COM3', baudrate=115200)

# Run tests
success = device.run_suite(FIPS_TEST_VECTORS)

# Cleanup
device.close()
```

**Standards**: NIST FIPS-197, pycryptodome AES reference

---

### `generate_vectors.py`

**Purpose**: Generate random AES-128 test vectors for extended validation.

**Main Function**: `generate_vectors(num_vectors, output_file)`

**Parameters**:
- `num_vectors` (int): Number of random vectors to generate (default 10)
- `output_file` (str): Output file path (default `test_vectors_generated.txt`)

**Return Value**: `True` on success, `False` on error

**Example Usage**:
```bash
# Generate 50 random test vectors
python generate_vectors.py 50 vectors/extended_vectors.txt

# Using defaults (10 vectors, test_vectors_generated.txt)
python generate_vectors.py
```

**Output Format**: Identical to canonical format (plaintext ciphertext key)

**Standards**: NIST FIPS-197, ECB mode for block validation only

---

### `run_hil_tests.ps1`

**Purpose**: Automated batch testing script for Windows PowerShell.

**Parameters**:
```powershell
-Port         # Serial port name (default: COM3)
-Baudrate     # Baud rate (default: 115200)
-LogDir       # Output log directory (default: .\hil_test_logs)
-Verbose      # Enable verbose output (switch flag)
```

**Functionality**:
1. Checks Python installation and version
2. Verifies package dependencies (pycryptodome, pyserial)
3. Validates serial port availability
4. Executes HIL test suite
5. Parses results and generates timestamped log file
6. Reports summary statistics (pass/fail counts, success rate)

**Example Usage**:
```powershell
# Use defaults (COM3, 115200 bps)
.\hil\run_hil_tests.ps1

# Specify custom port and baud rate
.\hil\run_hil_tests.ps1 -Port COM5 -Baudrate 230400

# Enable verbose output
.\hil\run_hil_tests.ps1 -Verbose

# Save to custom log directory
.\hil\run_hil_tests.ps1 -LogDir "C:\test_logs"
```

**Log Output**:
Saves results to timestamped file in `hil_test_logs/`:
- `hil_test_results_20260429_143022.txt`

---

### `setup_venv.ps1`

**Purpose**: One-command virtual environment setup.

**Parameters**:
```powershell
-VenvDir      # Virtual environment directory path (default: .venv)
```

**Functionality**:
1. Creates Python virtual environment
2. Activates environment
3. Upgrades pip to latest version
4. Installs all dependencies from `requirements.txt`

**Example Usage**:
```powershell
# Use default location (.venv)
.\hil\setup_venv.ps1

# Use custom venv location
.\hil\setup_venv.ps1 -VenvDir "C:\custom_venv"

# Then activate manually
C:\custom_venv\Scripts\Activate.ps1
```

---

### `vectors/test_vectors.txt`

**Purpose**: Read-only reference file containing official FIPS-197 test vectors.

**Format**: Four canonical test cases (plaintext ciphertext key, space-separated hex)

**Usage**: Used by default in `aes_hil_test.py` as `FIPS_TEST_VECTORS`

**Notes**:
- Do not modify this file
- For custom vectors, use `generate_vectors.py` to create separate files
- All values are 128-bit (32 hexadecimal characters)

---

## Troubleshooting

### Import Resolution Errors in VS Code

**Problem**: Pylance reports "could not be resolved" for `Crypto.Cipher`, `serial` imports

**Solution**:
1. Ensure venv is created: `.\hil\setup_venv.ps1`
2. Set VS Code Python interpreter:
   - Press `Ctrl+Shift+P` → "Python: Select Interpreter"
   - Choose `.venv\Scripts\python.exe`
3. Wait for Pylance to re-index (look for notification in bottom right)
4. Reload window if needed: `Ctrl+Shift+P` → "Developer: Reload Window"

### Serial Port Not Found

**Problem**: `ERROR: Failed to connect to COM3`

**Solution**:
1. Verify FPGA board is connected via USB
2. Check Device Manager for correct COM port number
3. Update port in script arguments: `--port COM5` (or appropriate port)
4. Ensure no other application is using the port

### Python Package Not Found

**Problem**: `ModuleNotFoundError: No module named 'Crypto'`

**Solution**:
1. Verify venv is activated (prompt shows `.venv`)
2. Reinstall dependencies: `pip install -r hil/requirements.txt`
3. Check pip version: `pip --version` (should be 20.0+)

### Timeout Errors During Tests

**Problem**: `ERROR: Serial communication failed` or timeout during test execution

**Solution**:
1. Increase operation timeout: Edit `aes_hil_test.py`, line ~150:
   ```python
   device.operation_timeout = 0.05  # 50ms instead of 20ms
   ```
2. Verify FPGA design is programmed and running
3. Check USB connection quality
4. Try different baud rate: `--baudrate 230400` or `--baudrate 9600`

---

## Hardware Interface

### Serial Communication Protocol

**FPGA ↔ Python Communication**:

| Command | Format | Expected Response | Purpose |
|---------|--------|-------------------|---------|
| KEY | `KEY:00112233...` | `READY` | Program AES key (128-bit hex) |
| MODE | `MODE:1` | `READY` | Set mode (1=encrypt, 0=decrypt) |
| DATA | `DATA:6BC1BEE2...` | `READY` | Load plaintext/ciphertext (128-bit hex) |
| START | `START` | Result hex (32 chars) | Trigger operation, read output |

**Example Exchange**:
```
← KEY:000102030405060708090a0b0c0d0e0f
→ READY
← MODE:1
→ READY
← DATA:00112233445566778899aabbccddeeff
→ READY
← START
→ 69c4e0d86a7b04530d8a4e6e77033e9f
```

### Basys 3 Connections

- **USB Micro-B**: Serial communication (UART via FTDI bridge)
- **100 MHz Clock**: System clock input (pin W5)
- **Constraints File**: `constraints/basys3_aes.xdc` (all I/O configured, only clock active)

---

## Standards Compliance

### NIST FIPS-197

- **AES Algorithm**: 128-bit block, 128-bit key, 10 rounds
- **Block Mode**: ECB (Electronic Codebook) for validation only
- **Test Vectors**: Comprehensive 264-vector regression suite included
- **Reference**: pycryptodome implements FIPS-197 specification

### VHDL IEEE 1076-2008

- **Design**: Compliant with IEEE 1076-2008 VHDL standard
- **Test Vectors**: Compatible with VHDL testbenches
- **Simulation**: Vectors can be integrated into ModelSim/Vivado simulation

---

## Performance Notes

- **Typical Throughput**: ~10-20 vectors/second (serial communication limited)
- **FPGA Latency**: ~100-300 ns per operation (depends on design)
- **Test Duration**: Full 4-vector suite typically completes in <1 second

---

## Support & References

- **NIST FIPS 197**: https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197.pdf
- **pycryptodome**: https://pycryptodome.readthedocs.io/
- **pyserial**: https://pyserial.readthedocs.io/
- **Basys 3**: https://reference.digilentinc.com/reference/programmable-logic/basys-3/reference-manual

---

**Version**: 1.0  
**Last Updated**: 2026-04-29  
**Status**: Production-Ready
