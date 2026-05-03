--
-- Purpose:   Self-checking testbench for SubBytes transformation.
-- Author:    PHR26-T03
-- Date:      29/04/2026
--
-- Description:
-- Comprehensive testbench following NIST FIPS-197 validation standards.
-- Tests the SubBytes module using known vectors from FIPS-197.
-- Verifies S-Box lookups for all 256 possible byte values in all 16 positions.
-- Validates FIPS-197 canonical S-Box implementation.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_sub_bytes is
end entity tb_sub_bytes;

architecture sim of tb_sub_bytes is

    -- This helper is implemented here because we are using VHDL-1993, and to_hstring is not available.
    function slv_to_hstring(value : std_logic_vector) return string is
        variable result : string(1 to value'length / 4);
        variable nibble : std_logic_vector(3 downto 0);
    begin
        for i in 0 to result'length - 1 loop
            nibble := value(value'left - i * 4 downto value'left - i * 4 - 3);
            case to_integer(unsigned(nibble)) is
                when 0  => result(i + 1) := '0';
                when 1  => result(i + 1) := '1';
                when 2  => result(i + 1) := '2';
                when 3  => result(i + 1) := '3';
                when 4  => result(i + 1) := '4';
                when 5  => result(i + 1) := '5';
                when 6  => result(i + 1) := '6';
                when 7  => result(i + 1) := '7';
                when 8  => result(i + 1) := '8';
                when 9  => result(i + 1) := '9';
                when 10 => result(i + 1) := 'A';
                when 11 => result(i + 1) := 'B';
                when 12 => result(i + 1) := 'C';
                when 13 => result(i + 1) := 'D';
                when 14 => result(i + 1) := 'E';
                when others => result(i + 1) := 'F';
            end case;
        end loop;
        return result;
    end function;

    signal state_in  : std_logic_vector(127 downto 0);
    signal state_out : std_logic_vector(127 downto 0);

    -- FIPS-197 S-Box for verification - verified canonical
    type t_sbox is array (0 to 255) of std_logic_vector(7 downto 0);
    constant sbox : t_sbox := (
        x"63", x"7c", x"77", x"7b", x"f2", x"6b", x"6f", x"c5",
        x"30", x"01", x"67", x"2b", x"fe", x"d7", x"ab", x"76",
        x"ca", x"82", x"c9", x"7d", x"fa", x"59", x"47", x"f0",
        x"ad", x"d4", x"a2", x"af", x"9c", x"a4", x"72", x"c0",
        x"b7", x"fd", x"93", x"26", x"36", x"3f", x"f7", x"cc",
        x"34", x"a5", x"e5", x"f1", x"71", x"d8", x"31", x"15",
        x"04", x"c7", x"23", x"c3", x"18", x"96", x"05", x"9a",
        x"07", x"12", x"80", x"e2", x"eb", x"27", x"b2", x"75",
        x"09", x"83", x"2c", x"1a", x"1b", x"6e", x"5a", x"a0",
        x"52", x"3b", x"d6", x"b3", x"29", x"e3", x"2f", x"84",
        x"53", x"d1", x"00", x"ed", x"20", x"fc", x"b1", x"5b",
        x"6a", x"cb", x"be", x"39", x"4a", x"4c", x"58", x"cf",
        x"d0", x"ef", x"aa", x"fb", x"43", x"4d", x"33", x"85",
        x"45", x"f9", x"02", x"7f", x"50", x"3c", x"9f", x"a8",
        x"51", x"a3", x"40", x"8f", x"92", x"9d", x"38", x"f5",
        x"bc", x"b6", x"da", x"21", x"10", x"ff", x"f3", x"d2",
        x"cd", x"0c", x"13", x"ec", x"5f", x"97", x"44", x"17",
        x"c4", x"a7", x"7e", x"3d", x"64", x"5d", x"19", x"73",
        x"60", x"81", x"4f", x"dc", x"22", x"2a", x"90", x"88",
        x"46", x"ee", x"b8", x"14", x"de", x"5e", x"0b", x"db",
        x"e0", x"32", x"3a", x"0a", x"49", x"06", x"24", x"5c",
        x"c2", x"d3", x"ac", x"62", x"91", x"95", x"e4", x"79",
        x"e7", x"c8", x"37", x"6d", x"8d", x"d5", x"4e", x"a9",
        x"6c", x"56", x"f4", x"ea", x"65", x"7a", x"ae", x"08",
        x"ba", x"78", x"25", x"2e", x"1c", x"a6", x"b4", x"c6",
        x"e8", x"dd", x"74", x"1f", x"4b", x"bd", x"8b", x"8a",
        x"70", x"3e", x"b5", x"66", x"48", x"03", x"f6", x"0e",
        x"61", x"35", x"57", x"b9", x"86", x"c1", x"1d", x"9e",
        x"e1", x"f8", x"98", x"11", x"69", x"d9", x"8e", x"94",
        x"9b", x"1e", x"87", x"e9", x"ce", x"55", x"28", x"df",
        x"8c", x"a1", x"89", x"0d", x"bf", x"e6", x"42", x"68",
        x"41", x"99", x"2d", x"0f", x"b0", x"54", x"bb", x"16"
    );

    component sub_bytes
        port (
            state_in  : in  std_logic_vector(127 downto 0);
            state_out : out std_logic_vector(127 downto 0)
        );
    end component sub_bytes;

begin

    u_dut : sub_bytes port map (
        state_in  => state_in,
        state_out => state_out
    );

    process
        variable pass_cnt : integer := 0;
        variable fail_cnt : integer := 0;
        variable test_num : integer := 0;
        variable expected : std_logic_vector(127 downto 0);
        variable input_byte : std_logic_vector(7 downto 0);
    begin
         report "==============================" & character'val(10) &
             "Starting SubBytes testbench" & character'val(10) &
             "==============================" severity note;

        -- Test all 256 byte values in all 16 positions using FIPS-197 S-Box
        for test_idx in 0 to 15 loop
            for byte_val in 0 to 255 loop
                test_num := test_num + 1;
                state_in <= (others => '0');
                input_byte := std_logic_vector(to_unsigned(byte_val, 8));
                state_in(test_idx * 8 + 7 downto test_idx * 8) <= input_byte;
                wait for 1 ns;

                -- Apply SubBytes to all 16 input bytes (15 bytes are 0x00 in this stimulus).
                for j in 0 to 15 loop
                    expected(j * 8 + 7 downto j * 8) := sbox(0);
                end loop;
                expected(test_idx * 8 + 7 downto test_idx * 8) := sbox(byte_val);

                if state_out = expected then
                    pass_cnt := pass_cnt + 1;
                    report "Test " & integer'image(test_num) & ": PASS" severity note;
                else
                    fail_cnt := fail_cnt + 1;
                    report "Test " & integer'image(test_num) & ": FAIL" & character'val(10) &
                           "  Byte position: " & integer'image(test_idx) & character'val(10) &
                           "  Input value:   " & integer'image(byte_val) & character'val(10) &
                           "  Expected:      " & slv_to_hstring(expected) & character'val(10) &
                           "  Got:           " & slv_to_hstring(state_out) severity warning;
                end if;
            end loop;
        end loop;

        report "==============================" & character'val(10) &
               "FINAL REPORT" & character'val(10) &
               "PASS: " & integer'image(pass_cnt) & character'val(10) &
               "FAIL: " & integer'image(fail_cnt) & character'val(10) &
               "==============================" severity note;
        wait;
    end process;

end architecture sim;
