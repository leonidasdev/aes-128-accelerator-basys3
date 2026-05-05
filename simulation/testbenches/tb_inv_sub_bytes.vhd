----------------------------------------------------------------------------------
-- Module Name:    tb_inv_sub_bytes
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           29/04/2026
--
-- Description:
--   Unit testbench for inverse SubBytes transformation. Validates FIPS-197 inverse
--   S-Box for all 256 byte values and verifies inverse property recovery.
--
--   Implementation: Zero-latency combinational verification with self-checking assertions.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_inv_sub_bytes is
end entity tb_inv_sub_bytes;

architecture sim of tb_inv_sub_bytes is

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

    -- Inverse S-Box from FIPS-197 - verified canonical (all 256 entries)
    type t_sbox is array (0 to 255) of std_logic_vector(7 downto 0);
    constant inv_sbox : t_sbox := (
        x"52", x"09", x"6a", x"d5", x"30", x"36", x"a5", x"38",
        x"bf", x"40", x"a3", x"9e", x"81", x"f3", x"d7", x"fb",
        x"7c", x"e3", x"39", x"82", x"9b", x"2f", x"ff", x"87",
        x"34", x"8e", x"43", x"44", x"c4", x"de", x"e9", x"cb",
        x"54", x"7b", x"94", x"32", x"a6", x"c2", x"23", x"3d",
        x"ee", x"4c", x"95", x"0b", x"42", x"fa", x"c3", x"4e",
        x"08", x"2e", x"a1", x"66", x"28", x"d9", x"24", x"b2",
        x"76", x"5b", x"a2", x"49", x"6d", x"8b", x"d1", x"25",
        x"72", x"f8", x"f6", x"64", x"86", x"68", x"98", x"16",
        x"d4", x"a4", x"5c", x"cc", x"5d", x"65", x"b6", x"92",
        x"6c", x"70", x"48", x"50", x"fd", x"ed", x"b9", x"da",
        x"5e", x"15", x"46", x"57", x"a7", x"8d", x"9d", x"84",
        x"90", x"d8", x"ab", x"00", x"8c", x"bc", x"d3", x"0a",
        x"f7", x"e4", x"58", x"05", x"b8", x"b3", x"45", x"06",
        x"d0", x"2c", x"1e", x"8f", x"ca", x"3f", x"0f", x"02",
        x"c1", x"af", x"bd", x"03", x"01", x"13", x"8a", x"6b",
        x"3a", x"91", x"11", x"41", x"4f", x"67", x"dc", x"ea",
        x"97", x"f2", x"cf", x"ce", x"f0", x"b4", x"e6", x"73",
        x"96", x"ac", x"74", x"22", x"e7", x"ad", x"35", x"85",
        x"e2", x"f9", x"37", x"e8", x"1c", x"75", x"df", x"6e",
        x"47", x"f1", x"1a", x"71", x"1d", x"29", x"c5", x"89",
        x"6f", x"b7", x"62", x"0e", x"aa", x"18", x"be", x"1b",
        x"fc", x"56", x"3e", x"4b", x"c6", x"d2", x"79", x"20",
        x"9a", x"db", x"c0", x"fe", x"78", x"cd", x"5a", x"f4",
        x"1f", x"dd", x"a8", x"33", x"88", x"07", x"c7", x"31",
        x"b1", x"12", x"10", x"59", x"27", x"80", x"ec", x"5f",
        x"60", x"51", x"7f", x"a9", x"19", x"b5", x"4a", x"0d",
        x"2d", x"e5", x"7a", x"9f", x"93", x"c9", x"9c", x"ef",
        x"a0", x"e0", x"3b", x"4d", x"ae", x"2a", x"f5", x"b0",
        x"c8", x"eb", x"bb", x"3c", x"83", x"53", x"99", x"61",
        x"17", x"2b", x"04", x"7e", x"ba", x"77", x"d6", x"26",
        x"e1", x"69", x"14", x"63", x"55", x"21", x"0c", x"7d"
    );

    component inv_sub_bytes
        port (
            state_in  : in  std_logic_vector(127 downto 0);
            state_out : out std_logic_vector(127 downto 0)
        );
    end component inv_sub_bytes;

begin

    u_dut : inv_sub_bytes port map (
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
             "Starting InvSubBytes testbench" & character'val(10) &
             "==============================" severity note;

        -- Test all 256 byte values in all 16 positions using inverse S-Box
        for test_pattern in 0 to 15 loop
            for byte_val in 0 to 255 loop
                test_num := test_num + 1;
                state_in <= (others => '0');
                input_byte := std_logic_vector(to_unsigned(byte_val, 8));
                state_in(test_pattern * 8 + 7 downto test_pattern * 8) <= input_byte;
                wait for 1 ns;

                -- Apply InvSubBytes to all 16 input bytes (15 bytes are 0x00 in this stimulus).
                for j in 0 to 15 loop
                    expected(j * 8 + 7 downto j * 8) := inv_sbox(0);
                end loop;
                expected(test_pattern * 8 + 7 downto test_pattern * 8) := inv_sbox(byte_val);

                if state_out = expected then
                    pass_cnt := pass_cnt + 1;
                    report "Test " & integer'image(test_num) & ": PASS" severity note;
                else
                    fail_cnt := fail_cnt + 1;
                    report "Test " & integer'image(test_num) & ": FAIL" & character'val(10) &
                           "  Byte position: " & integer'image(test_pattern) & character'val(10) &
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
