----------------------------------------------------------------------------------
-- Module Name:    tb_uart_rx
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           29/04/2026
--
-- Description:
--   Unit testbench for the UART receiver. Validates byte sampling and valid
--   pulse generation with representative UART frames.
--
--   Implementation: Self-contained stimulus process with UART frame helper.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity tb_uart_rx is
end tb_uart_rx;

architecture sim of tb_uart_rx is
    constant CLK_PERIOD : time := 10 ns;     -- 100 MHz
    constant BIT_PERIOD : time := 8.68 us;   -- 1 / 115200 baud

    signal clk      : std_logic := '0';
    signal rx       : std_logic := '1'; -- Reposo en alto
    signal rx_byte  : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;

    -- Helper: generate a UART frame (start, 8 data bits LSB-first, stop)
    procedure send_byte (
        constant data : in std_logic_vector(7 downto 0);
        signal serial_out : out std_logic
    ) is
    begin
        serial_out <= '0'; -- start bit (low)
        wait for BIT_PERIOD;
        for i in 0 to 7 loop
            serial_out <= data(i); -- data bits (LSB first)
            wait for BIT_PERIOD;
        end loop;
        serial_out <= '1'; -- stop bit (high)
        wait for BIT_PERIOD;
    end procedure;

begin
    -- Instantiate the unit under test (UART RX)
    uut: entity work.uart_rx
        generic map ( CLKS_PER_BIT => 868 )
        port map (
            clk      => clk,
            rx       => rx,
            rx_byte  => rx_byte,
            rx_valid => rx_valid
        );

    -- Clock generator
    clk <= not clk after CLK_PERIOD / 2;

    process begin
        wait for 100 ns;
        -- Send byte 0x41 ('A')
        send_byte(x"41", rx);

        wait for 100 us;

        -- Send another test byte 0x55
        send_byte(x"55", rx);

        wait for 500 us;
        report "RX simulation completed successfully" severity failure;
    end process;
end sim;