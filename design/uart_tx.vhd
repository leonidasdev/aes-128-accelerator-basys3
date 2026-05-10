----------------------------------------------------------------------------------
-- Module Name:    uart_tx
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           29/04/2026
--
-- Description:
--   UART transmitter that serializes one byte at a time with start and stop
--   bits and provides a ready/busy handshake.
--
--   Implementation: Clocked FSM transmitter with one-byte staging register.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    generic(
        BAUD_CLK : integer := 868  -- 100 MHz / 115200 baud
    );

    port(
        rst_n      : in  std_logic;
        clk        : in  std_logic;
        tx_start   : in  std_logic;
        tx_data_in : in  std_logic_vector(7 downto 0);
        tx         : out std_logic;
        tx_ready   : out std_logic  -- '1' = idle/ready; '0' = transmitting
    );
end uart_tx;

architecture rtl of uart_tx is
    type state_type is (IDLE, START, DATA, STOP_BIT, CLEANUP);
    signal tx_state : state_type := IDLE;

    signal clk_cnt    : integer range 0 to BAUD_CLK-1 := 0;
    signal bit_index  : integer range 0 to 7 := 0;
    signal tx_register: std_logic_vector(7 downto 0) := (others => '0');

begin
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            tx_state <= IDLE;
            clk_cnt <= 0;
            bit_index <= 0;
            tx_register <= (others => '0');
            tx <= '1';
            tx_ready <= '1';
        elsif rising_edge(clk) then
            case tx_state is
                    when IDLE =>
                        -- Idle state: line is high, transmitter ready
                        tx <= '1';
                        tx_ready <= '1';
                        clk_cnt <= 0;
                        bit_index <= 0;
                        if tx_start = '1' then
                            tx_register <= tx_data_in;
                            tx_ready <= '0';
                            tx_state <= START;
                        end if;
                when START =>
                    -- Transmit start bit (low)
                    tx <= '0';
                    if clk_cnt = BAUD_CLK-1 then
                        clk_cnt <= 0;
                        tx_state <= DATA;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;
                     
                when DATA =>
                    tx <= tx_register(bit_index);
                    if clk_cnt = BAUD_CLK-1 then
                        clk_cnt <= 0;
                        if bit_index < 7 then
                            bit_index <= bit_index + 1;
                        else
                            tx_state <= STOP_BIT;
                        end if;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;

                when STOP_BIT =>
                    -- Transmit stop bit (high)
                    tx <= '1';
                    if clk_cnt = BAUD_CLK - 1 then
                        clk_cnt <= 0;
                        tx_state <= CLEANUP;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;
                when CLEANUP =>
                    -- Mark ready and return to idle
                    tx_ready <= '1';
                    tx_state <= IDLE;
            end case;
        end if;
    end process;

end architecture rtl;
