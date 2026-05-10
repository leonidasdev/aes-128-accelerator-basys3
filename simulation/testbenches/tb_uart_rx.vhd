library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity tb_uart_rx is
end tb_uart_rx;

architecture sim of tb_uart_rx is
    constant CLK_PERIOD : time := 10 ns;     -- 100 MHz
    constant BIT_PERIOD : time := 8.68 us;   -- 1 / 115200 baudios

    signal clk      : std_logic := '0';
    signal rx       : std_logic := '1'; -- Reposo en alto
    signal rx_byte  : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;

    -- Procedimiento para generar la trama UART desde el TB
    procedure send_byte (
        constant data : in std_logic_vector(7 downto 0);
        signal serial_out : out std_logic
    ) is
    begin
        serial_out <= '0'; -- START BIT
        wait for BIT_PERIOD;
        for i in 0 to 7 loop
            serial_out <= data(i); -- DATA BITS (LSB primero)
            wait for BIT_PERIOD;
        end loop;
        serial_out <= '1'; -- STOP BIT
        wait for BIT_PERIOD;
    end procedure;

begin
    -- Instancia del módulo
    uut: entity work.uart_rx_module
        generic map ( CLKS_PER_BIT => 868 )
        port map (
            clk      => clk,
            rx       => rx,
            rx_byte  => rx_byte,
            rx_valid => rx_valid
        );

    -- Generador de reloj
    clk <= not clk after CLK_PERIOD / 2;

    process begin
        wait for 100 ns;
        -- Enviamos el byte 0x41
        send_byte(x"41", rx);
        
        wait for 100 us;
        
        -- Enviamos otro byte de prueba 0x55 (01010101)
        send_byte(x"55", rx);

        wait for 500 us;
        report "Simulacion de RX completada con exito" severity failure;
    end process;
end sim;