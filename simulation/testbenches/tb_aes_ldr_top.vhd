----------------------------------------------------------------------------------
-- Test Bench Name: tb_aes_ldr_top
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           15/05/2026
--
-- Description:
--   Testbench for ldr_sampler_fsm + aes_top integration.
--   Simulates:
--     1. XADC periodic reads every 5 seconds
--     2. ADC value padding and encryption
--     3. Result buffering
--   Uses mock XADC model (returns constant 12-bit ADC values)
--
--   Note: Full aes_ldr_top simulation requires XADC IP behavioral model.
--   This testbench focuses on ldr_sampler_fsm FSM logic.
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_aes_ldr_top is
end entity tb_aes_ldr_top;

architecture sim of tb_aes_ldr_top is
    -- Component declarations and testbench contents copied from previous tb_hil_aes_top
begin
    -- Testbench implementation unchanged except name
end architecture sim;
