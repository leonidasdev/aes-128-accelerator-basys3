----------------------------------------------------------------------------------
-- Module Name:    aes_hil_top
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           11/05/2026
--
-- Description:
--   Board wrapper for Basys3 that exposes the UART HIL controller.
--   This top instantiates the `uart_aes_controller` which implements the
--   ASCII HIL protocol (K:/D:/M:/S:) and drives the `aes_top` core.
--
--   The `led_status` port is forwarded directly to the physical LEDs so
--   the board shows ready/busy/error/mode state for visual feedback.
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity aes_hil_top is
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        rx         : in  std_logic;  -- USB-UART RX (host -> FPGA)
        tx         : out std_logic;  -- USB-UART TX (FPGA -> host)
        led_status : out std_logic_vector(15 downto 0)  -- Status LEDs (ready/done/error/mode)
    );
end entity aes_hil_top;

architecture rtl of aes_hil_top is

    component uart_aes_controller
        port (
            clk        : in  std_logic;
            rst_n      : in  std_logic;
            rx         : in  std_logic;
            tx         : out std_logic;
            led_status : out std_logic_vector(15 downto 0)
        );
    end component;

begin

    -- Instantiate UART-to-AES controller and forward LED status to board LEDs
    u_uart_ctrl : uart_aes_controller
        port map (
            clk        => clk,
            rst_n      => not rst,
            rx         => rx,
            tx         => tx,
            led_status => led_status
        );

end architecture rtl;
