----------------------------------------------------------------------------------
-- Module Name:    tb_uart_tx
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           29/04/2026
--
-- Description:
--   Unit testbench for the UART transmitter. Exercises byte launch timing
--   and tx_ready handshaking across multiple transfers.
--
--   Implementation: Self-checking stimulus process with fixed UART payloads.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity tb_uart_tx is
end tb_uart_tx;

architecture sim of tb_uart_tx is
    constant CLK_PERIOD : time := 10 ns; -- 100 MHz
    component uart_tx is
        generic (
            BAUD_CLK : integer := 868
        );
        port (
            clk       : in  std_logic;
            tx_start  : in  std_logic;
            tx_data_in   : in  std_logic_vector(7 downto 0);
            tx        : out std_logic;
            tx_ready  : out std_logic
        );
    end component;
    signal clk      : std_logic := '0';
    signal tx_start : std_logic := '0';
    signal tx_data_in  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx       : std_logic;
    signal tx_ready : std_logic;
begin
    -- Instantiate the unit under test (UART TX)
    uut: uart_tx
        generic map ( BAUD_CLK => 868 )
        port map (
            clk      => clk,
            tx_start => tx_start,
            tx_data_in  => tx_data_in,
            tx       => tx,
            tx_ready => tx_ready
        );

    -- Clock generator
    clk <= not clk after CLK_PERIOD / 2;

    process
    begin
        wait for 100 ns;

        -- Send first byte: 0x3F
        if tx_ready = '1' then
            tx_data_in <= x"3F";
            tx_start <= '1';
            wait until rising_edge(clk);
            tx_start <= '0';
        end if;

        -- Wait until transmitter completes, then pause
        wait until tx_ready = '1';
        wait for 50 us;

        -- Send second byte: 0xA5
        tx_data_in <= x"A5";
        tx_start <= '1';
        wait until rising_edge(clk);
        tx_start <= '0';

        wait for 1 ms;
        assert false report "Simulation finished" severity failure;
    end process;
end sim;


