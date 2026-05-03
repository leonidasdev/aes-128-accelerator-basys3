--
-- Purpose:   AES InvMixColumns transformation (decryption).
-- Author:    PHR26-T03
-- Date:      29/04/2026
--
-- Description:
-- This module performs the inverse MixColumns transformation of AES.
-- It processes 4 columns independently, multiplying each column by
-- the inverse mixing matrix in GF(2^8).
-- Uses GF(2^8) multiplication with coefficients 0e, 0b, 0d, 09.
-- Purely combinational.
--

library ieee;
use ieee.std_logic_1164.all;

entity inv_mix_columns is
    port (
        state_in  : in  std_logic_vector(127 downto 0);
        state_out : out std_logic_vector(127 downto 0)
    );
end entity inv_mix_columns;

architecture rtl of inv_mix_columns is

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

    -- Multiply by 4 in GF(2^8) = xtime(xtime(x))
    function mul_4(x : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        return xtime(xtime(x));
    end function mul_4;

    -- Multiply by 8 in GF(2^8) = xtime(mul_4(x))
    function mul_8(x : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        return xtime(mul_4(x));
    end function mul_8;

    -- Multiply by 0x09 (9) = 8 + 1 in GF(2^8)
    function mul_9(x : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        return mul_8(x) xor x;
    end function mul_9;

    -- Multiply by 0x0b (11) = 8 + 2 + 1 in GF(2^8)
    function mul_b(x : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        return mul_8(x) xor xtime(x) xor x;
    end function mul_b;

    -- Multiply by 0x0d (13) = 8 + 4 + 1 in GF(2^8)
    function mul_d(x : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        return mul_8(x) xor mul_4(x) xor x;
    end function mul_d;

    -- Multiply by 0x0e (14) = 8 + 4 + 2 in GF(2^8)
    function mul_e(x : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        return mul_8(x) xor mul_4(x) xor xtime(x);
    end function mul_e;

    -- Mix a single column with inverse coefficients
    function inv_mix_column(b0, b1, b2, b3 : std_logic_vector(7 downto 0))
        return std_logic_vector is
        variable r0, r1, r2, r3 : std_logic_vector(7 downto 0);
    begin
        r0 := (mul_e(b0) xor mul_b(b1) xor mul_d(b2) xor mul_9(b3));
        r1 := (mul_9(b0) xor mul_e(b1) xor mul_b(b2) xor mul_d(b3));
        r2 := (mul_d(b0) xor mul_9(b1) xor mul_e(b2) xor mul_b(b3));
        r3 := (mul_b(b0) xor mul_d(b1) xor mul_9(b2) xor mul_e(b3));
        return r3 & r2 & r1 & r0;
    end function inv_mix_column;

begin

    -- Extract columns and apply inverse mixing
    -- State in column-major format
    
    -- Column 0
    state_out(31 downto 0) <= inv_mix_column(
        state_in(7 downto 0),
        state_in(15 downto 8),
        state_in(23 downto 16),
        state_in(31 downto 24)
    );

    -- Column 1
    state_out(63 downto 32) <= inv_mix_column(
        state_in(39 downto 32),
        state_in(47 downto 40),
        state_in(55 downto 48),
        state_in(63 downto 56)
    );

    -- Column 2
    state_out(95 downto 64) <= inv_mix_column(
        state_in(71 downto 64),
        state_in(79 downto 72),
        state_in(87 downto 80),
        state_in(95 downto 88)
    );

    -- Column 3
    state_out(127 downto 96) <= inv_mix_column(
        state_in(103 downto 96),
        state_in(111 downto 104),
        state_in(119 downto 112),
        state_in(127 downto 120)
    );

end architecture rtl;
