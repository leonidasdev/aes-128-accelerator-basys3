--
-- Purpose:   Self-checking testbench for AddRoundKey transformation.
-- Author:    PHR26-T03
-- Date:      29/04/2026
--
-- Description:
-- Tests the AddRoundKey module by verifying the 128-bit XOR operation.
-- Verifies that the XOR of state and round key produces expected outputs.
-- Tests include: zero key, self-inverse property, and pattern-based vectors.
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_add_round_key is
end entity tb_add_round_key;

architecture sim of tb_add_round_key is

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

    component add_round_key
        port (
            state_in  : in  std_logic_vector(127 downto 0);
            key_in    : in  std_logic_vector(127 downto 0);
            state_out : out std_logic_vector(127 downto 0)
        );
    end component;

    signal state_in  : std_logic_vector(127 downto 0) := (others => '0');
    signal key_in    : std_logic_vector(127 downto 0) := (others => '0');
    signal state_out : std_logic_vector(127 downto 0);

begin

    u_dut : add_round_key port map (
        state_in  => state_in,
        key_in    => key_in,
        state_out => state_out
    );

    stim_proc: process
        variable expected : std_logic_vector(127 downto 0);
        variable s, k    : std_logic_vector(127 downto 0);
        variable pass_cnt : integer := 0;
        variable fail_cnt : integer := 0;
        variable test_num : integer := 0;
    begin
        report "==============================" & character'val(10) &
            "Starting add_round_key testbench" & character'val(10) &
            "==============================" severity note;

        -- Test 1: All zeros key (output should equal state, since state XOR 0 = state)
        test_num := test_num + 1;
        state_in <= x"00112233445566778899AABBCCDDEEFF";
        key_in   <= (others => '0');
        wait for 20 ns;
        s := state_in;
        k := key_in;
        for i in expected'range loop
            expected(i) := s(i) xor k(i);
        end loop;
        if state_out = expected then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL" & character'val(10) &
                   "  Expected: " & slv_to_hstring(expected) & character'val(10) &
                   "  Got:      " & slv_to_hstring(state_out) severity warning;
        end if;

        -- Test 2: Self-inverse check (all ones XOR all ones = all zeros)
        test_num := test_num + 1;
        state_in <= (others => '1');
        key_in   <= (others => '1');
        wait for 20 ns;
        s := state_in;
        k := key_in;
        for i in expected'range loop
            expected(i) := s(i) xor k(i);
        end loop;
        if state_out = expected then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL" & character'val(10) &
                   "  Expected: " & slv_to_hstring(expected) & character'val(10) &
                   "  Got:      " & slv_to_hstring(state_out) severity warning;
        end if;

        -- Test 3: Pattern-based vector (alternating pattern)
        test_num := test_num + 1;
        state_in <= x"FFFFFFFF00000000FFFFFFFF00000000";
        key_in   <= x"00000000FFFFFFFF00000000FFFFFFFF";
        wait for 20 ns;
        s := state_in;
        k := key_in;
        for i in expected'range loop
            expected(i) := s(i) xor k(i);
        end loop;
        if state_out = expected then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL" & character'val(10) &
                   "  Expected: " & slv_to_hstring(expected) & character'val(10) &
                   "  Got:      " & slv_to_hstring(state_out) severity warning;
        end if;

        report "==============================" & character'val(10) &
            "FINAL REPORT" & character'val(10) &
            "PASS: " & integer'image(pass_cnt) & character'val(10) &
            "FAIL: " & integer'image(fail_cnt) & character'val(10) &
            "==============================" severity note;
        wait;
    end process;

end architecture sim;
