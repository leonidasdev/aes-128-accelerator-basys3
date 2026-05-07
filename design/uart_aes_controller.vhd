library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_aes_controller is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;
        rx       : in  std_logic;
        tx       : out std_logic;
        led_status : out std_logic_vector(15 downto 0) -- Opcional, para ver en la placa
    );
end entity uart_aes_controller;

architecture rtl of uart_aes_controller is

    -- FUNCIONES DE TRADUCCIÓN ASCII <-> HEX
    -- Convierte un byte ASCII (ej. 'A' = x"41") a un nibble de 4 bits (ej. x"A")
    function ascii_to_hex(ascii_val : std_logic_vector(7 downto 0)) return std_logic_vector is
        variable num : unsigned(7 downto 0);
    begin
        num := unsigned(ascii_val);
        if num >= x"30" and num <= x"39" then     -- '0' a '9'
            return std_logic_vector(num(3 downto 0));
        elsif num >= x"41" and num <= x"46" then  -- 'A' a 'F'
            return std_logic_vector(num(3 downto 0) + 9);
        elsif num >= x"61" and num <= x"66" then  -- 'a' a 'f'
            return std_logic_vector(num(3 downto 0) + 9);
        else
            return x"0"; -- Carácter inválido
        end if;
    end function;

    -- Convierte un nibble de 4 bits (ej. x"A") a un byte ASCII (ej. 'A' = x"41")
    function hex_to_ascii(hex_val : std_logic_vector(3 downto 0)) return std_logic_vector is
        variable num : integer range 0 to 15;
    begin
        num := to_integer(unsigned(hex_val));
        if num <= 9 then
            return std_logic_vector(to_unsigned(num + 48, 8)); -- 48 es x"30" ('0')
        else
            return std_logic_vector(to_unsigned(num + 55, 8)); -- 55 + 10 = 65 = x"41" ('A')
        end if;
    end function;

    component uart_rx_module
        generic ( CLKS_PER_BIT : integer := 868 );
        port (
            clk      : in  std_logic;
            rx       : in  std_logic;
            rx_byte  : out std_logic_vector(7 downto 0);
            rx_valid : out std_logic
        );
    end component;

    component uart_tx
        generic ( BAUD_CLK : integer := 868 );
        port (
            clk        : in  std_logic;
            tx_start   : in  std_logic;
            tx_data_in : in  std_logic_vector(7 downto 0);
            tx         : out std_logic;
            tx_ready   : out std_logic
        );
    end component;
    
    -- Faltaría instanciar aquí tu aes_top
    -- Señales internas de interconexión
    signal rx_byte_sig  : std_logic_vector(7 downto 0);
    signal rx_valid_sig : std_logic;
    signal tx_data_sig  : std_logic_vector(7 downto 0);
    signal tx_start_sig : std_logic := '0';
    signal tx_ready_sig : std_logic;

    -- Estados de la FSM principal
    type t_state is (
        IDLE, 
        PARSE_CMD, 
        READ_KEY, 
        READ_DATA, 
        WAIT_AES_DONE, 
        SEND_RESPONSE
    );
    signal current_state : t_state := IDLE;

begin

    -- Instancia del RX de uart
    u_rx : uart_rx_module port map (
        clk => clk, rx => rx, rx_byte => rx_byte_sig, rx_valid => rx_valid_sig
    );

    -- Instancia del TX de uart
    u_tx : uart_tx port map (
        clk => clk, tx_start => tx_start_sig, tx_data_in => tx_data_sig, tx => tx, tx_ready => tx_ready_sig
    );


end architecture rtl;