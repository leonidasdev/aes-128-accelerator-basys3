--
-- Purpose:   Basys 3 board wrapper for the AES-128 core.
--
-- Description:
-- This wrapper keeps the synthesizable top-level I/O small enough for the
-- XC7A35T/CPG236 package by instantiating the AES core internally and
-- selecting from a small set of built-in FIPS test vectors.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity basys3_top is
    port (
        clk        : in  std_logic;
        rst_n      : in  std_logic;
        start_btn  : in  std_logic;
        mode_sw    : in  std_logic;
        vector_sel : in  std_logic_vector(2 downto 0);
        led        : out std_logic_vector(15 downto 0)
    );
end entity basys3_top;

architecture rtl of basys3_top is

    type t_state_array is array (natural range <>) of std_logic_vector(127 downto 0);

    constant PLAINTEXT_VECTORS : t_state_array(0 to 4) := (
        x"00112233445566778899AABBCCDDEEFF",
        x"6BC1BEE22E409F96E93D7E117393172A",
        x"AE2D8A571E03AC9C9EB76FAC45AF8E51",
        x"30C81C46A35CE411E5FBE6FBF7404067",
        x"F69F2445DF4F9B17AD2B417BE66C3710"
    );

    constant CIPHERTEXT_VECTORS : t_state_array(0 to 4) := (
        x"69C4E0D86A7B0430D8CDB78070B4C55A",
        x"3AD77BB40D7A3660A89ECAF32466EF97",
        x"F5D3D58503B9699DE785895A96FDBAAF",
        x"B6BC73E109EB1E1988362AB019322385",
        x"7B0C785E27E8AD3F8223207104725DD4"
    );

    constant KEY_VECTORS : t_state_array(0 to 4) := (
        x"000102030405060708090A0B0C0D0E0F",
        x"2B7E151628AED2A6ABF7158809CF4F3C",
        x"2B7E151628AED2A6ABF7158809CF4F3C",
        x"2B7E151628AED2A6ABF7158809CF4F3C",
        x"2B7E151628AED2A6ABF7158809CF4F3C"
    );

    signal core_start     : std_logic := '0';
    signal core_done      : std_logic;
    signal core_ready     : std_logic;
    signal core_error     : std_logic;
    signal core_enc_dec   : std_logic;
    signal core_data_in   : std_logic_vector(127 downto 0);
    signal core_key_in    : std_logic_vector(127 downto 0);
    signal core_data_out  : std_logic_vector(127 downto 0);
    signal result_reg     : std_logic_vector(127 downto 0) := (others => '0');
    signal start_btn_d    : std_logic := '0';
    signal vector_index   : integer range 0 to 4 := 0;
    constant ZERO9 : std_logic_vector(8 downto 0) := (others => '0');

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
    end component aes_top;

    function decode_vector_index(sel : std_logic_vector(2 downto 0)) return integer is
    begin
        case sel is
            when "000" => return 0;
            when "001" => return 1;
            when "010" => return 2;
            when "011" => return 3;
            when "100" => return 4;
            when others => return 0;
        end case;
    end function;

begin

    vector_index <= decode_vector_index(vector_sel);
    core_enc_dec <= mode_sw;

    process(vector_index, mode_sw)
    begin
        if mode_sw = '1' then
            core_data_in <= PLAINTEXT_VECTORS(vector_index);
        else
            core_data_in <= CIPHERTEXT_VECTORS(vector_index);
        end if;

        core_key_in <= KEY_VECTORS(vector_index);
    end process;

    u_core : aes_top
        port map (
            clk      => clk,
            rst_n    => rst_n,
            start    => core_start,
            enc_dec  => core_enc_dec,
            data_in  => core_data_in,
            key_in   => core_key_in,
            data_out => core_data_out,
            done     => core_done,
            ready    => core_ready,
            error    => core_error
        );

    process(clk, rst_n)
    begin
        if rst_n = '0' then
            core_start  <= '0';
            start_btn_d <= '0';
            result_reg  <= (others => '0');
        elsif rising_edge(clk) then
            core_start <= '0';

            if start_btn = '1' and start_btn_d = '0' and core_ready = '1' then
                core_start <= '1';
            end if;

            start_btn_d <= start_btn;

            if core_done = '1' then
                result_reg <= core_data_out;
            end if;
        end if;
    end process;

    -- LED mapping: provide simple, human-readable status bits on the 16 LEDs
    -- Bits (MSB->LSB):
    -- 15: core_ready
    -- 14: core_done
    -- 13: core_error
    -- 12: core_enc_dec (1 = encrypt)
    -- 11..9: vector_sel[2:0]
    -- 8..0: reserved / zero
    led <= core_ready & core_done & core_error & core_enc_dec & vector_sel & ZERO9;

end architecture rtl;