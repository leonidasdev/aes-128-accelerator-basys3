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
    constant BIT_PERIOD : time := 8.68 us; -- 115200 baud
    use ieee.numeric_std.all;
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
        variable pass_cnt : integer := 0;
        variable fail_cnt : integer := 0;
        variable test_num : integer := 0;
        variable received_byte : std_logic_vector(7 downto 0);
        -- Helper: sample the serial `tx` line and reconstruct a byte
        procedure receive_serial_byte(
            signal serial_in : in std_logic;
            variable data_byte : out std_logic_vector(7 downto 0)
        ) is
        begin
            wait until serial_in'event and serial_in = '0'; -- start bit
            wait for BIT_PERIOD / 2;
            for i in 0 to 7 loop
                wait for BIT_PERIOD;
                data_byte(i) := serial_in;
            end loop;
            wait for BIT_PERIOD; -- stop bit
        end procedure;
    begin
        report "==============================" & character'val(10) &
            "Starting tb_uart_tx" & character'val(10) &
            "==============================" severity note;

        wait for 100 ns;

        -- Test 1: transmit 0x3F and observe tx_ready return and waveform
        test_num := test_num + 1;
        if tx_ready = '1' then
            tx_data_in <= x"3F";
            tx_start <= '1';
            wait until rising_edge(clk);
            tx_start <= '0';
        end if;
        -- While the transmitter runs, capture serial waveform and verify
        receive_serial_byte(tx, received_byte);
        if received_byte = x"3F" then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL" & character'val(10) &
                   "  Expected: 0x3F" & character'val(10) &
                   "  Got:      " & integer'image(to_integer(unsigned(received_byte))) severity warning;
        end if;

        -- Test 2: back-to-back transmit 0xA5
        test_num := test_num + 1;
        wait for 50 us;
        tx_data_in <= x"A5";
        tx_start <= '1';
        wait until rising_edge(clk);
        tx_start <= '0';
        wait until tx_ready = '1';
        -- Capture waveform for second byte
        receive_serial_byte(tx, received_byte);
        if received_byte = x"A5" then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL" & character'val(10) &
                   "  Expected: 0xA5" & character'val(10) &
                   "  Got:      " & integer'image(to_integer(unsigned(received_byte))) severity warning;
        end if;

        -- Test 3: attempt assert of idle return
        test_num := test_num + 1;
        wait for 100 us;
        if tx_ready = '1' then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL - tx_ready not idle" severity warning;
        end if;

        report "==============================" & character'val(10) &
               "FINAL REPORT" & character'val(10) &
               "PASS: " & integer'image(pass_cnt) & character'val(10) &
               "FAIL: " & integer'image(fail_cnt) & character'val(10) &
               "==============================" severity note;

        wait;
    end process;
end architecture sim;


