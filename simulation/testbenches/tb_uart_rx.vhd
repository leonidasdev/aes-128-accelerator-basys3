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

    process
        variable pass_cnt : integer := 0;
        variable fail_cnt : integer := 0;
        variable received : std_logic_vector(7 downto 0);
    begin
        report "==============================" & character'val(10) &
            "Starting tb_uart_rx" & character'val(10) &
            "==============================" severity note;

        wait for 100 ns;

        -- Test 1: Receive 0x41 ('A')
        send_byte(x"41", rx);
        wait until rx_valid = '1';
        received := rx_byte;
        if received = x"41" then
            pass_cnt := pass_cnt + 1;
            report "Test 1 (receive 0x41): PASS" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test 1 (receive 0x41): FAIL - got " & integer'image(to_integer(unsigned(received))) severity warning;
        end if;

        -- Test 2: Receive 0x55
        wait for 10 us;
        send_byte(x"55", rx);
        wait until rx_valid = '1';
        received := rx_byte;
        if received = x"55" then
            pass_cnt := pass_cnt + 1;
            report "Test 2 (receive 0x55): PASS" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test 2 (receive 0x55): FAIL" severity warning;
        end if;

        -- Test 3: Framing error - hold stop bit low and ensure no valid pulse
        wait for 10 us;
        -- Drive start and data bits, then force stop low
        rx <= '0'; -- start
        wait for BIT_PERIOD;
        for i in 0 to 7 loop
            rx <= x"AA"(i); -- arbitrary pattern (value ignored for this test)
            wait for BIT_PERIOD;
        end loop;
        rx <= '0'; -- corrupted stop bit (should be high)
        wait for BIT_PERIOD;
        -- Give receiver time to react
        wait for 20 us;
        if rx_valid = '1' then
            fail_cnt := fail_cnt + 1;
            report "Test 3 (framing error): FAIL - framing error accepted as valid" severity warning;
        else
            pass_cnt := pass_cnt + 1;
            report "Test 3 (framing error): PASS" severity note;
        end if;
        -- Test 4: Long inter-byte gap should not disturb reception
        wait for 20 us;
        send_byte(x"7E", rx);
        wait until rx_valid = '1';
        received := rx_byte;
        if received = x"7E" then
            pass_cnt := pass_cnt + 1;
            report "Test 4 (long gap first byte): PASS" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test 4 (long gap first byte): FAIL" severity warning;
        end if;

        wait for 200 us;
        send_byte(x"81", rx);
        wait until rx_valid = '1';
        received := rx_byte;
        if received = x"81" then
            pass_cnt := pass_cnt + 1;
            report "Test 5 (long gap second byte): PASS" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test 5 (long gap second byte): FAIL" severity warning;
        end if;

        report "==============================" & character'val(10) &
               "FINAL REPORT" & character'val(10) &
               "PASS: " & integer'image(pass_cnt) & character'val(10) &
               "FAIL: " & integer'image(fail_cnt) & character'val(10) &
               "==============================" severity note;

        wait;
    end process;
end architecture sim;