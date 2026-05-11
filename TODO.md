# AES-128 Hardware Accelerator — Hardware Bring-Up TODO

**Project Status:** Development complete, ready for hardware validation  
**Current Phase:** Hardware bring-up and real-world testing on Basys 3

---

## Completed Work ✓

### Core RTL & Simulation (Complete)
- [x] AES-128 core implementation (encryption + decryption)
- [x] All primitive transformations (SubBytes, ShiftRows, MixColumns, AddRoundKey and inverses)
- [x] FSM control logic and key expansion
- [x] UART-to-AES controller with ASCII protocol (K:/D:/M:/S:)
- [x] Simulation testbenches for all modules (Layer 1 verification)
- [x] All FIPS-197 vectors passing in simulation

### Testing Framework (Complete)
- [x] Layer 2 HIL framework (`aes_hil_test.py`)
- [x] Layer 3 mock HIL controller (`mock_fpga_controller.py`) for CI/offline testing
- [x] 264-vector test suite (4 canonical + 260 edge cases)
- [x] Mock unit tests passing (26/26)

### Documentation & Architecture (Complete)
- [x] Consolidated READMEs (root + hil/)
- [x] Refactored `basys3_top.vhd` to UART HIL wrapper with LED feedback
- [x] Updated constraints for UART + LED pins
- [x] All module documentation and protocol specification

---

## Hardware Bring-Up TODO

### Phase 1: Synthesis & Bitstream (Vivado)

**Goal:** Generate FPGA bitstream and verify timing closure

- [x] Open Vivado project for AES-128 design
- [x] Set `design/basys3_top.vhd` as top module
- [x] Select constraint file: `constraints/basys3_aes.xdc`
- [x] Run synthesis (check for errors, warnings)
- [x] Run place & route (verify timing closure at 100 MHz)
- [x] Generate bitstream (.bit file)
- [x] **Checkpoint:** Verify build completes without critical errors

### Phase 2: Board Programming

**Goal:** Program Basys 3 with AES accelerator firmware

- [ ] Connect Basys 3 to PC via USB cable
- [ ] Open Vivado Hardware Manager
- [ ] Auto-connect to board (XC7A35T)
- [ ] Program device with generated bitstream
- [ ] Observe LED indication: LED15 should go high (ready signal)
- [ ] **Checkpoint:** Board boots and shows ready LED

### Phase 3: Initial Smoke Test

**Goal:** Verify basic UART communication and single encryption

- [ ] Open serial terminal (e.g., PuTTY, TeraTerm) on correct COM port
- [ ] Settings: 115,200 bps, 8 data, 1 stop, no parity
- [ ] Send test command: `K:000102030405060708090A0B0C0D0E0F\n`
- [ ] Verify board echoes back key
- [ ] Send mode: `M:1\n` (encrypt)
- [ ] Verify board echoes back 1
- [ ] Send data: `D:00112233445566778899AABBCCDDEEFF\n`
- [ ] Verify board echoes back data
- [ ] Send start: `S\n`
- [ ] Verify board returns ciphertext: `69C4E0D86A7B0430D8CDB78070B4C55A`
- [ ] **Checkpoint:** Single encryption verified correct

### Phase 4: Full HIL Regression Suite

**Goal:** Run all 264 vectors and validate 100% pass rate

- [ ] Activate Python virtual environment
- [ ] Identify correct COM port from Device Manager
- [ ] Run full test suite:
  ```powershell
  .\.venv\Scripts\Activate.ps1
  .\hil\run_hil_tests.ps1 -Port COM3 -Verbose
  ```
- [ ] Monitor board LEDs during testing:
  - LED15 = ready (should pulse between operations)
  - LED14 = done (should pulse on completion)
  - LED13 = error (should remain off for all passes)
  - LED12 = mode (should toggle between 0 and 1)
- [ ] Wait for full suite to complete (3–5 seconds)
- [ ] Verify final summary: **792/792 tests PASS (100%)**
- [ ] **Checkpoint:** All tests passing; HIL validation complete

### Phase 5: Documentation & Release

**Goal:** Prepare for final handoff

- [ ] Commit all changes with message:
  ```
  Hardware validation complete: 792/792 HIL tests passing on Basys 3
  ```
- [ ] Tag release (e.g., v1.0-hil-validated)
- [ ] Update README with final validation date and results
- [ ] Archive bitstream (.bit) and design for future reproducibility
- [ ] **Final Checkpoint:** Project archived and ready for deployment/demo

---

## Quick Start Commands

**One-time setup:**
```powershell
cd c:\amd-vivado-projects\aes_vscode
.\setup_venv.ps1
```

**Hardware testing:**
```powershell
.\.venv\Scripts\Activate.ps1
.\hil\run_hil_tests.ps1 -Port COM3 -Verbose
```

**Mock testing (no hardware):**
```powershell
.\.venv\Scripts\Activate.ps1
python hil\python\test_aes_hil_mock.py
```

---

## Known Good Configuration

**FPGA Board:** Basys 3 (XC7A35T-1CPG236C)  
**Design Top:** `basys3_top.vhd` (UART HIL wrapper)  
**Clock:** 100 MHz onboard oscillator  
**UART:** 115,200 bps, USB bridge  
**Test Vectors:** 264 vectors, 792 total tests (enc + dec + round-trip)  
**Expected Result:** 100% pass rate (all vectors + all operations matching pycryptodome reference)

---

## Success Criteria

✓ Bitstream builds without errors  
✓ Board programs and shows ready LED  
✓ Single encryption produces correct result  
✓ All 792 HIL tests pass (100%)  
✓ Both encryption and decryption paths validated  
✓ Round-trip (encrypt→decrypt) recovers original plaintext  

**Status:** Ready for hardware validation. Next step: synthesize, program, and run HIL suite.
