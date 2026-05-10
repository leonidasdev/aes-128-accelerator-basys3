----------------------------------------------------------------------------------
-- Module Name:    tb_uart_aes_controller
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           29/04/2026
--
-- Description:
--   Integration testbench for the UART-to-AES controller. Validates the full
--   ASCII protocol, AES result formatting, malformed-input recovery, and
--   controller-to-UART handshaking.
--
--   Implementation: Self-checking stimulus and response decoder over the UART
--   serial lines.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart_aes_controller is
end tb_uart_aes_controller;

architecture sim of tb_uart_aes_controller is
    constant CLK_PERIOD : time := 10 ns;   -- 100 MHz
    constant BIT_PERIOD : time := 8.68 us; -- 115200 baud

    constant KEY_HEX : string := "000102030405060708090A0B0C0D0E0F";
    constant DATA_HEX : string := "00112233445566778899AABBCCDDEEFF";
    constant EXPECTED_HEX : string := "69C4E0D86A7B0430D8CDB78070B4C55A";

    signal clk        : std_logic := '0';
    signal rst_n      : std_logic := '0';
    signal rx         : std_logic := '1';
    signal tx         : std_logic;
    signal led_status : std_logic_vector(15 downto 0);

    function char_to_slv(value : character) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(character'pos(value), 8));
    end function;

    procedure send_uart_byte(
        signal serial_out : out std_logic;
        constant data_byte : in std_logic_vector(7 downto 0)
    ) is
    begin
        serial_out <= '0';
        wait for BIT_PERIOD;

        for bit_index in 0 to 7 loop
            serial_out <= data_byte(bit_index);
            wait for BIT_PERIOD;
        end loop;

        serial_out <= '1';
        wait for BIT_PERIOD;
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

    procedure receive_uart_byte(
        signal serial_in : in std_logic;
        variable data_byte : out std_logic_vector(7 downto 0)
    ) is
    begin
        wait until serial_in'event and serial_in = '0';
        wait for BIT_PERIOD / 2;

        for bit_index in 0 to 7 loop
            wait for BIT_PERIOD;
            data_byte(bit_index) := serial_in;
        end loop;

        wait for BIT_PERIOD;
    end procedure;

    procedure expect_uart_string(
        signal serial_in : in std_logic;
        constant expected_text : in string
    ) is
        variable received_byte : std_logic_vector(7 downto 0);
    begin
        for index in expected_text'range loop
            receive_uart_byte(serial_in, received_byte);
            assert received_byte = char_to_slv(expected_text(index))
                report "UART response mismatch at character " & integer'image(index)
                severity error;
        end loop;

        receive_uart_byte(serial_in, received_byte);
        assert received_byte = x"0A"
            report "UART response missing trailing newline"
            severity error;
    end procedure;

begin
    uut: entity work.uart_aes_controller
        port map (
            clk        => clk,
            rst_n      => rst_n,
            rx         => rx,
            tx         => tx,
            led_status => led_status
        );

    clk <= not clk after CLK_PERIOD / 2;

    process
        variable idle_wait : time;
    begin
        rst_n <= '0';
        wait for 200 ns;
        rst_n <= '1';
        wait for 200 ns;

        -- Happy-path encryption transaction.
        send_uart_string(rx, "KEY:");
        send_uart_string(rx, KEY_HEX);
        send_uart_byte(rx, x"0A");

        send_uart_string(rx, "MODE:");
        send_uart_byte(rx, x"31");
        send_uart_byte(rx, x"0A");

        send_uart_string(rx, "DATA:");
        send_uart_string(rx, DATA_HEX);
        send_uart_byte(rx, x"0A");

        send_uart_string(rx, "START");
        send_uart_byte(rx, x"0A");

        expect_uart_string(tx, EXPECTED_HEX);

        idle_wait := 200 us;
        wait for idle_wait;
        assert tx = '1'
            report "UART TX did not return to idle after happy-path response"
            severity error;

        -- Malformed-input recovery: inject a bad hex character, then verify the
        -- controller still accepts the next valid transaction.
        send_uart_string(rx, "KEY:");
        send_uart_string(rx, "00010203040506070899AABBCCDDEEFZ");
        send_uart_byte(rx, x"0A");

        wait for 100 us;
        assert tx = '1'
            report "Malformed input should not trigger a UART response"
            severity error;

        send_uart_string(rx, "KEY:");
        send_uart_string(rx, KEY_HEX);
        send_uart_byte(rx, x"0A");

        send_uart_string(rx, "MODE:");
        send_uart_byte(rx, x"31");
        send_uart_byte(rx, x"0A");

        send_uart_string(rx, "DATA:");
        send_uart_string(rx, DATA_HEX);
        send_uart_byte(rx, x"0A");

        send_uart_string(rx, "START");
        send_uart_byte(rx, x"0A");

        expect_uart_string(tx, EXPECTED_HEX);

        wait for 200 us;
        assert false report "UART-AES controller integration test completed" severity failure;
    end process;
end sim;
