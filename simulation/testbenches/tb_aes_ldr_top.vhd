----------------------------------------------------------------------------------
-- Test Bench Name: tb_aes_ldr_top
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           15/05/2026
--
-- Description:
--   Testbench for ldr_sampler_fsm + aes_top integration.
--   Simulates:
--     1. XADC periodic reads every 5 seconds
--     2. ADC value padding and encryption
--     3. Result buffering
--   Uses mock XADC model (returns constant 12-bit ADC values)
--
--   Note: Full aes_ldr_top simulation requires XADC IP behavioral model.
--   This testbench focuses on ldr_sampler_fsm FSM logic.
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_aes_ldr_top is
end entity tb_aes_ldr_top;

architecture sim of tb_aes_ldr_top is

    -- =========================================================================
    -- Component Declarations
    -- =========================================================================
    
    component ldr_sampler_fsm
        port (
            clk           : in  std_logic;
            rst_n         : in  std_logic;
            manual_trigger : in  std_logic;
            xadc_valid    : in  std_logic;
            xadc_data     : in  std_logic_vector(15 downto 0);
            xadc_ready    : out std_logic;
            aes_start     : out std_logic;
            aes_done      : in  std_logic;
            aes_key       : in  std_logic_vector(127 downto 0);
            aes_data      : out std_logic_vector(127 downto 0);
            aes_out       : in  std_logic_vector(127 downto 0);
            result_ready  : out std_logic;
            encrypted     : out std_logic_vector(127 downto 0);
            adc_raw       : out std_logic_vector(11 downto 0);
            sample_count  : out std_logic_vector(31 downto 0)
        );
    end component ldr_sampler_fsm;

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

    -- =========================================================================
    -- Test Signals
    -- =========================================================================
    
    signal clk : std_logic := '0';
    signal rst_n : std_logic := '0';
    signal manual_trigger : std_logic := '0';
    
    -- XADC mock interface
    signal xadc_valid : std_logic := '0';
    signal xadc_data : std_logic_vector(15 downto 0) := (others => '0');
    signal xadc_ready : std_logic;
    signal xadc_mock_adc : std_logic_vector(11 downto 0) := (others => '0');
    
    -- LDR sampler FSM signals
    signal sampler_aes_start : std_logic;
    signal sampler_aes_data : std_logic_vector(127 downto 0);
    signal sampler_result_ready : std_logic;
    signal sampler_encrypted : std_logic_vector(127 downto 0);
    signal sampler_adc_raw : std_logic_vector(11 downto 0);
    signal sampler_count : std_logic_vector(31 downto 0);
    
    -- AES core signals
    signal aes_done : std_logic;
    signal aes_data_out : std_logic_vector(127 downto 0);
    signal aes_ready : std_logic;
    signal aes_error : std_logic;
    
    -- Test key (FIPS-197 vector 1)
    constant TEST_KEY : std_logic_vector(127 downto 0) := 
        x"000102030405060708090a0b0c0d0e0f";
    
    -- Clock period: 10 ns (100 MHz)
    constant CLK_PERIOD : time := 10 ns;
    
    -- Simulation timing
    signal sim_time : integer := 0;
    signal cycle_count : integer := 0;
    
begin

    -- =========================================================================
    -- Clock Generation
    -- =========================================================================
    
    clk <= not clk after CLK_PERIOD / 2;
    
    process(clk)
    begin
        if rising_edge(clk) then
            cycle_count <= cycle_count + 1;
        end if;
    end process;
    
    -- =========================================================================
    -- XADC Mock Model
    -- =========================================================================
    -- Simulates XADC behavior: request → 2 cycles later, return valid data
    
    process
        variable xadc_request_time : integer := 0;
        variable adc_counter : integer := 0;
    begin
        wait until rising_edge(clk);
        
        -- When sampler requests a read, respond after 2-cycle latency
        if xadc_ready = '1' then
            xadc_request_time := cycle_count;
            adc_counter := adc_counter + 1;
            xadc_mock_adc <= std_logic_vector(to_unsigned(256 + adc_counter, 12));
            report "[XADC] Read request at cycle " & integer'image(cycle_count);
        end if;
        
        -- Simulate 2-cycle latency, then return valid data
        if cycle_count = xadc_request_time + 2 then
            xadc_data <= (15 downto 12 => '0') & xadc_mock_adc;  -- status[3:0] + ADC[11:0]
            xadc_valid <= '1';
            report "[XADC] Data valid at cycle " & integer'image(cycle_count) & 
                   ", ADC value: 0x" & to_hstring(xadc_mock_adc);
        else
            xadc_valid <= '0';
        end if;
    end process;

    -- =========================================================================
    -- Instantiate LDR Sampler FSM
    -- =========================================================================
    
    u_sampler : ldr_sampler_fsm
        port map (
            clk           => clk,
            rst_n         => rst_n,
            manual_trigger => manual_trigger,
            xadc_valid    => xadc_valid,
            xadc_data     => xadc_data,
            xadc_ready    => xadc_ready,
            aes_start     => sampler_aes_start,
            aes_done      => aes_done,
            aes_key       => TEST_KEY,
            aes_data      => sampler_aes_data,
            aes_out       => aes_data_out,
            result_ready  => sampler_result_ready,
            encrypted     => sampler_encrypted,
            adc_raw       => sampler_adc_raw,
            sample_count  => sampler_count
        );

    -- =========================================================================
    -- Instantiate AES Core
    -- =========================================================================
    
    u_aes : aes_top
        port map (
            clk      => clk,
            rst_n    => rst_n,
            start    => sampler_aes_start,
            enc_dec  => '1',  -- always encrypt
            data_in  => sampler_aes_data,
            key_in   => TEST_KEY,
            data_out => aes_data_out,
            done     => aes_done,
            ready    => aes_ready,
            error    => aes_error
        );

    -- =========================================================================
    -- Main Test Process
    -- =========================================================================
    
    process
        variable sample_number : integer := 0;
        variable expected_plaintext : std_logic_vector(127 downto 0);
    begin
        -- Start in reset
        rst_n <= '0';
        report "[TEST] Simulation started, reset asserted";
        wait for 100 ns;
        
        -- Release reset
        rst_n <= '1';
        report "[TEST] Reset released, sampler FSM entering IDLE";
        wait for 50 ns;

        -- =====================================================================
        -- TEST 1: First automatic sample (after 5 seconds)
        -- =====================================================================
        
        report "[TEST] === SAMPLE 1: Waiting for first 5-second timer ======================";
        
        -- For simulation, wait a short time window for sampler_result_ready
        wait until sampler_result_ready = '1' for 600 ms;
        
        if sampler_result_ready = '1' then
            sample_number := 1;
            report "[TEST] Sample " & integer'image(sample_number) & " encrypted successfully";
            report "[TEST]   Raw ADC value: 0x" & to_hstring(sampler_adc_raw);
            report "[TEST]   Encrypted: 0x" & to_hstring(sampler_encrypted);
            report "[TEST]   Sample count: " & integer'image(to_integer(unsigned(sampler_count)));
            wait for 10 ns;
        else
            report "[TEST] ERROR: First sample timeout (expected after ~500M cycles)";
        end if;

        -- =====================================================================
        -- TEST 2: Wait for second sample
        -- =====================================================================
        
        report "[TEST] === SAMPLE 2: Waiting for second 5-second timer ======================";
        wait until sampler_result_ready = '1' for 600 ms;
        
        if sampler_result_ready = '1' then
            sample_number := 2;
            report "[TEST] Sample " & integer'image(sample_number) & " encrypted successfully";
            report "[TEST]   Raw ADC value: 0x" & to_hstring(sampler_adc_raw);
            report "[TEST]   Encrypted: 0x" & to_hstring(sampler_encrypted);
            report "[TEST]   Sample count: " & integer'image(to_integer(unsigned(sampler_count)));
            wait for 10 ns;
        else
            report "[TEST] ERROR: Second sample timeout";
        end if;

        -- =====================================================================
        -- TEST 3: Manual trigger (immediate, no waiting for timer)
        -- =====================================================================
        
        report "[TEST] === MANUAL TRIGGER TEST ==========================================";
        manual_trigger <= '1';
        wait for CLK_PERIOD;
        manual_trigger <= '0';
        
        wait until sampler_result_ready = '1' for 100 us;
        
        if sampler_result_ready = '1' then
            report "[TEST] Manual trigger successful";
            report "[TEST]   Raw ADC value: 0x" & to_hstring(sampler_adc_raw);
            report "[TEST]   Sample count: " & integer'image(to_integer(unsigned(sampler_count)));
        else
            report "[TEST] ERROR: Manual trigger timeout";
        end if;

        -- =====================================================================
        -- TEST 4: Verify plaintext padding logic
        -- =====================================================================
        
        report "[TEST] === PLAINTEXT PADDING VERIFICATION ===============================";
        
        expected_plaintext := (127 downto 12 => '0') & sampler_adc_raw;
        
        if sampler_aes_data = expected_plaintext then
            report "[TEST] Padding verification PASSED";
            report "[TEST]   Expected: 0x" & to_hstring(expected_plaintext);
            report "[TEST]   Got:      0x" & to_hstring(sampler_aes_data);
        else
            report "[TEST] ERROR: Padding mismatch!";
            report "[TEST]   Expected: 0x" & to_hstring(expected_plaintext);
            report "[TEST]   Got:      0x" & to_hstring(sampler_aes_data);
        end if;

        -- =====================================================================
        -- Test Summary
        -- =====================================================================
        
        report "[TEST] ============================================================";
        report "[TEST] SIMULATION COMPLETE";
        report "[TEST]   Total samples captured: " & integer'image(to_integer(unsigned(sampler_count)));
        report "[TEST] ============================================================";
        
        wait;
    end process;

    -- =========================================================================
    -- Monitoring Process (prints FSM state transitions)
    -- =========================================================================
    
    process
    begin
        wait until rising_edge(clk);
        
        if cycle_count mod 100000000 = 0 then
            report "[MONITOR] Cycle: " & integer'image(cycle_count) & 
                   " (" & integer'image(cycle_count / 10000000) & " x 100M cycles, " &
                   real'image(real(cycle_count) / 100_000_000.0) & " seconds)";
        end if;
        
        if sampler_aes_start = '1' then
            report "[AES] Start signal asserted, plaintext: 0x" & to_hstring(sampler_aes_data);
        end if;
        
        if aes_done = '1' then
            report "[AES] Done signal asserted, ciphertext: 0x" & to_hstring(aes_data_out);
        end if;
        
        if sampler_result_ready = '1' then
            report "[SAMPLER] Result ready, sample count: " & integer'image(to_integer(unsigned(sampler_count)));
        end if;
    end process;

end architecture sim;
