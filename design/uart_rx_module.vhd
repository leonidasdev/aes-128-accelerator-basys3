library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity uart_rx_module is
    generic (
        CLKS_PER_BIT : integer := 868  -- (100 MHz / 115200 baudios)
    );
    port (
        clk       : in  std_logic;
        rx        : in  std_logic;
        rx_byte   : out std_logic_vector(7 downto 0);
        rx_valid  : out std_logic
    );
end uart_rx_module;

architecture rtl of uart_rx_module is

    type state_type is (IDLE, START_BIT, DATA_BITS, STOP_BIT, CLEANUP);
    signal state : state_type := IDLE;

    signal clk_cnt : integer range 0 to CLKS_PER_BIT-1 := 0;
    signal bit_idx : integer range 0 to 7 := 0;
    signal rx_data : std_logic_vector(7 downto 0) := (others => '0');
    
    -- Sincronizadores para evitar metaestabilidad en señales asíncronas
    signal rx_meta : std_logic := '1';
    signal rx_reg  : std_logic := '1';

begin

    -- Sincronizar la entrada RX con el reloj de la FPGA
    process(clk)
    begin
        if rising_edge(clk) then
            rx_meta <= rx;
            rx_reg  <= rx_meta;
        end if;
    end process;

    -- Máquina de estados principal del Receptor
    process(clk)
    begin
        if rising_edge(clk) then
            rx_valid <= '0'; -- Por defecto en '0', solo pulsa al terminar un byte

            case state is
                when IDLE =>
                    clk_cnt <= 0;
                    bit_idx <= 0;
                    if rx_reg = '0' then       -- Detecta el 'Start Bit' (flanco de bajada)
                        state <= START_BIT;
                    end if;

                when START_BIT =>
                    if clk_cnt = (CLKS_PER_BIT-1)/2 then
                        if rx_reg = '0' then   -- Verifica que sigo en '0' a la mitad del bit
                            clk_cnt <= 0;
                            state <= DATA_BITS;
                        else
                            state <= IDLE;     -- Falsa alarma (glitch de ruido)
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
                    -- Espera a terminar el Stop Bit
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