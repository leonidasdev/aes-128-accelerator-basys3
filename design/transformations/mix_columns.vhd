--
-- Purpose:   AES MixColumns transformation (encryption).
-- Author:    PHR26-T03
-- Date:      29/04/2026
--
-- Description:
-- This module performs the MixColumns transformation of AES.
-- It processes 4 columns independently, multiplying each column by
-- the AES mixing matrix in GF(2^8).
-- The transformation uses xtime for GF(2^8) multiplication.
-- Purely combinational.
--

library ieee;
use ieee.std_logic_1164.all;

entity mix_columns is
    port (
        state_in  : in  std_logic_vector(127 downto 0);
        state_out : out std_logic_vector(127 downto 0)
    );
end entity mix_columns;

architecture rtl of mix_columns is

    -- Multiply by 2 in GF(2^8) using xtime
    function xtime(x : std_logic_vector(7 downto 0)) return std_logic_vector is
        variable result : std_logic_vector(7 downto 0);
    begin
        if x(7) = '0' then
            result := x(6 downto 0) & '0';
        else
            result := (x(6 downto 0) & '0') xor x"1b";
        end if;
        return result;
    end function xtime;

    -- Multiply by 3 in GF(2^8) = xtime(x) ^ x
    function mul_3(x : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        return xtime(x) xor x;
    end function mul_3;

    -- Mix a single column (4 bytes)
    function mix_column(b0, b1, b2, b3 : std_logic_vector(7 downto 0))
        return std_logic_vector is
        variable r0, r1, r2, r3 : std_logic_vector(7 downto 0);
    begin
        r0 := (xtime(b0) xor mul_3(b1) xor b2 xor b3);
        r1 := (b0 xor xtime(b1) xor mul_3(b2) xor b3);
        r2 := (b0 xor b1 xor xtime(b2) xor mul_3(b3));
        r3 := (mul_3(b0) xor b1 xor b2 xor xtime(b3));
        return r3 & r2 & r1 & r0;
    end function mix_column;

begin

    -- Extract columns and apply mixing
    -- State in column-major format (bytes 0-3 = col 0, bytes 4-7 = col 1, etc.)
    -- Each column is represented as 4 consecutive bytes
    
    -- Column 0
    state_out(31 downto 0) <= mix_column(
        state_in(7 downto 0),
        state_in(15 downto 8),
        state_in(23 downto 16),
        state_in(31 downto 24)
    );

    -- Column 1
    state_out(63 downto 32) <= mix_column(
        state_in(39 downto 32),
        state_in(47 downto 40),
        state_in(55 downto 48),
        state_in(63 downto 56)
    );

    -- Column 2
    state_out(95 downto 64) <= mix_column(
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
