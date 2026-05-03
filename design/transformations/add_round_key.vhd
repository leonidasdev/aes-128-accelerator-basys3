--
-- AddRoundKey transformation
-- XORs the 128-bit state with the 128-bit round key
--
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
