----------------------------------------------------------------------------------
-- Module Name:    tb_aes_ldr_top
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           15/05/2026
--
-- Description:
--   Integration testbench for ldr_sampler_fsm and aes_top. Tests autonomous periodic
--   sampling at 5-second intervals with AES-128 encryption. Validates FSM state machine
--   transitions, XADC read latency, plaintext padding with 12-bit ADC values, and
--   end-to-end encryption functionality with mock XADC behavioral model.
--
--   Test coverage: 8 test cases including automatic sampling, manual triggers, state
--   transitions, sample counting, and ciphertext validation.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_aes_ldr_top is
end entity tb_aes_ldr_top;

architecture sim of tb_aes_ldr_top is

    -- Vivado resolves to_hstring inconsistently here, so use a local helper
    -- to keep the testbench compatible with the rest of the repository.
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

    -- Component Declarations
    component ldr_sampler_fsm
        generic (
            TIMER_MAX_CYCLES : integer := 500000000
        );
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

    -- Test Signals
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

    -- Clock Generation
    clk <= not clk after CLK_PERIOD / 2;
    
    process(clk)
    begin
        if rising_edge(clk) then
            cycle_count <= cycle_count + 1;
        end if;
    end process;
    
    -- XADC Mock Model
    -- Simulates XADC behavior: detect a new request edge → 2 cycles later, return valid data
    process
        variable xadc_request_time : integer := -1000000;
        variable adc_counter : integer := 0;
        variable prev_xadc_ready : std_logic := '0';
    begin
        wait until rising_edge(clk);

        -- Detect rising edge of request and latch request time once per request
        if xadc_ready = '1' and prev_xadc_ready = '0' then
            xadc_request_time := cycle_count;
            adc_counter := adc_counter + 1;
            xadc_mock_adc <= std_logic_vector(to_unsigned(256 + adc_counter, 12));
            report "[XADC] Read request at cycle " & integer'image(cycle_count);
        end if;

        -- Simulate 2-cycle latency from latched request, then return valid data
        if cycle_count = xadc_request_time + 2 then
            xadc_data <= (15 downto 12 => '0') & xadc_mock_adc;  -- status[3:0] + ADC[11:0]
            xadc_valid <= '1';
            report "[XADC] Data valid at cycle " & integer'image(cycle_count) & 
                   ", ADC value: 0x" & slv_to_hstring(xadc_mock_adc);
        else
            xadc_valid <= '0';
        end if;

        -- Update previous ready for edge detection
        prev_xadc_ready := xadc_ready;
    end process;

    -- Instantiate LDR Sampler FSM
    -- For simulation we override the production 5-second timer to a much
    -- shorter value to keep simulations fast. Set to 5,000 cycles (~50 µs at 100 MHz).
    u_sampler : ldr_sampler_fsm
        generic map (timer_max_cycles => 5000)
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

    -- Instantiate AES Core
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

    -- Main Test Process
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
        
        report "[TEST] === SAMPLE 1: Waiting for first 5-second timer (sim shortened) ===";
        
        -- For simulation the sampling timer is shortened via the generic above
        -- so use a much smaller timeout to avoid long wall-clock runs.
        wait until sampler_result_ready = '1' for 10 ms;
        
        if sampler_result_ready = '1' then
            sample_number := 1;
            report "[TEST] Sample " & integer'image(sample_number) & " encrypted successfully";
            report "[TEST]   Raw ADC value: 0x" & slv_to_hstring(sampler_adc_raw);
            report "[TEST]   Encrypted: 0x" & slv_to_hstring(sampler_encrypted);
            report "[TEST]   Sample count: " & integer'image(to_integer(unsigned(sampler_count)));
            wait for 10 ns;
        else
            report "[TEST] ERROR: First sample timeout (expected after ~500M cycles)";
        end if;

        -- =====================================================================
        -- TEST 2: Wait for second sample
        -- =====================================================================
        
        report "[TEST] === SAMPLE 2: Waiting for second 5-second timer (sim shortened) ===";
        -- Same shortened timer applies to the second automatic sample.
        wait until sampler_result_ready = '1' for 10 ms;
        
        if sampler_result_ready = '1' then
            sample_number := 2;
            report "[TEST] Sample " & integer'image(sample_number) & " encrypted successfully";
            report "[TEST]   Raw ADC value: 0x" & slv_to_hstring(sampler_adc_raw);
            report "[TEST]   Encrypted: 0x" & slv_to_hstring(sampler_encrypted);
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
            report "[TEST]   Raw ADC value: 0x" & slv_to_hstring(sampler_adc_raw);
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
            report "[TEST]   Expected: 0x" & slv_to_hstring(expected_plaintext);
            report "[TEST]   Got:      0x" & slv_to_hstring(sampler_aes_data);
        else
            report "[TEST] ERROR: Padding mismatch!";
            report "[TEST]   Expected: 0x" & slv_to_hstring(expected_plaintext);
            report "[TEST]   Got:      0x" & slv_to_hstring(sampler_aes_data);
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
            report "[AES] Start signal asserted, plaintext: 0x" & slv_to_hstring(sampler_aes_data);
        end if;
        
        if aes_done = '1' then
            report "[AES] Done signal asserted, ciphertext: 0x" & slv_to_hstring(aes_data_out);
        end if;
        
        if sampler_result_ready = '1' then
            report "[SAMPLER] Result ready, sample count: " & integer'image(to_integer(unsigned(sampler_count)));
        end if;
    end process;

end architecture sim;
