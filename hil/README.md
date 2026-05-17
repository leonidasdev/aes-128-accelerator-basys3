# Hardware-in-the-Loop (HIL) Testing Framework

## Overview

Hardware-in-the-loop testing validates the AES-128 FPGA implementation by comparing its output against a trusted reference (pycryptodome AES-128) across a 264-vector test suite. Tests run on the host PC and communicate with the FPGA via USB UART.

**Key Facts:**
- Protocol: ASCII command-response via USB serial (115,200 bps)
- Vectors: 264 test vectors (4 canonical FIPS-197 + 260 regression/edge cases)
- Reference: NIST pycryptodome (FIPS-197 compliant)
- Test coverage: 3 modes per vector = 792 total tests (encryption, decryption, round-trip)
- Expected duration: 3–5 seconds for full suite
- Success criterion: All 792 tests PASS (100% match between FPGA and reference)
- **Visual Feedback:** 16 Basys3 LEDs show real-time controller status (LED15=ready, LED14=done, LED13=error, LED12=mode) during testing

---

## Architecture

```
Host Computer (Windows)
  ├─ Python HIL Framework
  │   ├─ aes_hil_test.py (main test controller)
  │   ├─ adc_monitor.py (ADC monitor and decryptor)
  │   ├─ generate_vectors.py (vector generation)
  │   ├─ mock_aes_adc.py / mock_aes_hil.py (test doubles)
  │   ├─ send_single_encrypt.py / send_single_decrypt.py (smoke tests)
  │   └─ serial_diagnostics.py + tests (manual diagnostics and regression)
  │
  └─ USB Serial UART
      └─ 115,200 bps, 8 data bits, 1 stop bit, no parity
         (FTDI FT232 bridge)

Basys 3 FPGA
  └─ XC7A35T Artix-7
      └─ AES-128 Hardware Accelerator
          ├─ Encryption engine (forward transformations)
          ├─ Decryption engine (inverse transformations)
          ├─ UART interface controller
          └─ Command/response FSM
```

---

## Serial Protocol

**Command Set:**

| Command | Format | Response | Function |
|---------|--------|----------|----------|
| `K` (Key) | `K:<32-hex>\n` | (no response) | Load 128-bit master key into FPGA |
| `M` (Mode) | `M:<0 or 1>\n` | (no response) | Set mode (1=encrypt, 0=decrypt) |
| `D` (Data) | `D:<32-hex>\n` | (no response) | Load plaintext or ciphertext |
| `S` (Start) | `S\n` | `<32-hex>\n` | Execute AES operation; returns ciphertext/plaintext (32-hex) |

**Data Encoding:**
- Format: Hexadecimal strings (uppercase or lowercase accepted)
from mock_aes_hil import MockAESHILController, MockAESHILSerialPort
from aes_hil_test import AESHardwareTest
from unittest.mock import patch

# Create mock FPGA
mock_fpga = MockAESHILController(verbose=True)
mock_port = MockAESHILSerialPort(mock_fpga=mock_fpga)

# Use with AESHardwareTest
with patch('aes_hil_test.serial.Serial', return_value=mock_port):
    tester = AESHardwareTest(port='MOCK')
    
    # Full encryption test
    tester.set_key('000102030405060708090A0B0C0D0E0F')
    tester.set_mode(1)  # Encrypt
    tester.set_data('00112233445566778899AABBCCDDEEFF')
    result = tester.execute()
    print(f"Result: {result}")
    
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
├── hil_verify.py                  # Environment and structure verification
├── results/                       # Timestamped HIL logs and run output
├── python/
│   ├── aes_hil_test.py            # Main HIL test controller
│   ├── adc_monitor.py             # ADC monitor and decryptor
│   ├── generate_vectors.py        # Test vector generation utility
│   ├── mock_aes_adc.py            # Mock ADC stream simulator
│   ├── mock_aes_hil.py            # Mock AES HIL simulator
│   ├── send_single_decrypt.py     # Single-vector decryption smoke test
│   ├── send_single_encrypt.py     # Single-vector encryption smoke test
│   ├── serial_diagnostics.py      # Manual serial troubleshooting utility
│   ├── test_aes_adc_mock.py       # ADC monitor integration tests
│   └── test_aes_hil_mock.py       # Unit tests with mock
├── vectors/
│   └── test_vectors.txt           # Comprehensive regression suite (authoritative HIL input)
├── run_hil_tests.ps1              # Batch test automation script (PowerShell)
```

Shared setup files live in the repository root:
- `requirements.txt`
- `setup_venv.ps1`

---

## Quick Start

### 1. Setup Python Virtual Environment

```powershell
# From workspace root: c:\amd-vivado-projects\aes_vscode

# Create virtual environment and install dependencies
.\setup_venv.ps1

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
pip install -r requirements.txt
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
```powershell
# Generate 50 random test vectors
python .\python\generate_vectors.py 50 .\vectors\extended_vectors.txt

# Using defaults (10 vectors, test_vectors_generated.txt)
python .\python\generate_vectors.py
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
-LogDir       # Output log directory (default: .\hil\results)
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
Saves the full transcript to a timestamped file in `hil/results/`:
- `hil_test_results_20260512_143022.txt`

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
.\setup_venv.ps1

# Use custom venv location
.\setup_venv.ps1 -VenvDir "C:\custom_venv"

# Then activate manually
C:\custom_venv\Scripts\Activate.ps1
```

---

### `vectors/test_vectors.txt`

**Purpose**: Read-only reference file containing the 264-vector HIL regression suite and official FIPS-197 test vectors.

**Format**: 264 regression vectors (plaintext ciphertext key, space-separated hex)

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
1. Ensure venv is created: `.setup_venv.ps1`
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
2. Reinstall dependencies: `pip install -r requirements.txt`
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
- **Constraints File**: `constraints/aes_hil_top.xdc` (all I/O configured, only clock active)

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
- **Test Duration**: Full 264-vector suite typically completes in 3–5 seconds

---

## Support & References

- **NIST FIPS 197**: https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197.pdf
- **pycryptodome**: https://pycryptodome.readthedocs.io/
- **pyserial**: https://pyserial.readthedocs.io/
- **Basys 3**: https://reference.digilentinc.com/reference/programmable-logic/basys-3/reference-manual

---

**Version**: 0.0.2 
**Last Updated**: 2026-05-17
**Status**: Production-Ready

