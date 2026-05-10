----------------------------------------------------------------------------------
-- Module Name:    uart_rx
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           29/04/2026
--
-- Description:
--   UART receiver that samples an asynchronous serial input and outputs one
--   received byte with a one-cycle valid pulse.
--
--   Implementation: Oversampled FSM receiver with start-bit validation and
--   synchronized input sampling.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity uart_rx is
    generic (
        CLKS_PER_BIT : integer := 868  -- (100 MHz / 115200 baud)
    );
    port (
        clk       : in  std_logic;
        rx        : in  std_logic;
        rx_byte   : out std_logic_vector(7 downto 0);
        rx_valid  : out std_logic
    );
end uart_rx;

architecture rtl of uart_rx is

    -- Receiver state and timing signals
    type state_type is (IDLE, START_BIT, DATA_BITS, STOP_BIT, CLEANUP);
    signal state : state_type := IDLE;

    signal clk_cnt : integer range 0 to CLKS_PER_BIT-1 := 0;
    signal bit_idx : integer range 0 to 7 := 0;
    signal rx_data : std_logic_vector(7 downto 0) := (others => '0');

    -- Synchronizers to reduce metastability on async RX input
    signal rx_meta : std_logic := '1';
    signal rx_reg  : std_logic := '1';

begin

    -- Synchronize the async RX input to the local clock domain
    process(clk)
    begin
        if rising_edge(clk) then
            rx_meta <= rx;
            rx_reg  <= rx_meta;
        end if;
    end process;

    -- Main receiver FSM: detect start bit, sample data bits LSB-first,
    -- output `rx_byte` and pulse `rx_valid` for one clock cycle when a byte is ready.
    process(clk)
    begin
        if rising_edge(clk) then
            rx_valid <= '0'; -- default: no valid byte

            case state is
                when IDLE =>
                    clk_cnt <= 0;
                    bit_idx <= 0;
                    if rx_reg = '0' then       -- detect start bit (falling edge)
                        state <= START_BIT;
                    end if;

                when START_BIT =>
                    if clk_cnt = (CLKS_PER_BIT-1)/2 then
                        if rx_reg = '0' then   -- sample mid-bit to avoid glitches
                            clk_cnt <= 0;
                            state <= DATA_BITS;
                        else
                            state <= IDLE;     -- false start (noise)
                        end if;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;

                when DATA_BITS =>
                    if clk_cnt = CLKS_PER_BIT-1 then
                        clk_cnt <= 0;
                        rx_data(bit_idx) <= rx_reg;

                        if bit_idx < 7 then
                            bit_idx <= bit_idx + 1;
                        else
                            bit_idx <= 0;
                            state <= STOP_BIT;
                        end if;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;

                when STOP_BIT =>
                    -- wait through stop bit then present data
                    if clk_cnt = CLKS_PER_BIT-1 then
                        rx_byte <= rx_data;
                        rx_valid <= '1';
                        clk_cnt <= 0;
                        state <= CLEANUP;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;

                when CLEANUP =>
                    state <= IDLE;
                    rx_valid <= '0';

            end case;
        end if;
    end process;

end rtl;