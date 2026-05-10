----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05.05.2026 18:04:47
-- Design Name: 
-- Module Name: tb_uart_tx - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

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
    -- Instancia del módulo a probar
    uut: uart_tx
        generic map ( BAUD_CLK => 868 )
        port map (
            clk      => clk,
            tx_start => tx_start,
            tx_data_in  => tx_data_in,
            tx       => tx,
            tx_ready => tx_ready
        );

    -- Generador de reloj
    clk <= not clk after CLK_PERIOD / 2;

    process
    begin
        wait for 100 ns;

        -- Enviar primer byte: 0x3F (00111111)
        if tx_ready = '1' then
            tx_data_in  <= x"3F";
            tx_start <= '1';
            wait until rising_edge(clk);
            tx_start <= '0';
        end if;
        
        -- Esperar a que termine de transmitir
        wait until tx_ready = '1';
        wait for 50 us;

        -- Enviar segundo byte: 0xA5 (10100101)
        tx_data_in  <= x"A5";
        tx_start <= '1';
        wait until rising_edge(clk);
        tx_start <= '0';

        wait for 1 ms;
        assert false report "Simulación terminada" severity failure;
    end process;
end sim;


