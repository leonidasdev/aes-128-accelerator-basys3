# AES Project Review TODO

This is a working review list for the AES-128 forward/inverse RTL, simulation testbenches, and HIL flow. Priorities are ordered from most urgent to least urgent.

## P0 - Fix documentation drift and broken references

- [x] Update all README links and references from `implementation/testbenches` to `simulation/testbenches`.
- [x] Audit the root README for any other stale path names, especially testbench and verification references.
- [x] Normalize the HIL README structure so headings, tables, and diagrams render cleanly from top to bottom.
- [x] Remove or correct any conflicting claims about the regression suite size and contents.

## P1 - Make verification claims technically accurate

- [ ] Reconcile the HIL README claim that `vectors/test_vectors.txt` is a 264-vector suite with the actual generation and loading logic.
- [ ] Ensure the root README and HIL README describe the same test-vector source, counts, and coverage model.
- [ ] Replace any sample output or latency statements that are presented as facts but are not measured or versioned.
- [ ] Document exactly what is proven by simulation versus what is proven only in HIL.

## P1 - Tighten RTL architecture and control review

- [ ] Review the AES top-level handshake for reset/start/done behavior and confirm it is robust under back-to-back transactions.
- [ ] Review the FSM round sequencing for edge cases, especially deassertion timing and state transitions around final-round handling.
- [ ] Verify the key expansion interface is truly aligned with encryption and decryption round ordering.
- [ ] Check that the datapath uses a single, unambiguous byte ordering across forward and inverse paths.
- [ ] **Implement robust start/ready handshake**: Add `ready`/`busy` and `error` outputs to `aes_fsm` and `aes_top`. Guard `start` signal sampling so it is only accepted when `ready='1'`. Add watchdog timer to detect hangs and transition to `ST_ERROR`. Update `tb_aes_top.vhd` to verify repeated `start` is ignored and timeout is triggered. Update `aes_hil_test.py` to poll `ready` before sending `start` (serial command protocol). Options: (1) minimal fix: sample guard + ready output; (2) preferred: add ready + error + watchdog; (3) stronger: req/ack or toggle protocol. *Recommendation: option 2 (ready/busy/error outputs + watchdog).*

## P2 - Strengthen simulation testbenches

- [ ] Expand `tb_aes_top.vhd` coverage beyond a small fixed set of vectors and add explicit negative or timeout checks.
- [ ] Add assertions for protocol behavior, not only final ciphertext equality.
- [ ] Review each primitive testbench for completeness, especially whether inverse modules are tested as thoroughly as forward ones.
- [x] Tighten `tb_key_expansion.vhd` to validate the inverse round-key path for the all-zero key case.
- [ ] Make sure unit benches and top-level benches agree on the same reference vectors and byte order.

## P2 - Strengthen HIL validation

- [ ] Verify that `aes_hil_test.py` and the FPGA UART protocol are documented as implemented, not as assumed.
- [ ] Confirm that HIL round-trip tests are not being treated as proof of cryptographic correctness by themselves.
- [ ] Check timeout handling, serial failure handling, and pass/fail reporting for false positives or silent truncation.
- [ ] Make the HIL environment verification script and batch runner agree on package names, paths, and expected outputs.

## P3 - Clean up maintainability issues

- [ ] Review comments and module headers for dated or overstated language.
- [ ] Remove duplicated claims between README files where one source of truth would be clearer.
- [ ] Add a short verification matrix that lists each module, testbench, and what is actually proven.
- [ ] Consider a single canonical regression document for simulation and HIL so the suite does not drift again.

## First item to tackle

1. Update the README path references to `simulation/testbenches` and then re-check the surrounding verification text for consistency.
