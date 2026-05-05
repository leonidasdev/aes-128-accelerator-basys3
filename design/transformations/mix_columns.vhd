----------------------------------------------------------------------------------
-- Module Name:    mix_columns
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           29/04/2026
--
-- Description:
--   Performs the forward MixColumns transformation for AES encryption.
--   Operates on the 128-bit state matrix, processing four 32-bit columns
--   independently. Each column is multiplied by the standard AES polynomial
--   matrix in the Galois Field GF(2^8).
--
--   Implementation: Purely combinational logic.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity mix_columns is
    port (
        state_in  : in  std_logic_vector(127 downto 0);
        state_out : out std_logic_vector(127 downto 0)
    );
end entity mix_columns;

architecture rtl of mix_columns is

    -- Multiply by 2 in GF(2^8) using the xtime operation
    -- Uses the AES irreducible polynomial x^8 + x^4 + x^3 + x + 1 (0x1B)
    function xtime(x : std_logic_vector(7 downto 0)) return std_logic_vector is
        variable result : std_logic_vector(7 downto 0);
    begin
        if x(7) = '0' then
            result := x(6 downto 0) & '0';
        else
            result := (x(6 downto 0) & '0') xor x"1B";
        end if;
        return result;
    end function xtime;

    -- Multiply by 3 in GF(2^8) equivalent to: (x * 2) XOR x
    function mul_3(x : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        return xtime(x) xor x;
    end function mul_3;

    -- Mix a single 32-bit column (4 bytes) using the forward matrix
    function mix_column(b0, b1, b2, b3 : std_logic_vector(7 downto 0)) return std_logic_vector is
        variable r0, r1, r2, r3 : std_logic_vector(7 downto 0);
    begin
        r0 := xtime(b0) xor mul_3(b1) xor       b2  xor       b3;
        r1 :=       b0  xor xtime(b1) xor mul_3(b2) xor       b3;
        r2 :=       b0  xor       b1  xor xtime(b2) xor mul_3(b3);
        r3 := mul_3(b0) xor       b1  xor       b2  xor xtime(b3);
        
        return r3 & r2 & r1 & r0;
    end function mix_column;

begin

    -- Extract columns and apply the MixColumns matrix multiplication.
    -- State is in column-major format (bytes 0-3 = col 0, bytes 4-7 = col 1, etc.)
    
    -- Column 0
    state_out(31 downto 0)   <= mix_column(
        state_in(7 downto 0),
        state_in(15 downto 8),
        state_in(23 downto 16),
        state_in(31 downto 24)
    );

    -- Column 1
    state_out(63 downto 32)  <= mix_column(
        state_in(39 downto 32),
        state_in(47 downto 40),
        state_in(55 downto 48),
        state_in(63 downto 56)
    );

    -- Column 2
    state_out(95 downto 64)  <= mix_column(
        state_in(71 downto 64),
        state_in(79 downto 72),
        state_in(87 downto 80),
        state_in(95 downto 88)
    );

    -- Column 3
    state_out(127 downto 96) <= mix_column(
        state_in(103 downto 96),
        state_in(111 downto 104),
        state_in(119 downto 112),
        state_in(127 downto 120)
    );

end architecture rtl;