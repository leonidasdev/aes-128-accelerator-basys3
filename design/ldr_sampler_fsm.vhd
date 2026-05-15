----------------------------------------------------------------------------------
-- Module Name:    ldr_sampler_fsm
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           15/05/2026
--
-- Description:
--   Periodic LDR sampling controller using integrated XADC.
--   Samples analog voltage from LDR+voltage-divider every 5 seconds.
--   Encrypts each reading with AES-128 and buffers result for UART transmission.
--
--   Timing:
--     - XADC read latency: ~26 cycles @ 100 MHz = 0.26 µs
--     - AES-128 latency: 15 cycles = 0.15 µs
--     - Sampling period: 5 seconds (configurable)
--
--   State Machine:
--     IDLE → TIMER_RUNNING → READ_ADC → START_AES → WAIT_AES → BUFFER_RESULT → (back to TIMER_RUNNING)
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ldr_sampler_fsm is
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;
        
        -- External trigger (optional: allow manual sampling from UART)
        manual_trigger : in  std_logic;
        
        -- XADC AXI Lite interface (read-only)
        xadc_valid    : in  std_logic;              -- data ready from XADC
        xadc_data     : in  std_logic_vector(15 downto 0);  -- 16-bit (upper 12 bits = ADC)
        xadc_ready    : out std_logic;              -- request XADC read
        
        -- AES core interface
        aes_start     : out std_logic;
        aes_done      : in  std_logic;
        aes_key       : in  std_logic_vector(127 downto 0);  -- key from uart_aes_controller
        aes_data      : out std_logic_vector(127 downto 0);  -- padded ADC value
        aes_out       : in  std_logic_vector(127 downto 0);  -- encrypted result
        
        -- Status outputs
        result_ready  : out std_logic;              -- '1' when new encrypted sample available
        encrypted     : out std_logic_vector(127 downto 0);  -- buffered encrypted result
        adc_raw       : out std_logic_vector(11 downto 0);   -- raw 12-bit ADC value
        sample_count  : out std_logic_vector(31 downto 0)    -- total samples captured
    );
end entity ldr_sampler_fsm;

architecture rtl of ldr_sampler_fsm is

    type t_state is (ST_IDLE, ST_TIMER_RUNNING, ST_READ_ADC, ST_START_AES, ST_WAIT_AES, ST_BUFFER_RESULT);

    signal state, next_state : t_state;
    signal adc_value : std_logic_vector(11 downto 0);
    signal result_buffer : std_logic_vector(127 downto 0);
    signal sample_counter : unsigned(31 downto 0) := (others => '0');
    
    -- Timer for 5-second sampling period @ 100 MHz
    -- 5 seconds = 500,000,000 cycles
    signal timer : unsigned(31 downto 0) := (others => '0');
    constant TIMER_MAX : unsigned(31 downto 0) := to_unsigned(500000000, 32);  -- 5 seconds @ 100 MHz

begin

    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state <= ST_IDLE;
            timer <= (others => '0');
            sample_counter <= (others => '0');
            adc_value <= (others => '0');
            result_buffer <= (others => '0');
            xadc_ready <= '0';
            aes_start <= '0';
            result_ready <= '0';
            
        elsif rising_edge(clk) then
            -- Default outputs (hold unless explicitly set)
            xadc_ready <= '0';
            aes_start <= '0';
            result_ready <= '0';
            
            case state is
                
                -- Initial state: wait for first trigger
                when ST_IDLE =>
                    timer <= (others => '0');
                    if manual_trigger = '1' then
                        state <= ST_READ_ADC;
                    else
                        state <= ST_TIMER_RUNNING;
                    end if;
                
                -- Timer running: count down to sampling period
                when ST_TIMER_RUNNING =>
                    if timer = TIMER_MAX then
                        timer <= (others => '0');
                        state <= ST_READ_ADC;
                    else
                        timer <= timer + 1;
                    end if;
                    
                    -- Allow manual override interrupt
                    if manual_trigger = '1' then
                        timer <= (others => '0');
                        state <= ST_READ_ADC;
                    end if;
                
                -- Request XADC read of analog voltage
                when ST_READ_ADC =>
                    xadc_ready <= '1';  -- request read
                    if xadc_valid = '1' then
                        -- XADC returns 16-bit value: [status(3:0) | ADC(11:0)]
                        adc_value <= xadc_data(11 downto 0);
                        state <= ST_START_AES;
                    end if;
                
                -- Start AES encryption with padded ADC value
                when ST_START_AES =>
                    -- Pad 12-bit ADC value to 128-bit block
                    -- Format: [000...000 | 12-bit ADC value]
                    aes_data <= (127 downto 12 => '0') & adc_value;
                    aes_start <= '1';
                    state <= ST_WAIT_AES;
                
                -- Wait for AES to complete
                when ST_WAIT_AES =>
                    if aes_done = '1' then
                        result_buffer <= aes_out;
                        sample_counter <= sample_counter + 1;
                        state <= ST_BUFFER_RESULT;
                    end if;
                
                -- Signal that result is ready, then loop
                when ST_BUFFER_RESULT =>
                    result_ready <= '1';
                    state <= ST_TIMER_RUNNING;
                    timer <= (others => '0');
                
            end case;
        end if;
    end process;

    -- Continuous outputs
    encrypted <= result_buffer;
    adc_raw <= adc_value;
    sample_count <= std_logic_vector(sample_counter);

end architecture rtl;
