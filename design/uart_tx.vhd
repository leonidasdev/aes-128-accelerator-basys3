----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05.05.2026 18:04:06
-- Design Name: 
-- Module Name: uart_tx - Behavioral
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    generic(
        BAUD_CLK: integer:= 868 --100MHz / 115200 baulios
    );
    
    port(
        clk: in std_logic;
        tx_start: in std_logic; 
        tx_data_in: in std_logic_vector(7 downto 0);
        tx: out std_logic; 
        tx_ready: out std_logic --'1' libre ; 0 transmite
    );
end UART_tx;

architecture rtl of UART_tx is
    type state_type is (IDLE, START, DATA, STOP_BIT, CLEANUP);
    signal tx_state : state_type := IDLE;

    signal clk_cnt: integer range 0 to BAUD_CLK-1 :=0;
    signal bit_index : integer range 0 to 7 := 0; 
    signal tx_register: std_logic_vector(7 downto 0) := (others => '0');

    begin 
        process(clk)
        begin 
            if rising_edge(clk) then 
                case tx_state is 
                    when IDLE =>
                        tx <= '1';
                        tx_ready<='1';
                        clk_cnt<= 0; 
                        bit_index <= 0; 
                        if tx_start = '1' then
                            tx_register<=tx_data_in;
                            tx_ready<= '0'; 
                            tx_state <= START;
                        end if;
                when START =>
                    tx<= '0'; 
                    if clk_cnt = BAUD_CLK-1 then 
                            clk_cnt <= 0; 
                            tx_state <= DATA; 
                    else 
                        clk_cnt <= clk_cnt + 1;
                    end if; 
                     
                when DATA => 
                    tx<= tx_register(bit_index);
                    if clk_cnt = BAUD_CLK-1 then 
                        clk_cnt <= 0; 
                        if bit_index < 7 then 
                            bit_index <= bit_index+1;
                        else 
                            tx_state<= STOP_BIT;
                        end if;
                    else 
                        clk_cnt <= clk_cnt+1;
                    end if; 
                    
                when STOP_BIT => 
                    tx<= '1'; --Bit stop
                    if clk_cnt = BAUD_CLK - 1 then
                        clk_cnt<=0; 
                        tx_state<= CLEANUP;
                    else 
                        clk_cnt <= clk_cnt +1;
                    end if;
                when CLEANUP => 
                        tx_ready <= '1';
                        tx_state<= IDLE;
                end case;
             end if;
        end process; 
end rtl; 