----------------------------------------------------------------------------------
-- Module Name:    inv_shift_rows
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           29/04/2026
--
-- Description:
--   Inverse ShiftRows transformation for AES decryption.
--   Row 0: no shift, Row 1: right shift by 1, Row 2: right shift by 2, Row 3: right shift by 3.
--   Operates on 128-bit state matrix in column-major format.
--
--   Implementation: Purely combinational byte rewiring complement of shift_rows.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity inv_shift_rows is
    port (
        state_in  : in  std_logic_vector(127 downto 0);
        state_out : out std_logic_vector(127 downto 0)
    );
end entity inv_shift_rows;

architecture rtl of inv_shift_rows is
begin

    -- Input state layout (byte indices in column-major order):
    --  0  4  8  12
    --  1  5  9  13
    --  2  6 10  14
    --  3  7 11  15

    -- After InvShiftRows (row-wise right shifts):
    --  0  4  8  12  (row 0: no shift)
    --  13 1  5  9   (row 1: right shift by 1)
    --  10 14 2  6   (row 2: right shift by 2)
    --  7  11 15 3   (row 3: right shift by 3)

    -- Byte mapping in bits (each byte i occupies bits [8*i+7 downto 8*i]):
    state_out(7 downto 0)     <= state_in(7 downto 0);        -- out byte 0 <- in byte 0
    state_out(15 downto 8)    <= state_in(111 downto 104);    -- out byte 1 <- in byte 13
    state_out(23 downto 16)   <= state_in(87 downto 80);      -- out byte 2 <- in byte 10
    state_out(31 downto 24)   <= state_in(63 downto 56);      -- out byte 3 <- in byte 7
    state_out(39 downto 32)   <= state_in(39 downto 32);      -- out byte 4 <- in byte 4
    state_out(47 downto 40)   <= state_in(15 downto 8);       -- out byte 5 <- in byte 1
    state_out(55 downto 48)   <= state_in(119 downto 112);    -- out byte 6 <- in byte 14
    state_out(63 downto 56)   <= state_in(95 downto 88);      -- out byte 7 <- in byte 11
    state_out(71 downto 64)   <= state_in(71 downto 64);      -- out byte 8 <- in byte 8
    state_out(79 downto 72)   <= state_in(47 downto 40);      -- out byte 9 <- in byte 5
    state_out(87 downto 80)   <= state_in(23 downto 16);      -- out byte 10 <- in byte 2
    state_out(95 downto 88)   <= state_in(127 downto 120);    -- out byte 11 <- in byte 15
    state_out(103 downto 96)  <= state_in(103 downto 96);     -- out byte 12 <- in byte 12
    state_out(111 downto 104) <= state_in(79 downto 72);      -- out byte 13 <- in byte 9
    state_out(119 downto 112) <= state_in(55 downto 48);      -- out byte 14 <- in byte 6
    state_out(127 downto 120) <= state_in(31 downto 24);      -- out byte 15 <- in byte 3

end architecture rtl;
