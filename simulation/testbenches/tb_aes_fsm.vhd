----------------------------------------------------------------------------------
-- Module Name:    tb_aes_fsm
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           17/05/2026
--
-- Description:
--   Unit testbench for the AES control FSM. Validates reset behavior, ready/done
--   sequencing, round-index progression, and busy-start immunity.
--
--   Implementation: Self-checking clocked stimulus with cycle-by-cycle control
--   signal verification.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_aes_fsm is
end entity tb_aes_fsm;

architecture sim of tb_aes_fsm is

    function sl_to_string(sl : std_logic) return string is
    begin
        if sl = '1' then
            return "1";
        else
            return "0";
        end if;
    end function;

    component aes_fsm
        port (
            clk       : in  std_logic;
            rst_n     : in  std_logic;
            start     : in  std_logic;
            done      : out std_logic;
            round_idx : out std_logic_vector(3 downto 0);
            state_ld  : out std_logic;
            state_en  : out std_logic;
            key_ld    : out std_logic;
            first_rnd : out std_logic;
            final_rnd : out std_logic;
            ready     : out std_logic;
            error     : out std_logic
        );
    end component aes_fsm;

    signal clk       : std_logic := '0';
    signal rst_n     : std_logic := '0';
    signal start     : std_logic := '0';
    signal done      : std_logic;
    signal round_idx : std_logic_vector(3 downto 0);
    signal state_ld  : std_logic;
    signal state_en  : std_logic;
    signal key_ld    : std_logic;
    signal first_rnd : std_logic;
    signal final_rnd : std_logic;
    signal ready     : std_logic;
    signal error     : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin

    u_dut : aes_fsm
        port map (
            clk       => clk,
            rst_n     => rst_n,
            start     => start,
            done      => done,
            round_idx => round_idx,
            state_ld  => state_ld,
            state_en  => state_en,
            key_ld    => key_ld,
            first_rnd => first_rnd,
            final_rnd => final_rnd,
            ready     => ready,
            error     => error
        );

    clk <= not clk after CLK_PERIOD / 2;

    stim_proc : process
        variable pass_cnt : integer := 0;
        variable fail_cnt : integer := 0;
        variable test_num : integer := 0;
    begin
        report "==============================" & character'val(10) &
            "Starting tb_aes_fsm" & character'val(10) &
            "==============================" severity note;

        rst_n <= '0';
        start <= '0';
        wait for 50 ns;

        test_num := test_num + 1;
        if ready = '1' and done = '0' and error = '0' then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS - reset places FSM in ready idle" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL - reset state mismatch" severity warning;
        end if;

        rst_n <= '1';
        wait for 20 ns;

        test_num := test_num + 1;
        if ready = '1' and done = '0' and error = '0' then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS - FSM ready after reset release" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL - ready should be high in idle" severity warning;
        end if;

        test_num := test_num + 1;
        start <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        if state_ld = '1' and ready = '0' and done = '0' and round_idx = x"0" then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS - load state entered after start" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL - expected ST_LOAD outputs" severity warning;
        end if;

        test_num := test_num + 1;
        wait until rising_edge(clk);
        wait for 1 ns;
        if state_en = '1' and first_rnd = '1' and final_rnd = '0' and round_idx = x"0" then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS - initial AddRoundKey phase" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL - initial round control mismatch" severity warning;
        end if;

        for round_value in 1 to 9 loop
            test_num := test_num + 1;
            wait until rising_edge(clk);
            wait for 1 ns;
            if state_en = '1' and final_rnd = '0' and first_rnd = '0' and round_idx = std_logic_vector(to_unsigned(round_value, 4)) then
                pass_cnt := pass_cnt + 1;
                report "Test " & integer'image(test_num) & ": PASS - round " & integer'image(round_value) & " control" severity note;
            else
                fail_cnt := fail_cnt + 1;
                report "Test " & integer'image(test_num) & ": FAIL - round " & integer'image(round_value) & " control mismatch" severity warning;
            end if;

            if round_value = 4 then
                start <= '1';
            elsif round_value = 5 then
                start <= '0';
            end if;
        end loop;

        test_num := test_num + 1;
        wait until rising_edge(clk);
        wait for 1 ns;
        if state_en = '1' and final_rnd = '1' and round_idx = x"A" then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS - final round control" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL - final round control mismatch" severity warning;
        end if;

        test_num := test_num + 1;
        wait until rising_edge(clk);
        wait for 1 ns;
        if done = '1' and ready = '0' then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS - done asserted in output state" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL - done pulse missing" severity warning;
        end if;

        start <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;

        test_num := test_num + 1;
        if ready = '1' and done = '0' then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS - FSM returned to idle after transaction" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL - FSM did not return to idle" severity warning;
        end if;

        report "==============================" & character'val(10) &
            "FINAL REPORT" & character'val(10) &
            "PASS: " & integer'image(pass_cnt) & character'val(10) &
            "FAIL: " & integer'image(fail_cnt) & character'val(10) &
            "==============================" severity note;

        wait;
    end process;

end architecture sim;