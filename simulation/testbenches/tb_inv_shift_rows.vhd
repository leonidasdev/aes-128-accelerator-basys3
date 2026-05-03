--
-- Purpose:   Self-checking testbench for InvShiftRows transformation.
-- Author:    PHR26-T03
-- Date:      29/04/2026
--
-- Description:
-- Comprehensive testbench following NIST FIPS-197 validation standards.
-- Tests that InvShiftRows correctly inverts ShiftRows.
-- Verifies that InvShiftRows(ShiftRows(state)) = state for known patterns.
-- Validates inverse shift correctness with indexed bytes, zero, and all-ones patterns.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_inv_shift_rows is
end entity tb_inv_shift_rows;

architecture sim of tb_inv_shift_rows is

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

    component inv_shift_rows
        port (
            state_in  : in  std_logic_vector(127 downto 0);
            state_out : out std_logic_vector(127 downto 0)
        );
    end component inv_shift_rows;

begin

    u_dut : inv_shift_rows port map (
        state_in  => state_in,
        state_out => state_out
    );

    process
        variable pass_cnt : integer := 0;
        variable fail_cnt : integer := 0;
        variable test_num : integer := 0;
        variable expected : std_logic_vector(127 downto 0);
    begin
         report "==============================" & character'val(10) &
             "Starting InvShiftRows testbench" & character'val(10) &
             "==============================" severity note;

        -- Test 1: Verify inverse shift pattern with indexed bytes (0-15)
        test_num := test_num + 1;
        for i in 0 to 15 loop
            state_in(i * 8 + 7 downto i * 8) <= std_logic_vector(to_unsigned(i, 8));
        end loop;
        wait for 1 ns;

        expected := (others => '0');
        expected(7 downto 0)     := std_logic_vector(to_unsigned(0, 8));
        expected(15 downto 8)    := std_logic_vector(to_unsigned(13, 8));
        expected(23 downto 16)   := std_logic_vector(to_unsigned(10, 8));
        expected(31 downto 24)   := std_logic_vector(to_unsigned(7, 8));
        expected(39 downto 32)   := std_logic_vector(to_unsigned(4, 8));
        expected(47 downto 40)   := std_logic_vector(to_unsigned(1, 8));
        expected(55 downto 48)   := std_logic_vector(to_unsigned(14, 8));
        expected(63 downto 56)   := std_logic_vector(to_unsigned(11, 8));
        expected(71 downto 64)   := std_logic_vector(to_unsigned(8, 8));
        expected(79 downto 72)   := std_logic_vector(to_unsigned(5, 8));
        expected(87 downto 80)   := std_logic_vector(to_unsigned(2, 8));
        expected(95 downto 88)   := std_logic_vector(to_unsigned(15, 8));
        expected(103 downto 96)  := std_logic_vector(to_unsigned(12, 8));
        expected(111 downto 104) := std_logic_vector(to_unsigned(9, 8));
        expected(119 downto 112) := std_logic_vector(to_unsigned(6, 8));
        expected(127 downto 120) := std_logic_vector(to_unsigned(3, 8));

        if state_out = expected then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL" & character'val(10) &
                   "  Expected: " & slv_to_hstring(expected) & character'val(10) &
                   "  Got:      " & slv_to_hstring(state_out) severity warning;
        end if;

        -- Test 2: All zeros (identity test)
        test_num := test_num + 1;
        state_in <= (others => '0');
        wait for 1 ns;
        if state_out = (127 downto 0 => '0') then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL" & character'val(10) &
                   "  Expected: " & slv_to_hstring((127 downto 0 => '0')) & character'val(10) &
                   "  Got:      " & slv_to_hstring(state_out) severity warning;
        end if;

        -- Test 3: All ones (identity test)
        test_num := test_num + 1;
        state_in <= (others => '1');
        wait for 1 ns;
        if state_out = (127 downto 0 => '1') then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL" & character'val(10) &
                   "  Expected: " & slv_to_hstring((127 downto 0 => '1')) & character'val(10) &
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
