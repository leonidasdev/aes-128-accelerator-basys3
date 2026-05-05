----------------------------------------------------------------------------------
-- Module Name:    key_expansion
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           29/04/2026
--
-- Description:
--   Generates 11 round keys (128 bits each) from a 128-bit master key using
--   the AES key schedule with SubWord, RotWord, and round constant operations.
--   Supports round selection and forward/inverse modes.
--
--   Implementation: Purely combinational logic with round index multiplexing.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity key_expansion is
    port (
        key_in   : in  std_logic_vector(127 downto 0);
        round    : in  std_logic_vector(3 downto 0);  -- 0..10
        enc_dec  : in  std_logic;                     -- '1' = encryption, '0' = decryption
        key_out  : out std_logic_vector(127 downto 0)
    );
end entity;

architecture rtl of key_expansion is
    -- FIPS-197 S-Box (forward substitution table)
    type t_sbox is array (0 to 255) of std_logic_vector(7 downto 0);
    constant sbox : t_sbox := (
        x"63", x"7c", x"77", x"7b", x"f2", x"6b", x"6f", x"c5", x"30", x"01", x"67", x"2b", x"fe", x"d7", x"ab", x"76",
        x"ca", x"82", x"c9", x"7d", x"fa", x"59", x"47", x"f0", x"ad", x"d4", x"a2", x"af", x"9c", x"a4", x"72", x"c0",
        x"b7", x"fd", x"93", x"26", x"36", x"3f", x"f7", x"cc", x"34", x"a5", x"e5", x"f1", x"71", x"d8", x"31", x"15",
        x"04", x"c7", x"23", x"c3", x"18", x"96", x"05", x"9a", x"07", x"12", x"80", x"e2", x"eb", x"27", x"b2", x"75",
        x"09", x"83", x"2c", x"1a", x"1b", x"6e", x"5a", x"a0", x"52", x"3b", x"d6", x"b3", x"29", x"e3", x"2f", x"84",
        x"53", x"d1", x"00", x"ed", x"20", x"fc", x"b1", x"5b", x"6a", x"cb", x"be", x"39", x"4a", x"4c", x"58", x"cf",
        x"d0", x"ef", x"aa", x"fb", x"43", x"4d", x"33", x"85", x"45", x"f9", x"02", x"7f", x"50", x"3c", x"9f", x"a8",
        x"51", x"a3", x"40", x"8f", x"92", x"9d", x"38", x"f5", x"bc", x"b6", x"da", x"21", x"10", x"ff", x"f3", x"d2",
        x"cd", x"0c", x"13", x"ec", x"5f", x"97", x"44", x"17", x"c4", x"a7", x"7e", x"3d", x"64", x"5d", x"19", x"73",
        x"60", x"81", x"4f", x"dc", x"22", x"2a", x"90", x"88", x"46", x"ee", x"b8", x"14", x"de", x"5e", x"0b", x"db",
        x"e0", x"32", x"3a", x"0a", x"49", x"06", x"24", x"5c", x"c2", x"d3", x"ac", x"62", x"91", x"95", x"e4", x"79",
        x"e7", x"c8", x"37", x"6d", x"8d", x"d5", x"4e", x"a9", x"6c", x"56", x"f4", x"ea", x"65", x"7a", x"ae", x"08",
        x"ba", x"78", x"25", x"2e", x"1c", x"a6", x"b4", x"c6", x"e8", x"dd", x"74", x"1f", x"4b", x"bd", x"8b", x"8a",
        x"70", x"3e", x"b5", x"66", x"48", x"03", x"f6", x"0e", x"61", x"35", x"57", x"b9", x"86", x"c1", x"1d", x"9e",
        x"e1", x"f8", x"98", x"11", x"69", x"d9", x"8e", x"94", x"9b", x"1e", x"87", x"e9", x"ce", x"55", x"28", x"df",
        x"8c", x"a1", x"89", x"0d", x"bf", x"e6", x"42", x"68", x"41", x"99", x"2d", x"0f", x"b0", x"54", x"bb", x"16"
    );

    -- Rcon constants for AES-128 (rounds 1..10)
    type t_rcon is array (1 to 10) of std_logic_vector(31 downto 0);
    constant rcon : t_rcon := (
        x"01000000", x"02000000", x"04000000", x"08000000",
        x"10000000", x"20000000", x"40000000", x"80000000",
        x"1b000000", x"36000000"
    );

    -- Rotate a 32-bit word left by one byte
    function rotword(w : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return w(23 downto 0) & w(31 downto 24);
    end function rotword;

    -- Apply S-Box to each byte of a 32-bit word (SubWord)
    function subword(w : std_logic_vector(31 downto 0)) return std_logic_vector is
        variable res : std_logic_vector(31 downto 0);
        variable b   : std_logic_vector(7 downto 0);
    begin
        for i in 0 to 3 loop
            b := w(31 - i*8 downto 24 - i*8);
            res(31 - i*8 downto 24 - i*8) := sbox(to_integer(unsigned(b)));
        end loop;
        return res;
    end function subword;

    -- Expanded key as array of 44 words (W0..W43)
    type t_key_words is array(0 to 43) of std_logic_vector(31 downto 0);

    -- Expand the 128-bit master key into 44 words
    function expand_key_arr(k : std_logic_vector(127 downto 0)) return t_key_words is
        variable W : t_key_words;
        variable temp : std_logic_vector(31 downto 0);
    begin
        W(0) := k(127 downto 96);
        W(1) := k(95  downto 64);
        W(2) := k(63  downto 32);
        W(3) := k(31  downto 0);
        for i in 4 to 43 loop
            temp := W(i-1);
            if (i mod 4) = 0 then
                temp := subword(rotword(temp)) xor rcon(i/4);
            end if;
            W(i) := W(i-4) xor temp;
        end loop;
        return W;
    end function expand_key_arr;

    signal all_keys_arr : t_key_words;
    signal round_int : integer range 0 to 10 := 0;
    signal start : integer range 0 to 40 := 0;
begin
    -- Expand key combinationally and pick the 4-word round key
    all_keys_arr <= expand_key_arr(key_in);
    round_int <= to_integer(unsigned(round));
    start <= round_int * 4 when enc_dec = '1' else (10 - round_int) * 4;

    -- Concatenate the 4 words W[start]..W[start+3] into a 128-bit vector
    process(all_keys_arr, start)
    begin
        key_out <= all_keys_arr(start) & all_keys_arr(start+1) & all_keys_arr(start+2) & all_keys_arr(start+3);
        report "KEY_EXP: round=" & integer'image(round_int) & 
               " enc_dec=" & std_logic'image(enc_dec) & 
               " word_start=" & integer'image(start) severity note;
    end process;
end architecture;