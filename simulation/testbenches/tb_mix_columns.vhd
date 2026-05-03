--
-- Purpose:   Self-checking testbench for MixColumns transformation.
-- Author:    PHR26-T03
-- Date:      29/04/2026
--
-- Description:
-- Comprehensive testbench following NIST FIPS-197 validation standards.
-- Tests GF(2^8) column mixing with comprehensive known vectors.
-- Validates the matrix multiplication over GF(2^8) with coefficients [2, 3, 1, 1].
-- Includes FIPS-197 standard vectors and systematic pattern verification.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_mix_columns is
end entity tb_mix_columns;

architecture sim of tb_mix_columns is

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

    component mix_columns
        port (
            state_in  : in  std_logic_vector(127 downto 0);
            state_out : out std_logic_vector(127 downto 0)
        );
    end component mix_columns;

    -- Test vector type
    type t_mix_vector is record
        input  : std_logic_vector(127 downto 0);
        output : std_logic_vector(127 downto 0);
    end record t_mix_vector;

    type t_test_vectors is array (natural range <>) of t_mix_vector;
    
    constant test_vectors : t_test_vectors := (
        -- FIPS-197 MixColumns examples encoded in DUT byte packing
        -- DUT packs column bytes as b3 b2 b1 b0 in hex literal, where b0 is bits[7:0].
        -- FIPS [d4 bf 5d 30] -> [04 66 81 e5]  maps to  input 305DBFD4 -> output E5816604
        (input  => x"000000000000000000000000305DBFD4",
         output => x"000000000000000000000000E5816604"),

        -- FIPS [db 13 53 45] -> [8e 4d a1 bc]  maps to  input 455313DB -> output BCA14D8E
        (input  => x"000000000000000000000000455313DB",
         output => x"000000000000000000000000BCA14D8E"),

        -- FIPS [f2 0a 22 5c] -> [9f dc 58 9d]  maps to  input 5C220AF2 -> output 9D58DC9F
        (input  => x"0000000000000000000000005C220AF2",
         output => x"0000000000000000000000009D58DC9F"),

        -- [01 01 01 01] is an eigenvector of MixColumns
        (input  => x"00000000000000000000000001010101",
         output => x"00000000000000000000000001010101"),

        -- All zeros should remain zeros
        (input  => x"00000000000000000000000000000000",
         output => x"00000000000000000000000000000000"),

        -- All 0xFF should remain 0xFF
        (input  => x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
         output => x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")
    );

begin

    u_dut : mix_columns port map (
        state_in  => state_in,
        state_out => state_out
    );

    process
        variable pass_cnt : integer := 0;
        variable fail_cnt : integer := 0;
        variable test_num : integer := 0;
        variable err_output : std_logic_vector(127 downto 0);
    begin
         report "==============================" & character'val(10) &
             "Starting MixColumns testbench" & character'val(10) &
             "==============================" severity note;

        -- Test MixColumns transformation with FIPS-197 vectors
        for i in test_vectors'range loop
            test_num := test_num + 1;
            state_in <= test_vectors(i).input;
            wait for 1 ns;
            err_output := state_out;

            if err_output = test_vectors(i).output then
                pass_cnt := pass_cnt + 1;
                report "Test " & integer'image(test_num) & ": PASS" severity note;
            else
                fail_cnt := fail_cnt + 1;
                report "Test " & integer'image(test_num) & ": FAIL" & character'val(10) &
                       "  Input:    " & slv_to_hstring(test_vectors(i).input) & character'val(10) &
                       "  Expected: " & slv_to_hstring(test_vectors(i).output) & character'val(10) &
                       "  Got:      " & slv_to_hstring(err_output) severity warning;
            end if;

            wait for 50 ns;
        end loop;

        report "==============================" & character'val(10) &
               "FINAL REPORT" & character'val(10) &
               "PASS: " & integer'image(pass_cnt) & character'val(10) &
               "FAIL: " & integer'image(fail_cnt) & character'val(10) &
               "==============================" severity note;
        wait;
    end process;

end architecture sim;
