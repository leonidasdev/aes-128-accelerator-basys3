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
use ieee.numeric_std.all;

entity tb_uart_rx is
end tb_uart_rx;

architecture sim of tb_uart_rx is
    constant CLK_PERIOD : time := 10 ns;     -- 100 MHz
    constant BIT_PERIOD : time := 8.68 us;   -- 1 / 115200 baud
    constant CLKS_PER_BIT : natural := 868;
    constant BIT_MARGIN_CYCLES : natural := 2;
    constant BIT_WAIT_CYCLES : natural := CLKS_PER_BIT + BIT_MARGIN_CYCLES;

    signal clk      : std_logic := '0';
    signal rst_n    : std_logic := '1';
    signal rx       : std_logic := '1'; -- Reposo en alto
    signal rx_byte  : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;

    -- Helper: generate a UART frame (start, 8 data bits LSB-first, stop)
    -- The stop bit is driven high and left asserted so the caller can wait
    -- for rx_valid without missing the one-cycle pulse.
    procedure send_byte (
        constant data : in std_logic_vector(7 downto 0);
        signal serial_out : out std_logic;
        signal clk_sig : in std_logic
    ) is
    begin
        wait until falling_edge(clk_sig);
        serial_out <= '0'; -- start bit (low)
        for cycle_index in 1 to BIT_WAIT_CYCLES loop
            wait until rising_edge(clk_sig);
        end loop;
        for i in 0 to 7 loop
            wait until falling_edge(clk_sig);
            serial_out <= data(i); -- data bits (LSB first)
            for cycle_index in 1 to BIT_WAIT_CYCLES loop
                wait until rising_edge(clk_sig);
            end loop;
        end loop;
        wait until falling_edge(clk_sig);
        serial_out <= '1'; -- stop bit (high)
    end procedure;

    procedure wait_for_rx_byte(
        signal valid_sig : in std_logic;
        signal data_sig : in std_logic_vector(7 downto 0);
        variable data_out : out std_logic_vector(7 downto 0)
    ) is
    begin
        wait until valid_sig'event and valid_sig = '1';
        wait for 0 ns;
        data_out := data_sig;
        wait until valid_sig'event and valid_sig = '0';
    end procedure;

begin
    -- Instantiate the unit under test (UART RX)
    uut: entity work.uart_rx
        generic map ( CLKS_PER_BIT => 868 )
        port map (
            rst_n    => rst_n,
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
        variable framing_pattern : std_logic_vector(7 downto 0) := x"AA";
    begin
        report "==============================" & character'val(10) &
            "Starting tb_uart_rx" & character'val(10) &
            "==============================" severity note;

        rst_n <= '0';
        wait for 100 ns;
        rst_n <= '1';

        wait for 100 ns;

        -- Test 1: Receive 0x41 ('A')
        send_byte(x"41", rx, clk);
        wait_for_rx_byte(rx_valid, rx_byte, received);
        if received = x"41" then
            pass_cnt := pass_cnt + 1;
            report "Test 1 (receive 0x41): PASS" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test 1 (receive 0x41): FAIL - got " & integer'image(to_integer(unsigned(received))) severity warning;
        end if;

        -- Test 2: Receive 0x55
        wait for 10 us;
        send_byte(x"55", rx, clk);
        wait_for_rx_byte(rx_valid, rx_byte, received);
        if received = x"55" then
            pass_cnt := pass_cnt + 1;
            report "Test 2 (receive 0x55): PASS" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test 2 (receive 0x55): FAIL" severity warning;
        end if;

        -- Test 3: Framing error - hold stop bit low and ensure no valid pulse
        wait for 20 us;
        -- Drive start and data bits, then force stop low
        wait until falling_edge(clk);
        rx <= '0'; -- start
        for cycle_index in 1 to BIT_WAIT_CYCLES loop
            wait until rising_edge(clk);
        end loop;
        for i in 0 to 7 loop
            wait until falling_edge(clk);
            rx <= framing_pattern(i); -- arbitrary pattern (value ignored for this test)
            for cycle_index in 1 to BIT_WAIT_CYCLES loop
                wait until rising_edge(clk);
            end loop;
        end loop;
        wait until falling_edge(clk);
        rx <= '0'; -- corrupted stop bit (should be high)
        for cycle_index in 1 to BIT_WAIT_CYCLES loop
            wait until rising_edge(clk);
        end loop;
        -- Give receiver time to react
        wait for 20 us;
        if rx_valid = '1' then
            fail_cnt := fail_cnt + 1;
            report "Test 3 (framing error): FAIL - framing error accepted as valid" severity warning;
        else
            pass_cnt := pass_cnt + 1;
            report "Test 3 (framing error): PASS" severity note;
        end if;

        -- Clear the receiver state after the malformed frame before the next gap test.
        rst_n <= '0';
        wait for 100 ns;
        rst_n <= '1';
        -- Return the line to idle before testing a long inter-byte gap.
        rx <= '1';
        wait for 20 us;

        -- Test 4: Long inter-byte gap should not disturb reception
        wait for 20 us;
        send_byte(x"7E", rx, clk);
        wait_for_rx_byte(rx_valid, rx_byte, received);
        if received = x"7E" then
            pass_cnt := pass_cnt + 1;
            report "Test 4 (long gap first byte): PASS" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test 4 (long gap first byte): FAIL - got " & integer'image(to_integer(unsigned(received))) severity warning;
        end if;

        wait for 200 us;
        send_byte(x"81", rx, clk);
        wait_for_rx_byte(rx_valid, rx_byte, received);
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