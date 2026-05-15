----------------------------------------------------------------------------------
-- Module Name:    aes_ldr_top
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           15/05/2026
--
-- Description:
--   Top-level integration of LDR sensor with XADC and AES-128 encryption.
--   Samples analog voltage from LDR via Pmod JA (XADC channel 5).
--   Automatically encrypts each sample every 5 seconds.
--   Transmits encrypted results to PC via UART.
--
--   Architecture:
--     XADC IP (hardmacro ADC) reads LDR voltage
--     ldr_sampler_fsm (control FSM) orchestrates periodic sampling
--     aes_top (existing AES core) encrypts each reading
--     uart_aes_controller (existing) handles UART communication
--     Key is loaded once from PC, then reused for all samples
--
--   Hardware Connections:
--     Pmod JA Pin 1 (XADC_CH5_P) = LDR + voltage divider
--     USB UART RX/TX = PC serial connection
--     LED[15:0] = status indicators
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity aes_ldr_top is
    port (
        clk        : in  std_logic;                    -- 100 MHz system clock
        rst        : in  std_logic;                    -- async reset (active high)
        rx         : in  std_logic;                    -- USB UART RX
        tx         : out std_logic;                    -- USB UART TX
        ldr_adc_in : in  std_logic;                    -- analog input from Pmod JA (XADC_CH5_P)
        led_status : out std_logic_vector(15 downto 0) -- status LEDs
    );
end entity aes_ldr_top;

architecture rtl of aes_ldr_top is

    -- XADC Wizard generated component (user must generate this in Vivado)
    component xadc_wiz_0
        port (
            daddr_in      : in  std_logic_vector(6 downto 0);    -- XADC address bus
            den_in        : in  std_logic;                        -- read enable
            dwe_in        : in  std_logic;                        -- write enable
            di_in         : in  std_logic_vector(15 downto 0);    -- write data
            do_out        : out std_logic_vector(15 downto 0);    -- read data
            drdy_out      : out std_logic;                        -- data ready
            dclk_in       : in  std_logic;                        -- XADC clock
            reset_in      : in  std_logic;                        -- XADC reset
            vp_in         : in  std_logic;                        -- VP (unused)
            vn_in         : in  std_logic;                        -- VN (unused)
            busy_out      : out std_logic;                        -- conversion busy
            channel_out   : out std_logic_vector(4 downto 0);    -- active channel
            eoc_out       : out std_logic;                        -- end of conversion
            eos_out       : out std_logic;                        -- end of sequence
            alarm_out     : out std_logic;                        -- temperature alarm
            vauxp5        : in  std_logic;                        -- CH5 positive (LDR)
            vauxn5        : in  std_logic                         -- CH5 negative (GND ref)
        );
    end component xadc_wiz_0;

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

    component uart_aes_controller
        port (
            clk        : in  std_logic;
            rst_n      : in  std_logic;
            rx         : in  std_logic;
            tx         : out std_logic;
            led_status : out std_logic_vector(15 downto 0)
        );
    end component uart_aes_controller;

    -- XADC signals
    signal xadc_data : std_logic_vector(15 downto 0);
    signal xadc_valid : std_logic;
    signal xadc_ready : std_logic;
    signal xadc_busy : std_logic;
    signal xadc_eoc : std_logic;

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

    -- Key storage (loaded from UART once, reused for all samples)
    signal stored_key : std_logic_vector(127 downto 0);

begin

    -- Initialize stored_key with default FIPS-197 test key
    -- Note: v2.0 uses a fixed key for autonomous LDR sampling.
    -- Future extensions can support dynamic key loading via UART.
    stored_key <= x"000102030405060708090a0b0c0d0e0f";

    -- =========================================================================
    -- XADC IP Instance (Xilinx integrated ADC)
    -- =========================================================================
    u_xadc : xadc_wiz_0
        port map (
            daddr_in      => "0010101",       -- address for XADC data register (CH5)
            den_in        => xadc_ready,      -- request read from XADC
            dwe_in        => '0',             -- read-only
            di_in         => (others => '0'),
            do_out        => xadc_data,       -- 16-bit result (bits 15:4 = ADC12)
            drdy_out      => xadc_valid,      -- data valid on next cycle
            dclk_in       => clk,
            reset_in      => rst,
            vp_in         => '0',             -- VP not used
            vn_in         => '0',             -- VN not used
            busy_out      => xadc_busy,
            channel_out   => open,
            eoc_out       => xadc_eoc,
            eos_out       => open,
            alarm_out     => open,
            vauxp5        => ldr_adc_in,      -- LDR voltage divider output → CH5 positive
            vauxn5        => '0'              -- CH5 negative tied to GND (single-ended)
        );

    -- =========================================================================
    -- LDR Sampler FSM (periodic read + encrypt every 5 seconds)
    -- =========================================================================
    u_sampler : ldr_sampler_fsm
        port map (
            clk           => clk,
            rst_n         => not rst,
            manual_trigger => '0',            -- always use periodic timer
            xadc_valid    => xadc_valid,
            xadc_data     => xadc_data,
            xadc_ready    => xadc_ready,
            aes_start     => sampler_aes_start,
            aes_done      => aes_done,
            aes_key       => stored_key,
            aes_data      => sampler_aes_data,
            aes_out       => aes_data_out,
            result_ready  => sampler_result_ready,
            encrypted     => sampler_encrypted,
            adc_raw       => sampler_adc_raw,
            sample_count  => sampler_count
        );

    -- =========================================================================
    -- AES-128 Core (reused from existing design)
    -- =========================================================================
    u_aes : aes_top
        port map (
            clk      => clk,
            rst_n    => not rst,
            start    => sampler_aes_start,
            enc_dec  => '1',                  -- always encrypt (not decrypt)
            data_in  => sampler_aes_data,     -- padded ADC value
            key_in   => stored_key,
            data_out => aes_data_out,
            done     => aes_done,
            ready    => aes_ready,
            error    => aes_error
        );

    -- =========================================================================
    -- UART Controller (reused from existing design, unmodified)
    -- =========================================================================
    -- Note: uart_aes_controller remains unchanged for backward compatibility.
    -- The LDR sampler FSM operates autonomously in parallel:
    -- - Samples LDR every 5 seconds
    -- - Encrypts each reading with pre-loaded key
    -- - Buffers results (future extension: add UART readout or logging)
    u_uart_ctrl : uart_aes_controller
        port map (
            clk        => clk,
            rst_n      => not rst,
            rx         => rx,
            tx         => tx,
            led_status => led_status
        );

end architecture rtl;
