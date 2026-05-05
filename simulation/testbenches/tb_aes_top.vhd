----------------------------------------------------------------------------------
-- Module Name:    tb_aes_top
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           29/04/2026
--
-- Description:
--   Self-checking testbench for AES-128 complete core. Tests encryption, decryption,
--   and round-trip verification against FIPS-197 known vectors. Validates all 10 rounds
--   plus final round behavior for both forward and inverse transformations.
--
--   Implementation: Cycle-accurate simulation with assertion-based pass/fail reporting.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_aes_top is
end entity tb_aes_top;

architecture sim of tb_aes_top is

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

    -- Convert std_logic to string for VHDL-1993 compatibility
    function sl_to_string(sl : std_logic) return string is
    begin
        if sl = '1' then
            return "1";
        else
            return "0";
        end if;
    end function;

    signal clk      : std_logic := '0';
    signal rst_n    : std_logic := '0';
    signal start    : std_logic := '0';
    signal enc_dec  : std_logic := '1';
    signal data_in  : std_logic_vector(127 downto 0) := (others => '0');
    signal key_in   : std_logic_vector(127 downto 0) := (others => '0');
    signal data_out : std_logic_vector(127 downto 0);
    signal done     : std_logic;

    component aes_top
        port (
            clk      : in  std_logic;
            rst_n    : in  std_logic;
            start    : in  std_logic;
            enc_dec  : in  std_logic;
            data_in  : in  std_logic_vector(127 downto 0);
            key_in   : in  std_logic_vector(127 downto 0);
            data_out : out std_logic_vector(127 downto 0);
            done     : out std_logic;
            ready    : out std_logic;
            error    : out std_logic
        );
    end component aes_top;
    constant CLK_PERIOD : time := 10 ns;

    -- Test vector type
    type t_test_vector is record
        plaintext  : std_logic_vector(127 downto 0);
        ciphertext : std_logic_vector(127 downto 0);
        key        : std_logic_vector(127 downto 0);
    end record t_test_vector;

    -- Known test vectors from FIPS-197 and additional verified vectors
    type t_test_vectors is array (natural range <>) of t_test_vector;
    constant test_vectors : t_test_vectors := (
        -- FIPS-197 Appendix C.1 (Encryption Example)
        (plaintext  => x"00112233445566778899aabbccddeeff",
         ciphertext => x"69c4e0d86a7b0430d8cdb78070b4c55a",
         key        => x"000102030405060708090a0b0c0d0e0f"),
        
        -- FIPS-197 Appendix C.2 (Additional Test Vector 1)
        (plaintext  => x"6bc1bee22e409f96e93d7e117393172a",
         ciphertext => x"3ad77bb40d7a3660a89ecaf32466ef97",
         key        => x"2b7e151628aed2a6abf7158809cf4f3c"),
        
        -- FIPS-197 Additional Test Vector 2
        (plaintext  => x"ae2d8a571e03ac9c9eb76fac45af8e51",
         ciphertext => x"f5d3d58503b9699de785895a96fdbaaf",
         key        => x"2b7e151628aed2a6abf7158809cf4f3c"),
        
        -- FIPS-197 Additional Test Vector 3
        (plaintext  => x"30c81c46a35ce411e5fbe6fbf7404067",
         ciphertext => x"b6bc73e109eb1e1988362ab019322385",
         key        => x"2b7e151628aed2a6abf7158809cf4f3c"),
        
        -- FIPS-197 Additional Test Vector 4
        (plaintext  => x"f69f2445df4f9b17ad2b417be66c3710",
         ciphertext => x"7b0c785e27e8ad3f8223207104725dd4",
         key        => x"2b7e151628aed2a6abf7158809cf4f3c"),
        
        -- All zeros key and plaintext
        (plaintext  => x"00000000000000000000000000000000",
         ciphertext => x"66e94bd4ef8a2c3b884cfa59ca342b2e",
         key        => x"00000000000000000000000000000000"),
        
        -- All ones key and plaintext
        (plaintext  => x"ffffffffffffffffffffffffffffffff",
         ciphertext => x"bcbf217cb280cf30b2517052193ab979",
         key        => x"ffffffffffffffffffffffffffffffff"),

        -- Walking-One Data Patterns
        (plaintext  => x"00000000000000000000000000000001",
         ciphertext => x"58e2fccefa7e3061367f1d57a4e7455a",
         key        => x"00000000000000000000000000000000"),
        
        (plaintext  => x"80000000000000000000000000000000",
         ciphertext => x"3ad78e726c1ec02b7ebfe92b23d9ec34",
         key        => x"00000000000000000000000000000000"),
        
        (plaintext  => x"00000000000000000000000000000000",
         ciphertext => x"0545aad56da2a97c3663d1432a3d1c84",
         key        => x"00000000000000000000000000000001")
    );

    signal dut_ready : std_logic := '0';
    signal dut_error : std_logic := '0';
    
begin


    u_dut : aes_top port map (
        clk      => clk,
        rst_n    => rst_n,
        start    => start,
        enc_dec  => enc_dec,
        data_in  => data_in,
        key_in   => key_in,
        data_out => data_out,
        done     => done,
        ready    => dut_ready,
        error    => dut_error
    );

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;
    process
        variable pass_cnt, fail_cnt : integer := 0;
        variable enc_pass, enc_fail : integer := 0;
        variable dec_pass, dec_fail : integer := 0;
        variable roundtrip_pass, roundtrip_fail : integer := 0;
        variable output : std_logic_vector(127 downto 0);
        variable timeout : integer;
        variable test_idx : integer;
        variable test_num : integer := 0;
        variable intermediate_result : std_logic_vector(127 downto 0);
        -- Variables for negative test and assertion checks
        variable done_pulses_neg : integer := 0;
        variable cycles_neg : integer := 0;
        variable error_detected : boolean := false;
    begin
         report "==============================" & character'val(10) &
             "Starting AES-128 testbench" & character'val(10) &
             "TB_BUILD: 2026-05-02-DONEWAIT-V2" & character'val(10) &
             "==============================" severity note;

        -- Reset
        rst_n <= '0';
        wait for 100 ns;
        rst_n <= '1';
        wait for 100 ns;
        report "Post-reset: dut_ready=" & sl_to_string(dut_ready) & ", dut_error=" & sl_to_string(dut_error) severity note;

        -- SECTION 1: ENCRYPTION TESTS - Plaintext to Ciphertext with FIPS-197 vectors
        report "SECTION 1: ENCRYPTION TESTS (Plaintext -> Ciphertext)" severity note;
        
        for i in test_vectors'range loop
            test_idx := i + 1;
            test_num := test_num + 1;
            report "Test " & integer'image(test_num) & ": Encrypting with FIPS-197 vector " & 
                   integer'image(test_idx) severity note;
            
            -- Wait until DUT reports ready (clocked polling avoids wait-until deadlock)
            timeout := 0;
            while dut_ready /= '1' and timeout < 5000 loop
                wait until rising_edge(clk);
                timeout := timeout + 1;
            end loop;
            if dut_ready = '1' then
                report "DUT ready detected (dut_ready=1)" severity note;
            else
                report "ERROR: Timeout waiting for dut_ready=1 before encryption start" severity error;
            end if;
            
            -- Drive controls before the sampling edge
            enc_dec <= '1';
            data_in <= test_vectors(i).plaintext;
            key_in <= test_vectors(i).key;
            start <= '1';
            report "Asserting start for encryption (pre-edge drive)" severity note;
            
            -- Sampling edge for start/data/key
            wait until rising_edge(clk);
            -- Hold start for one full clock cycle
            wait until rising_edge(clk);
            start <= '0';
            report "Clearing start signal at time " & time'image(now) severity note;
            
            -- Wait a bit for FSM state changes to propagate through combinational logic
            wait for CLK_PERIOD;
            
            -- Wait for DUT to accept (ready de-asserted) with timeout for debugging
            timeout := 0;
            while dut_ready = '1' and timeout < 100 loop
                wait for 1 ns;
                timeout := timeout + 1;
                if timeout = 50 then
                    report "WARNING: dut_ready still 1 after 50 ns. FSM may not be transitioning." & character'val(10) &
                           "  Current time: " & time'image(now) & ", dut_ready=" & sl_to_string(dut_ready) &
                           ", dut_error=" & sl_to_string(dut_error) severity warning;
                end if;
            end loop;
            
            if dut_ready = '0' then
                report "DUT accepted start (dut_ready=0), waiting for done [DONEWAIT_V2]" severity note;
                report "DEBUG_DONE_AT_ACCEPT: done=" & sl_to_string(done) &
                       ", ready=" & sl_to_string(dut_ready) &
                       ", t=" & time'image(now) severity note;
            else
                report "ERROR: Timeout waiting for dut_ready to go low! FSM stuck in ST_IDLE." severity error;
            end if;

            -- Wait for a fresh done pulse (avoid premature sampling on ready glitches)
            timeout := 0;
            while done = '1' and timeout < 100 loop
                wait until rising_edge(clk);
                timeout := timeout + 1;
            end loop;
            timeout := 0;
            while done = '0' and timeout < 5000 loop
                wait until rising_edge(clk);
                timeout := timeout + 1;
                if timeout <= 3 then
                    report "DEBUG_DONE_WAIT: cycle=" & integer'image(timeout) &
                           ", done=" & sl_to_string(done) &
                           ", ready=" & sl_to_string(dut_ready) &
                           ", t=" & time'image(now) severity note;
                end if;
                if (timeout mod 50) = 0 then
                    report "Waiting for done: timeout=" & integer'image(timeout) &
                           ", dut_ready=" & sl_to_string(dut_ready) severity note;
                end if;
            end loop;

            if done = '1' then
                output := data_out;
                if output = test_vectors(i).ciphertext then
                    report "Test " & integer'image(test_num) & ": PASS" severity note;
                    enc_pass := enc_pass + 1;
                    pass_cnt := pass_cnt + 1;
                else
                    report "Test " & integer'image(test_num) & ": FAIL" & character'val(10) &
                           "  Ciphertext mismatch" & character'val(10) &
                           "  Expected: " & slv_to_hstring(test_vectors(i).ciphertext) & character'val(10) &
                           "  Got:      " & slv_to_hstring(output) severity warning;
                    enc_fail := enc_fail + 1;
                    fail_cnt := fail_cnt + 1;
                end if;
            else
                report "  FAIL: Timeout (done pulse not observed after " & integer'image(timeout) & " cycles)" severity warning;
                enc_fail := enc_fail + 1;
                fail_cnt := fail_cnt + 1;
            end if;

            wait for CLK_PERIOD * 5;
        end loop;

        -- NEGATIVE TEST: Start asserted while operation is in-flight
            report "NEGATIVE TEST: Re-asserting start while operation is running" severity note;
            
            -- Wait until DUT reports ready (clocked polling avoids wait-until deadlock)
            timeout := 0;
            while dut_ready /= '1' and timeout < 5000 loop
                wait until rising_edge(clk);
                timeout := timeout + 1;
            end loop;
            if dut_ready /= '1' then
                report "ERROR: Timeout waiting for dut_ready=1 before negative test" severity error;
            end if;
            
            -- Use first test vector for negative test (drive before edge)
            enc_dec <= '1';
            data_in <= test_vectors(0).plaintext;
            key_in <= test_vectors(0).key;
            start <= '1';
            report "Asserting start for negative test (pre-edge drive)" severity note;
            
            -- Sampling edge for start/data/key
            wait until rising_edge(clk);
            -- Hold start for one full clock cycle
            wait until rising_edge(clk);
            start <= '0';
            report "Cleared start signal for negative test" severity note;

            -- During operation, repeatedly assert start to simulate spurious inputs
            done_pulses_neg := 0;
            cycles_neg := 0;
            error_detected := false;
            while cycles_neg < 200 loop
                -- Wait for clock edge, then re-assert start for a few cycles while DUT is busy
                wait until rising_edge(clk);
                start <= '1';
                wait until rising_edge(clk);
                start <= '0';

                if dut_error = '1' then
                    error_detected := true;
                end if;

                if done = '1' then
                    done_pulses_neg := done_pulses_neg + 1;
                end if;

                cycles_neg := cycles_neg + 1;
                -- break early if we have observed done and allowed a few extra cycles
                if done_pulses_neg > 1 then
                    exit;
                end if;
            end loop;

            test_num := test_num + 1;
            if done_pulses_neg = 1 and error_detected then
                pass_cnt := pass_cnt + 1;
                report "Test " & integer'image(test_num) & ": PASS (dut_error asserted correctly)" severity note;
            else
                fail_cnt := fail_cnt + 1;
                report "Test " & integer'image(test_num) & ": FAIL" & character'val(10) &
                       "  Multiple 'done' assertions or missing 'dut_error' detected when start was re-asserted" & character'val(10) &
                       "  Expected done pulses: 1" & character'val(10) &
                       "  Got done pulses:      " & integer'image(done_pulses_neg) severity warning;
            end if;


        -- SECTION 2: DECRYPTION TESTS - Ciphertext to Plaintext with FIPS-197 vectors
        report "SECTION 2: DECRYPTION TESTS (Ciphertext -> Plaintext)" severity note;
        
        for i in test_vectors'range loop
            test_idx := i + 1;
            test_num := test_num + 1;
            report "Test " & integer'image(test_num) & ": Decrypting with FIPS-197 vector " & 
                   integer'image(test_idx) severity note;
            
            -- Wait until DUT reports ready (clocked polling avoids wait-until deadlock)
            timeout := 0;
            while dut_ready /= '1' and timeout < 5000 loop
                wait until rising_edge(clk);
                timeout := timeout + 1;
            end loop;
            if dut_ready = '1' then
                report "DUT ready detected (dut_ready=1)" severity note;
            else
                report "ERROR: Timeout waiting for dut_ready=1 before decryption start" severity error;
            end if;
            
            -- Drive controls before the sampling edge
            enc_dec <= '0';
            data_in <= test_vectors(i).ciphertext;
            key_in <= test_vectors(i).key;
            start <= '1';
            report "Asserting start for decryption (pre-edge drive)" severity note;
            
            -- Sampling edge for start/data/key
            wait until rising_edge(clk);
            -- Hold start for one full clock cycle
            wait until rising_edge(clk);
            start <= '0';
            report "Clearing start signal at time " & time'image(now) severity note;
            
            -- Wait a bit for FSM state changes to propagate through combinational logic
            wait for CLK_PERIOD;
            
            -- Wait for DUT to accept (ready de-asserted) with timeout for debugging
            timeout := 0;
            while dut_ready = '1' and timeout < 100 loop
                wait for 1 ns;
                timeout := timeout + 1;
                if timeout = 50 then
                    report "WARNING: dut_ready still 1 after 50 ns. FSM may not be transitioning." & character'val(10) &
                           "  Current time: " & time'image(now) & ", dut_ready=" & sl_to_string(dut_ready) &
                           ", dut_error=" & sl_to_string(dut_error) severity warning;
                end if;
            end loop;
            
            if dut_ready = '0' then
                report "DUT accepted start (dut_ready=0), waiting for done" severity note;
            else
                report "ERROR: Timeout waiting for dut_ready to go low! FSM stuck in ST_IDLE." severity error;
            end if;

            -- Wait for a fresh done pulse (avoid premature sampling on ready glitches)
            timeout := 0;
            while done = '1' and timeout < 100 loop
                wait until rising_edge(clk);
                timeout := timeout + 1;
            end loop;

            timeout := 0;
            while done = '0' and timeout < 5000 loop
                wait until rising_edge(clk);
                timeout := timeout + 1;
                if (timeout mod 50) = 0 then
                    report "Waiting for done: timeout=" & integer'image(timeout) &
                           ", dut_ready=" & sl_to_string(dut_ready) severity note;
                end if;
            end loop;

            if done = '1' then
                output := data_out;
                if output = test_vectors(i).plaintext then
                    report "Test " & integer'image(test_num) & ": PASS" severity note;
                    dec_pass := dec_pass + 1;
                    pass_cnt := pass_cnt + 1;
                else
                    report "Test " & integer'image(test_num) & ": FAIL" & character'val(10) &
                           "  Plaintext mismatch" & character'val(10) &
                           "  Expected: " & slv_to_hstring(test_vectors(i).plaintext) & character'val(10) &
                           "  Got:      " & slv_to_hstring(output) severity warning;
                    dec_fail := dec_fail + 1;
                    fail_cnt := fail_cnt + 1;
                end if;
            else
                report "  FAIL: Timeout (done pulse not observed)" severity warning;
                dec_fail := dec_fail + 1;
                fail_cnt := fail_cnt + 1;
            end if;

            wait for CLK_PERIOD * 5;
        end loop;

        -- SECTION 3: ROUND-TRIP VALIDATION - Decrypt(Encrypt(p)) = p
        report "SECTION 3: ROUND-TRIP VALIDATION (Decrypt(Encrypt(p)) = p)" severity note;
        
        for i in test_vectors'range loop
            test_idx := i + 1;
            test_num := test_num + 1;
            report "Test " & integer'image(test_num) & ": Round-trip with vector " & 
                   integer'image(test_idx) severity note;
            
            -- Phase 1: Encrypt
            -- Wait until DUT reports ready (clocked polling avoids wait-until deadlock)
            timeout := 0;
            while dut_ready /= '1' and timeout < 5000 loop
                wait until rising_edge(clk);
                timeout := timeout + 1;
            end loop;
            if dut_ready /= '1' then
                report "ERROR: Timeout waiting for dut_ready=1 before round-trip encrypt" severity error;
            end if;
            enc_dec <= '1';
            data_in <= test_vectors(i).plaintext;
            key_in <= test_vectors(i).key;
            report "Asserting start for round-trip encrypt" severity note;
            start <= '1';
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            start <= '0';
            report "Clearing start signal at time " & time'image(now) severity note;

            -- Wait a bit for FSM state changes to propagate through combinational logic
            wait for CLK_PERIOD;

            -- Wait for DUT to accept (ready de-asserted) with timeout for debugging
            timeout := 0;
            while dut_ready = '1' and timeout < 100 loop
                wait for 1 ns;
                timeout := timeout + 1;
            end loop;

            if dut_ready = '0' then
                report "DUT accepted start (dut_ready=0), waiting for encrypt done" severity note;
            else
                report "ERROR: Timeout waiting for dut_ready to go low in round-trip encrypt." severity error;
            end if;
            timeout := 0;
            while done = '1' and timeout < 100 loop
                wait until rising_edge(clk);
                timeout := timeout + 1;
            end loop;

            timeout := 0;
            while done = '0' and timeout < 5000 loop
                wait until rising_edge(clk);
                timeout := timeout + 1;
                if (timeout mod 50) = 0 then
                    report "Waiting for done: timeout=" & integer'image(timeout) &
                           ", dut_ready=" & sl_to_string(dut_ready) severity note;
                end if;
            end loop;

            if done = '1' then
                intermediate_result := data_out;
            else
                report "Test " & integer'image(test_num) & ": FAIL" & character'val(10) &
                       "  Round-trip encrypt phase timeout" severity warning;
                roundtrip_fail := roundtrip_fail + 1;
                fail_cnt := fail_cnt + 1;
                wait for CLK_PERIOD * 5;
                next;
            end if;

            wait for CLK_PERIOD * 5;

            -- Phase 2: Decrypt the result
            -- Wait until DUT reports ready again (clocked polling avoids wait-until deadlock)
            timeout := 0;
            while dut_ready /= '1' and timeout < 5000 loop
                wait until rising_edge(clk);
                timeout := timeout + 1;
            end loop;
            if dut_ready /= '1' then
                report "ERROR: Timeout waiting for dut_ready=1 before round-trip decrypt" severity error;
            end if;
            enc_dec <= '0';
            data_in <= intermediate_result;
            key_in <= test_vectors(i).key;
            report "Asserting start for round-trip decrypt" severity note;
            start <= '1';
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            start <= '0';
            report "Clearing start signal at time " & time'image(now) severity note;

            -- Wait a bit for FSM state changes to propagate through combinational logic
            wait for CLK_PERIOD;

            -- Wait for DUT to accept (ready de-asserted) with timeout for debugging
            timeout := 0;
            while dut_ready = '1' and timeout < 100 loop
                wait for 1 ns;
                timeout := timeout + 1;
            end loop;

            if dut_ready = '0' then
                report "DUT accepted start (dut_ready=0), waiting for decrypt done" severity note;
            else
                report "ERROR: Timeout waiting for dut_ready to go low in round-trip decrypt." severity error;
            end if;

            timeout := 0;
            while done = '1' and timeout < 100 loop
                wait until rising_edge(clk);
                timeout := timeout + 1;
            end loop;

            timeout := 0;
            while done = '0' and timeout < 250 loop
                wait until rising_edge(clk);
                timeout := timeout + 1;
            end loop;

            if done = '1' then
                output := data_out;
                if output = test_vectors(i).plaintext then
                    report "Test " & integer'image(test_num) & ": PASS" severity note;
                    roundtrip_pass := roundtrip_pass + 1;
                    pass_cnt := pass_cnt + 1;
                else
                    report "Test " & integer'image(test_num) & ": FAIL" & character'val(10) &
                           "  Round-trip recovered plaintext mismatch" & character'val(10) &
                           "  Expected: " & slv_to_hstring(test_vectors(i).plaintext) & character'val(10) &
                           "  Got:      " & slv_to_hstring(output) severity warning;
                    roundtrip_fail := roundtrip_fail + 1;
                    fail_cnt := fail_cnt + 1;
                end if;
            else
                report "Test " & integer'image(test_num) & ": FAIL" & character'val(10) &
                       "  Round-trip decrypt phase timeout" severity warning;
                roundtrip_fail := roundtrip_fail + 1;
                fail_cnt := fail_cnt + 1;
            end if;

            wait for CLK_PERIOD * 5;
        end loop;

         report "==============================" & character'val(10) &
             "FINAL REPORT" & character'val(10) &
             "ENCRYPTION: " & integer'image(enc_pass) & " PASS, " & integer'image(enc_fail) & " FAIL" & character'val(10) &
             "DECRYPTION: " & integer'image(dec_pass) & " PASS, " & integer'image(dec_fail) & " FAIL" & character'val(10) &
             "ROUND-TRIP: " & integer'image(roundtrip_pass) & " PASS, " & integer'image(roundtrip_fail) & " FAIL" & character'val(10) &
             "TOTAL: " & integer'image(pass_cnt) & " PASS, " & integer'image(fail_cnt) & " FAIL" & character'val(10) &
             "==============================" severity note;
        wait;
    end process;

end architecture sim;