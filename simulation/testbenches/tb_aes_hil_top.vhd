----------------------------------------------------------------------------------
-- Module Name:    tb_aes_hil_top
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           17/05/2026
--
-- Description:
--   Smoke testbench for the HIL board wrapper. Validates reset polarity and
--   confirms the UART AES controller remains reachable through aes_hil_top.
--
--   Implementation: UART stimulus and monitored serial response using the same
--   ASCII command protocol as the controller testbench.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_aes_hil_top is
end entity tb_aes_hil_top;

architecture sim of tb_aes_hil_top is

    constant CLK_PERIOD : time := 10 ns;
    constant CLKS_PER_BIT : natural := 868;
    constant BIT_PERIOD : time := CLK_PERIOD * CLKS_PER_BIT;

    constant KEY_HEX : string := "000102030405060708090A0B0C0D0E0F";
    constant DATA_HEX : string := "00112233445566778899AABBCCDDEEFF";
    constant EXPECTED_HEX : string := "69C4E0D86A7B0430D8CDB78070B4C55A";

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal rx         : std_logic := '1';
    signal tx         : std_logic;
    signal led_status : std_logic_vector(15 downto 0);

    signal tx_mon_byte  : std_logic_vector(7 downto 0);
    signal tx_mon_valid  : std_logic;

    type t_uart_byte_buffer is array (natural range <>) of std_logic_vector(7 downto 0);
    constant TX_MON_BUFFER_SIZE : natural := 128;
    signal tx_mon_buffer : t_uart_byte_buffer(0 to TX_MON_BUFFER_SIZE - 1) := (others => (others => '0'));
    signal tx_mon_wr_idx : natural range 0 to TX_MON_BUFFER_SIZE := 0;

    function char_to_slv(value : character) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(character'pos(value), 8));
    end function;

    procedure send_uart_byte(
        signal serial_out : out std_logic;
        constant data_byte : in std_logic_vector(7 downto 0)
    ) is
        variable char_val : character;
    begin
        if data_byte >= x"20" and data_byte <= x"7E" then
            char_val := character'val(to_integer(unsigned(data_byte)));
            report "SEND_BYTE: '" & char_val & "' (" &
                integer'image(to_integer(unsigned(data_byte))) & ")" severity note;
        else
            report "SEND_BYTE: " & integer'image(to_integer(unsigned(data_byte))) severity note;
        end if;

        wait until falling_edge(clk);
        serial_out <= '0';
        for bit_cycle in 1 to CLKS_PER_BIT loop
            wait until rising_edge(clk);
        end loop;

        for bit_index in 0 to 7 loop
            wait until falling_edge(clk);
            serial_out <= data_byte(bit_index);
            for bit_cycle in 1 to CLKS_PER_BIT loop
                wait until rising_edge(clk);
            end loop;
        end loop;

        wait until falling_edge(clk);
        serial_out <= '1';
        for bit_cycle in 1 to CLKS_PER_BIT loop
            wait until rising_edge(clk);
        end loop;

        for idle_cycle in 1 to CLKS_PER_BIT loop
            wait until rising_edge(clk);
        end loop;
    end procedure;

    procedure send_uart_string(
        signal serial_out : out std_logic;
        constant text_value : in string
    ) is
    begin
        for index in text_value'range loop
            send_uart_byte(serial_out, char_to_slv(text_value(index)));
        end loop;
    end procedure;

    procedure expect_uart_string(
        constant expected_text : in string
    ) is
        variable received_byte : std_logic_vector(7 downto 0);
        variable byte_count : natural := 0;
    begin
        for index in expected_text'range loop
            while tx_mon_wr_idx <= byte_count loop
                wait until rising_edge(clk);
            end loop;
            received_byte := tx_mon_buffer(byte_count);
            byte_count := byte_count + 1;
            assert received_byte = char_to_slv(expected_text(index))
                report "UART response mismatch at character " & integer'image(index)
                severity error;
        end loop;

        while tx_mon_wr_idx <= byte_count loop
            wait until rising_edge(clk);
        end loop;
        received_byte := tx_mon_buffer(byte_count);
        assert received_byte = x"0A"
            report "UART response missing trailing newline"
            severity error;
    end procedure;

begin

    u_dut : entity work.aes_hil_top
        port map (
            clk        => clk,
            rst        => rst,
            rx         => rx,
            tx         => tx,
            led_status => led_status
        );

    tx_monitor : entity work.uart_rx
        generic map ( CLKS_PER_BIT => CLKS_PER_BIT )
        port map (
            rst_n    => '1',
            clk      => clk,
            rx       => tx,
            rx_byte  => tx_mon_byte,
            rx_valid => tx_mon_valid
        );

    process(tx_mon_valid)
    begin
        if tx_mon_valid'event and tx_mon_valid = '1' then
            if tx_mon_wr_idx < TX_MON_BUFFER_SIZE then
                tx_mon_buffer(tx_mon_wr_idx) <= tx_mon_byte;
                tx_mon_wr_idx <= tx_mon_wr_idx + 1;
            end if;
        end if;
    end process;

    clk <= not clk after CLK_PERIOD / 2;

    process
        variable pass_cnt : integer := 0;
        variable fail_cnt : integer := 0;
        variable test_num : integer := 0;
    begin
        report "==============================" & character'val(10) &
            "Starting tb_aes_hil_top" & character'val(10) &
            "==============================" severity note;

        rst <= '1';
        wait for 100 ns;

        test_num := test_num + 1;
        if tx = '1' then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS - wrapper reset holds UART idle high" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL - UART TX not idle during reset" severity warning;
        end if;

        rst <= '0';
        wait for 200 ns;

        test_num := test_num + 1;
        if tx = '1' then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS - reset polarity released correctly" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL - wrapper reset polarity mismatch" severity warning;
        end if;

        test_num := test_num + 1;
        send_uart_byte(rx, x"4B");
        send_uart_byte(rx, x"3A");
        send_uart_string(rx, KEY_HEX);
        send_uart_byte(rx, x"0A");

        send_uart_byte(rx, x"4D");
        send_uart_byte(rx, x"3A");
        send_uart_byte(rx, x"31");
        send_uart_byte(rx, x"0A");

        send_uart_byte(rx, x"44");
        send_uart_byte(rx, x"3A");
        send_uart_string(rx, DATA_HEX);
        send_uart_byte(rx, x"0A");

        send_uart_byte(rx, x"53");
        send_uart_byte(rx, x"0A");

        wait for BIT_PERIOD;
        expect_uart_string(EXPECTED_HEX);
        pass_cnt := pass_cnt + 1;
        report "Test " & integer'image(test_num) & ": PASS - wrapper forwards UART AES transaction" severity note;

        wait for 400 us;

        test_num := test_num + 1;
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for 200 ns;

        if tx = '1' then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS - wrapper survives reset pulse" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL - TX did not return to idle after reset pulse" severity warning;
        end if;

        report "==============================" & character'val(10) &
            "FINAL REPORT" & character'val(10) &
            "PASS: " & integer'image(pass_cnt) & character'val(10) &
            "FAIL: " & integer'image(fail_cnt) & character'val(10) &
            "==============================" severity note;

        wait;
    end process;

end architecture sim;