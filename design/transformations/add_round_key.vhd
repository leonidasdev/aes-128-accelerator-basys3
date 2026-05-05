----------------------------------------------------------------------------------
-- Module Name:    add_round_key
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           29/04/2026
--
-- Description:
--   AddRoundKey transformation: XORs the 128-bit state with the 128-bit round key.
--   Self-inverse operation (same logic for encryption and decryption).
--
--   Implementation: Purely combinational bitwise XOR with no latency.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity add_round_key is
    port (
        state_in  : in  std_logic_vector(127 downto 0);
        key_in    : in  std_logic_vector(127 downto 0);
        state_out : out std_logic_vector(127 downto 0)
    );
end entity add_round_key;

architecture rtl of add_round_key is
begin
    -- Simple bitwise XOR of state and round key
    state_out <= state_in xor key_in;
end architecture rtl;
