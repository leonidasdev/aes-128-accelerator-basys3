----------------------------------------------------------------------------------
-- Module Name:    uart_aes_controller
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           29/04/2026
--
-- Description:
--   UART-to-AES controller that parses ASCII commands from the host and
--   drives the AES core (K, D, M, S commands). Returns the 32-hex ASCII
--   result followed by a newline.
--
--   Protocol (single-letter commands):
--     K:<32 hex nibbles>\n     Load key
--     D:<32 hex nibbles>\n     Load plaintext/ciphertext
--     M:<0|1>\n                Set mode (1=encrypt, 0=decrypt)
--     S\n                      Start AES computation
--   
--   Response format:
--     <32 hex nibbles>\n       Output ciphertext/plaintext
--
--   Implementation: Sequential FSM with UART RX/TX handshaking and AES core
--   orchestration.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_aes_controller is
    port (
        clk        : in  std_logic;
        rst_n      : in  std_logic;
        rx         : in  std_logic;
        tx         : out std_logic;
        led_status : out std_logic_vector(15 downto 0)
    );
end entity uart_aes_controller;

architecture rtl of uart_aes_controller is

    function ascii_to_hex(ascii_val : std_logic_vector(7 downto 0)) return std_logic_vector is
        variable num : unsigned(7 downto 0);
    begin
        num := unsigned(ascii_val);
        if num >= x"30" and num <= x"39" then
            return std_logic_vector(num(3 downto 0));
        elsif num >= x"41" and num <= x"46" then
            return std_logic_vector(num(3 downto 0) + 9);
        elsif num >= x"61" and num <= x"66" then
            return std_logic_vector(num(3 downto 0) + 9);
        else
            return x"0";
        end if;
    end function;

    function is_hex_ascii(ascii_val : std_logic_vector(7 downto 0)) return boolean is
        variable num : unsigned(7 downto 0);
    begin
        num := unsigned(ascii_val);
        return (num >= x"30" and num <= x"39") or
               (num >= x"41" and num <= x"46") or
               (num >= x"61" and num <= x"66");
    end function;

    function hex_to_ascii(hex_val : std_logic_vector(3 downto 0)) return std_logic_vector is
        variable num : integer range 0 to 15;
    begin
        num := to_integer(unsigned(hex_val));
        if num <= 9 then
            return std_logic_vector(to_unsigned(num + 48, 8));
        else
            return std_logic_vector(to_unsigned(num + 55, 8));
        end if;
    end function;

    component uart_rx
        generic ( CLKS_PER_BIT : integer := 868 );
        port (
            rst_n     : in  std_logic;
            clk      : in  std_logic;
            rx       : in  std_logic;
            rx_byte  : out std_logic_vector(7 downto 0);
            rx_valid : out std_logic
        );
    end component;

    component uart_tx
        generic ( BAUD_CLK : integer := 868 );
        port (
            rst_n      : in  std_logic;
            clk        : in  std_logic;
            tx_start   : in  std_logic;
            tx_data_in : in  std_logic_vector(7 downto 0);
            tx         : out std_logic;
            tx_ready   : out std_logic
        );
    end component;

    component aes_top
        port (
            clk      : in  std_logic;
            rst_n    : in  std_logic;
            start    : in  std_logic;
            enc_dec  : in  std_logic;
            data_in  : in  std_logic_vector(127 downto 0);
            key_in   : in  std_logic_vector(127 downto 0);
            data_out : out std_logic_vector(127 downto 0);
            done     : out std_logic;
            ready    : out std_logic;
            error    : out std_logic
        );
    end component;

    signal rx_byte_sig  : std_logic_vector(7 downto 0);
    signal rx_valid_sig : std_logic;
    signal tx_data_sig  : std_logic_vector(7 downto 0);
    signal tx_start_sig : std_logic := '0';
    signal tx_ready_sig : std_logic;

    signal aes_start    : std_logic := '0';
    signal aes_enc_dec  : std_logic := '1';
    signal aes_data_in  : std_logic_vector(127 downto 0) := (others => '0');
    signal aes_key_in   : std_logic_vector(127 downto 0) := (others => '0');
    signal aes_data_out : std_logic_vector(127 downto 0);
    signal aes_done     : std_logic;
    signal aes_ready    : std_logic;
    signal aes_error    : std_logic;

    type t_state is (
        IDLE, WAIT_COLON, READ_HEX, READ_MODE, WAIT_NEWLINE,
        WAIT_NEWLINE_START, EXECUTE_AES, SEND_RESULT, SEND_NEWLINE, WAIT_TX
    );
    signal state : t_state := IDLE;

    type t_cmd is (CMD_KEY, CMD_DATA, CMD_MODE, CMD_NONE);
    signal current_cmd : t_cmd := CMD_NONE;

    signal nibble_cnt : integer range 0 to 31 := 0;
    signal out_reg    : std_logic_vector(127 downto 0) := (others => '0');

begin

    u_rx : uart_rx
        port map (
            rst_n    => rst_n,
            clk      => clk,
            rx       => rx,
            rx_byte  => rx_byte_sig,
            rx_valid => rx_valid_sig
        );

    u_tx : uart_tx
        port map (
            rst_n      => rst_n,
            clk        => clk,
            tx_start   => tx_start_sig,
            tx_data_in => tx_data_sig,
            tx         => tx,
            tx_ready   => tx_ready_sig
        );

    u_aes : aes_top
        port map (
            clk      => clk,
            rst_n    => rst_n,
            start    => aes_start,
            enc_dec  => aes_enc_dec,
            data_in  => aes_data_in,
            key_in   => aes_key_in,
            data_out => aes_data_out,
            done     => aes_done,
            ready    => aes_ready,
            error    => aes_error
        );

    led_status(15) <= aes_ready;
    led_status(14) <= aes_done;
    led_status(13) <= aes_error;
    led_status(12) <= aes_enc_dec;
    led_status(11 downto 0) <= (others => '0');

    process(clk, rst_n)
        variable prev_state : t_state := IDLE;
    begin
        if rst_n = '0' then
            state <= IDLE;
            aes_start <= '0';
            tx_start_sig <= '0';
            tx_data_sig <= (others => '0');
            aes_data_in <= (others => '0');
            aes_key_in <= (others => '0');
            aes_enc_dec <= '1';
            current_cmd <= CMD_NONE;
            nibble_cnt <= 0;
            out_reg <= (others => '0');
        elsif rising_edge(clk) then
            aes_start <= '0';

            case state is
                when IDLE =>
                    tx_start_sig <= '0';
                    if rx_valid_sig = '1' then
                        if rx_byte_sig = x"4B" then
                            current_cmd <= CMD_KEY;
                            state <= WAIT_COLON;
                        elsif rx_byte_sig = x"44" then
                            current_cmd <= CMD_DATA;
                            state <= WAIT_COLON;
                        elsif rx_byte_sig = x"4D" then
                            current_cmd <= CMD_MODE;
                            state <= WAIT_COLON;
                        elsif rx_byte_sig = x"53" then
                            current_cmd <= CMD_NONE;
                            state <= WAIT_NEWLINE_START;
                        end if;
                    end if;

                when WAIT_COLON =>
                    if rx_valid_sig = '1' then
                        if rx_byte_sig = x"3A" then
                            if current_cmd = CMD_MODE then
                                state <= READ_MODE;
                            else
                                nibble_cnt <= 31;
                                state <= READ_HEX;
                            end if;
                        elsif rx_byte_sig = x"0A" then
                            state <= IDLE;
                            current_cmd <= CMD_NONE;
                        else
                            state <= IDLE;
                            current_cmd <= CMD_NONE;
                            aes_key_in <= (others => '0');
                            aes_data_in <= (others => '0');
                            nibble_cnt <= 0;
                        end if;
                    end if;

                when READ_HEX =>
                    if rx_valid_sig = '1' then
                        if is_hex_ascii(rx_byte_sig) then
                            if current_cmd = CMD_KEY then
                                aes_key_in <= aes_key_in(123 downto 0) & ascii_to_hex(rx_byte_sig);
                            else
                                aes_data_in <= aes_data_in(123 downto 0) & ascii_to_hex(rx_byte_sig);
                            end if;

                            if nibble_cnt = 0 then
                                state <= WAIT_NEWLINE;
                            else
                                nibble_cnt <= nibble_cnt - 1;
                            end if;
                        else
                            state <= IDLE;
                            current_cmd <= CMD_NONE;
                            nibble_cnt <= 0;
                            aes_key_in <= (others => '0');
                            aes_data_in <= (others => '0');
                        end if;
                    end if;

                when READ_MODE =>
                    if rx_valid_sig = '1' then
                        if rx_byte_sig = x"31" then
                            aes_enc_dec <= '1';
                            state <= WAIT_NEWLINE;
                        elsif rx_byte_sig = x"30" then
                            aes_enc_dec <= '0';
                            state <= WAIT_NEWLINE;
                        else
                            state <= IDLE;
                            current_cmd <= CMD_NONE;
                            aes_key_in <= (others => '0');
                            aes_data_in <= (others => '0');
                        end if;
                    end if;

                when WAIT_NEWLINE =>
                    if rx_valid_sig = '1' and rx_byte_sig = x"0A" then
                        state <= IDLE;
                    end if;

                when WAIT_NEWLINE_START =>
                    if rx_valid_sig = '1' and rx_byte_sig = x"0A" then
                        if aes_ready = '1' then
                            aes_start <= '1';
                            state <= EXECUTE_AES;
                        else
                            state <= IDLE;
                        end if;
                    end if;

                when EXECUTE_AES =>
                    if aes_done = '1' then
                        out_reg <= aes_data_out;
                        nibble_cnt <= 31;
                        state <= SEND_RESULT;
                    end if;

                when SEND_RESULT =>
                    if tx_ready_sig = '1' and tx_start_sig = '0' then
                        tx_data_sig <= hex_to_ascii(out_reg(127 downto 124));
                        tx_start_sig <= '1';
                        out_reg <= out_reg(123 downto 0) & x"0";

                        if nibble_cnt = 0 then
                            state <= SEND_NEWLINE;
                        else
                            nibble_cnt <= nibble_cnt - 1;
                        end if;
                    else
                        tx_start_sig <= '0';
                    end if;

                when SEND_NEWLINE =>
                    if tx_ready_sig = '1' and tx_start_sig = '0' then
                        tx_data_sig <= x"0A";
                        tx_start_sig <= '1';
                        state <= WAIT_TX;
                    else
                        tx_start_sig <= '0';
                    end if;

                when WAIT_TX =>
                    tx_start_sig <= '0';
                    if tx_ready_sig = '1' then
                        state <= IDLE;
                    end if;

            end case;
        end if;
    end process;

end architecture rtl;
