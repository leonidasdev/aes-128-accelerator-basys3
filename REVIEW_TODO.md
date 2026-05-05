# AES Project Cleanup TODO

Verification status: All simulation tests passing (5/5 FIPS-197 encryption vectors validated)

This is the cleanup and maintenance checklist for the AES-128 forward/inverse RTL implementation. The core functionality is complete and verified correct through simulation. The following tasks address code quality, style consistency, and expanded test coverage.

## Current Status

- [X] Core RTL implementation complete and functionally correct
- [X] All 5 FIPS-197 encryption test vectors passing in `tb_aes_top.vhd`
- [X] All primitive transformation modules validated (forward and inverse)
- [X] Key expansion verified correct
- [X] FSM control logic verified correct
- [X] Documentation path references corrected to `simulation/testbenches`

## Remaining Tasks

### P0 - Verify Hardware-in-the-Loop Testing

- [ ] Run full HIL regression suite with `run_hil_tests.ps1`
- [ ] Confirm all 264 test vectors pass on the Basys 3 board
- [ ] Validate decryption path (inverse) against HIL test suite
- [ ] Verify round-trip encryption/decryption matches reference

### P1 - Dead Code and Optimization

- [ ] Remove any unused signals or commented-out code from `aes_datapath.vhd`
- [ ] Remove any unused signals or commented-out code from other modules
- [ ] Review for unreachable FSM states or dead logic paths
- [ ] Clean up any debug or temporary instrumentation code

### P2 - Test Coverage Expansion

- [ ] Expand `tb_aes_top.vhd` to include full FIPS-197 test vector suite (not just 5 vectors)
- [ ] Ensure inverse (decryption) path is tested as thoroughly as forward (encryption) path
- [ ] Add boundary-condition tests (all-zero, all-one, alternating patterns)
- [ ] Verify bit-error injection tests or randomized vector testing if desired

## Commit Strategy

Once all tasks are complete:

1. Verify all tests still pass
2. Commit with message: "AES-128: Cleanup - comments, style consistency, dead code removal, HIL validation complete"
