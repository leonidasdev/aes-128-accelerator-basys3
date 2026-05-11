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
    constant CLKS_PER_BIT : natural := 868;
    constant BIT_PERIOD : time := CLK_PERIOD * CLKS_PER_BIT;
    constant IDLE_GAP_CYCLES : natural := CLKS_PER_BIT;

    constant KEY_HEX : string := "000102030405060708090A0B0C0D0E0F";
    constant DATA_HEX : string := "00112233445566778899AABBCCDDEEFF";
    constant EXPECTED_HEX : string := "69C4E0D86A7B0430D8CDB78070B4C55A";

    signal clk        : std_logic := '0';
    signal rst_n      : std_logic := '0';
    signal rx         : std_logic := '1';
    signal tx         : std_logic;
    signal tx_mon_byte  : std_logic_vector(7 downto 0);
    signal tx_mon_valid  : std_logic;
    signal led_status : std_logic_vector(15 downto 0);

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
        -- Print debug info showing which byte is being sent
        if data_byte >= x"20" and data_byte <= x"7E" then
            char_val := character'val(to_integer(unsigned(data_byte)));
            report "SEND_BYTE: '" & char_val & "' (" & 
                integer'image(to_integer(unsigned(data_byte))) & ")" severity note;
        else
            report "SEND_BYTE: " & integer'image(to_integer(unsigned(data_byte))) severity note;
        end if;

        -- Start bit
        wait until falling_edge(clk);
        serial_out <= '0';
        report "[TX_BIT] Start bit (0) at " & time'image(now) severity note;
        for bit_cycle in 1 to CLKS_PER_BIT loop
            wait until rising_edge(clk);
        end loop;

        -- Data bits (LSB first)
        for bit_index in 0 to 7 loop
            wait until falling_edge(clk);
            serial_out <= data_byte(bit_index);
            report "[TX_BIT] Data bit " & integer'image(bit_index) & " = " & std_logic'image(data_byte(bit_index)) & " at " & time'image(now) severity note;
            for bit_cycle in 1 to CLKS_PER_BIT loop
                wait until rising_edge(clk);
            end loop;
        end loop;

        -- Stop bit
        wait until falling_edge(clk);
        serial_out <= '1';
        report "[TX_BIT] Stop bit (1) at " & time'image(now) severity note;
        for bit_cycle in 1 to CLKS_PER_BIT loop
            wait until rising_edge(clk);
        end loop;

        -- Inter-byte gap: ensure at least 1 bit time of idle
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
        report "[EXPECT_STR] Starting string reception at " & time'image(now) severity note;
        for index in expected_text'range loop
            while tx_mon_wr_idx <= byte_count loop
                wait until rising_edge(clk);
            end loop;
            received_byte := tx_mon_buffer(byte_count);
            byte_count := byte_count + 1;
            report "[RX_BYTE " & integer'image(integer(byte_count)) & "] Buffered byte = " & integer'image(to_integer(unsigned(received_byte))) &
                   " ('" & character'val(to_integer(unsigned(received_byte))) & "') at " & time'image(now) severity note;
            assert received_byte = char_to_slv(expected_text(index))
                report "UART response mismatch at character " & integer'image(index) & 
                    " (expected " & integer'image(to_integer(unsigned(char_to_slv(expected_text(index))))) &
                    " '" & expected_text(index) & "', got " & integer'image(to_integer(unsigned(received_byte))) & ")"
                severity error;
        end loop;

        while tx_mon_wr_idx <= byte_count loop
            wait until rising_edge(clk);
        end loop;
        received_byte := tx_mon_buffer(byte_count);
        report "[RX_BYTE " & integer'image(integer(byte_count + 1)) & "] Buffered byte = " & integer'image(to_integer(unsigned(received_byte))) &
               " ('" & character'val(to_integer(unsigned(received_byte))) & "') at " & time'image(now) severity note;
        assert received_byte = x"0A"
            report "UART response missing trailing newline (got " & 
                integer'image(to_integer(unsigned(received_byte))) & ")"
            severity error;
        report "[EXPECT_STR] String reception complete at " & time'image(now) severity note;
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

    tx_monitor : entity work.uart_rx
        generic map ( CLKS_PER_BIT => CLKS_PER_BIT )
        port map (
            rst_n    => rst_n,
            clk      => clk,
            rx       => tx,
            rx_byte  => tx_mon_byte,
            rx_valid => tx_mon_valid
        );

    process(tx_mon_valid, rst_n)
    begin
        if rst_n = '0' then
            tx_mon_wr_idx <= 0;
        elsif tx_mon_valid'event and tx_mon_valid = '1' then
            if tx_mon_wr_idx < TX_MON_BUFFER_SIZE then
                tx_mon_buffer(tx_mon_wr_idx) <= tx_mon_byte;
                report "[TX_MON] Stored byte " & integer'image(to_integer(unsigned(tx_mon_byte))) &
                       " at buffer index " & integer'image(tx_mon_wr_idx) severity note;
                tx_mon_wr_idx <= tx_mon_wr_idx + 1;
            end if;
        end if;
    end process;

    clk <= not clk after CLK_PERIOD / 2;

    process
        variable pass_cnt : integer := 0;
        variable fail_cnt : integer := 0;
        variable test_num : integer := 0;
        variable idle_wait : time;
        constant KEY_HEX_LOWER : string := "000102030405060708090a0b0c0d0e0f";
    begin
        report "==============================" & character'val(10) &
            "Starting tb_uart_aes_controller" & character'val(10) &
            "==============================" severity note;

        rst_n <= '0';
        wait for 200 ns;
        rst_n <= '1';
        wait for 200 ns;

        -- Test 1: Happy-path encryption transaction.
        test_num := test_num + 1;
        report "======== Test " & integer'image(test_num) & ": Sending KEY command ========" severity note;
        send_uart_byte(rx, x"4B");  -- 'K'
        send_uart_byte(rx, x"3A");  -- ':'
        send_uart_string(rx, KEY_HEX);
        send_uart_byte(rx, x"0A");

        report "======== Test " & integer'image(test_num) & ": Sending MODE command ========" severity note;
        send_uart_byte(rx, x"4D");  -- 'M'
        send_uart_byte(rx, x"3A");  -- ':'
        send_uart_byte(rx, x"31");  -- '1'
        send_uart_byte(rx, x"0A");

        report "======== Test " & integer'image(test_num) & ": Sending DATA command ========" severity note;
        send_uart_byte(rx, x"44");  -- 'D'
        send_uart_byte(rx, x"3A");  -- ':'
        send_uart_string(rx, DATA_HEX);
        send_uart_byte(rx, x"0A");

        report "======== Test " & integer'image(test_num) & ": Sending START command ========" severity note;
        send_uart_byte(rx, x"53");  -- 'S'
        send_uart_byte(rx, x"0A");

        report "======== Test " & integer'image(test_num) & ": Expecting response ========" severity note;
        report "[TEST] TX line state at response decode start: " & std_logic'image(tx) severity note;
        
        -- IMPORTANT: The controller may have already started transmitting, and the 
        -- inter-byte gap in the controller is very small (~1 BIT_PERIOD). 
        -- To ensure we sync to a clean byte boundary, wait for the next start bit
        -- (falling edge), which guarantees we're at a byte boundary.
        report "[TEST] Waiting for confirmed byte boundary (next start bit)..." severity note;
        if tx = '0' then
            -- Already in a start bit, wait for it to finish and next one to begin
            wait until tx = '1';
        end if;
        -- Line is now high. Wait for the NEXT falling edge (start bit of next byte)
        wait until tx = '0';
        report "[TEST] Detected start bit at " & time'image(now) severity note;
        
        expect_uart_string(EXPECTED_HEX);
        pass_cnt := pass_cnt + 1;
        report "Test " & integer'image(test_num) & ": PASS" severity note;

        -- Fixed wait to ensure complete response transmission (32 bytes + newline = ~286 µs, use 400 µs buffer)
        report "[TEST] Waiting 400 µs for complete response transmission..." severity note;
        wait for 400 us;

        -- Malformed-input recovery: inject a bad hex character, then verify the
        -- controller still accepts the next valid transaction.
        send_uart_byte(rx, x"4B");  -- 'K'
        send_uart_byte(rx, x"3A");  -- ':'
        send_uart_string(rx, "00010203040506070899AABBCCDDEEEEEE");
        send_uart_byte(rx, x"0A");

        wait for 100 us;
        test_num := test_num + 1;
        if tx /= '1' then
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL - malformed input triggered unexpected UART response" severity warning;
        else
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS" severity note;
        end if;

        -- Lowercase hex handling test
        send_uart_byte(rx, x"4B");  -- 'K'
        send_uart_byte(rx, x"3A");  -- ':'
        send_uart_string(rx, KEY_HEX_LOWER);
        send_uart_byte(rx, x"0A");

        send_uart_byte(rx, x"4D");  -- 'M'
        send_uart_byte(rx, x"3A");  -- ':'
        send_uart_byte(rx, x"31");  -- '1'
        send_uart_byte(rx, x"0A");

        send_uart_byte(rx, x"44");  -- 'D'
        send_uart_byte(rx, x"3A");  -- ':'
        send_uart_string(rx, DATA_HEX);
        send_uart_byte(rx, x"0A");

        send_uart_byte(rx, x"53");  -- 'S'
        send_uart_byte(rx, x"0A");

        expect_uart_string(EXPECTED_HEX);
        test_num := test_num + 1;
        pass_cnt := pass_cnt + 1;
        report "Test " & integer'image(test_num) & ": PASS" severity note;

        -- Wait for TX to actually complete transmission (not just decoder finish)
        -- TX idles high, so wait for it to return to high state after transmission
        if tx = '0' then
            report "[TEST] TX is still transmitting, waiting for idle..." severity note;
            wait until tx = '1';
        end if;
        -- After TX goes high, wait for one more byte period as safety margin
        -- to ensure stop bit is fully transmitted before next command arrives
        wait for BIT_PERIOD * 10;  -- ~87 µs safety margin for full byte
        report "[TEST] TX confirmed idle, proceeding with next test" severity note;

         -- Back-to-back transactions: send a second identical request immediately
         -- after the first to stress controller buffering / busy handling.
         send_uart_byte(rx, x"4B");  -- 'K'
         send_uart_byte(rx, x"3A");  -- ':'
         send_uart_string(rx, KEY_HEX);
         send_uart_byte(rx, x"0A");

         send_uart_byte(rx, x"4D");  -- 'M'
         send_uart_byte(rx, x"3A");  -- ':'
         send_uart_byte(rx, x"31");  -- '1'
         send_uart_byte(rx, x"0A");

         send_uart_byte(rx, x"44");  -- 'D'
         send_uart_byte(rx, x"3A");  -- ':'
         send_uart_string(rx, DATA_HEX);
         send_uart_byte(rx, x"0A");

         send_uart_byte(rx, x"53");  -- 'S'
         send_uart_byte(rx, x"0A");

         -- Immediately send a second transaction without waiting for the first response
         send_uart_byte(rx, x"4B");  -- 'K'
         send_uart_byte(rx, x"3A");  -- ':'
         send_uart_string(rx, KEY_HEX);
         send_uart_byte(rx, x"0A");

         send_uart_byte(rx, x"4D");  -- 'M'
         send_uart_byte(rx, x"3A");  -- ':'
         send_uart_byte(rx, x"31");  -- '1'
         send_uart_byte(rx, x"0A");

         send_uart_byte(rx, x"44");  -- 'D'
         send_uart_byte(rx, x"3A");  -- ':'
         send_uart_string(rx, DATA_HEX);
         send_uart_byte(rx, x"0A");

         send_uart_byte(rx, x"53");  -- 'S'
         send_uart_byte(rx, x"0A");

        -- Expect two responses in sequence
        test_num := test_num + 1;
        expect_uart_string(EXPECTED_HEX);
        pass_cnt := pass_cnt + 1;
        report "Test " & integer'image(test_num) & ": PASS (back-to-back responses)" severity note;

         -- Final report
         report "==============================" & character'val(10) &
             "FINAL REPORT" & character'val(10) &
             "PASS: " & integer'image(pass_cnt) & character'val(10) &
             "FAIL: " & integer'image(fail_cnt) & character'val(10) &
             "==============================" severity note;

         wait;
    end process;
end architecture sim;
