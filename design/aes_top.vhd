----------------------------------------------------------------------------------
-- Module Name:    aes_top
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           29/04/2026
--
-- Description:
--   Top-level wrapper integrating FSM, datapath, and key expansion.
--   Provides external interface for start signal, plaintext/ciphertext,
--   master key, and output completion signal.
--
--   Implementation: Synchronous design with start/done handshake protocol.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity aes_top is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;
        start    : in  std_logic;
        enc_dec  : in  std_logic;                 -- 1 = encrypt, 0 = decrypt
        data_in  : in  std_logic_vector(127 downto 0);
        key_in   : in  std_logic_vector(127 downto 0);
        data_out : out std_logic_vector(127 downto 0);
        done     : out std_logic;
        ready    : out std_logic;
        error    : out std_logic
    );
end entity aes_top;

architecture rtl of aes_top is

    function slv_to_hstring(value : std_logic_vector) return string is
        variable result : string(1 to value'length / 4);
        variable nibble : std_logic_vector(3 downto 0);
    begin
        for i in 0 to result'length - 1 loop
            nibble := value(value'left - i * 4 downto value'left - i * 4 - 3);
            case to_integer(unsigned(nibble)) is
                when 0  => result(i + 1) := '0';
                when 1  => result(i + 1) := '1';
                when 2  => result(i + 1) := '2';
                when 3  => result(i + 1) := '3';
                when 4  => result(i + 1) := '4';
                when 5  => result(i + 1) := '5';
                when 6  => result(i + 1) := '6';
                when 7  => result(i + 1) := '7';
                when 8  => result(i + 1) := '8';
                when 9  => result(i + 1) := '9';
                when 10 => result(i + 1) := 'A';
                when 11 => result(i + 1) := 'B';
                when 12 => result(i + 1) := 'C';
                when 13 => result(i + 1) := 'D';
                when 14 => result(i + 1) := 'E';
                when others => result(i + 1) := 'F';
            end case;
        end loop;
        return result;
    end function;

    -- FSM signals
    signal fsm_done, fsm_state_ld, fsm_state_en, fsm_key_ld : std_logic;
    signal fsm_first_rnd, fsm_final_rnd : std_logic;
    signal fsm_round : std_logic_vector(3 downto 0);
    signal fsm_ready, fsm_error : std_logic;

    -- Datapath signals
    signal datapath_state_out : std_logic_vector(127 downto 0);

    -- Key expansion signals
    signal expanded_key_comb : std_logic_vector(127 downto 0);

    -- Input registers for latching data/key until operations complete
    signal data_reg : std_logic_vector(127 downto 0);
    signal key_reg : std_logic_vector(127 downto 0);
    signal enc_dec_reg : std_logic;

    component aes_fsm
        port (
            clk       : in  std_logic;
            rst_n     : in  std_logic;
            start     : in  std_logic;
            done      : out std_logic;
            round_idx : out std_logic_vector(3 downto 0);
            state_ld  : out std_logic;
            state_en  : out std_logic;
            key_ld    : out std_logic;
            first_rnd : out std_logic;
            final_rnd : out std_logic;
            ready     : out std_logic;
            error     : out std_logic
        );
    end component aes_fsm;

    component aes_datapath
        port (
            clk          : in  std_logic;
            rst_n        : in  std_logic;
            state_in     : in  std_logic_vector(127 downto 0);
            key_in       : in  std_logic_vector(127 downto 0);
            enc_dec      : in  std_logic;
            state_ld     : in  std_logic;
            key_ld       : in  std_logic;
            state_en     : in  std_logic;
            first_round  : in  std_logic;
            final_round  : in  std_logic;
            state_out    : out std_logic_vector(127 downto 0)
        );
    end component aes_datapath;

    component key_expansion
        port (
            key_in     : in  std_logic_vector(127 downto 0);
            round      : in  std_logic_vector(3 downto 0);
            enc_dec    : in  std_logic;
            key_out    : out std_logic_vector(127 downto 0)
        );
    end component key_expansion;

begin

    -- Instantiate FSM
    u_fsm : aes_fsm port map (
        clk       => clk,
        rst_n     => rst_n,
        start     => start,
        done      => fsm_done,
        round_idx => fsm_round,
        state_ld  => fsm_state_ld,
        state_en  => fsm_state_en,
        key_ld    => fsm_key_ld,
        first_rnd => fsm_first_rnd,
        final_rnd => fsm_final_rnd,
        ready     => fsm_ready,
        error     => fsm_error
    );

    -- Instantiate datapath
    u_datapath : aes_datapath port map (
        clk          => clk,
        rst_n        => rst_n,
        state_in     => data_reg,
        key_in       => expanded_key_comb,
        enc_dec      => enc_dec_reg,
        state_ld     => fsm_state_ld,
        key_ld       => fsm_key_ld,
        state_en     => fsm_state_en,
        first_round  => fsm_first_rnd,
        final_round  => fsm_final_rnd,
        state_out    => datapath_state_out
    );

    -- Instantiate key expansion
    u_key_exp : key_expansion port map (
        key_in     => key_reg,
        round      => fsm_round,
        enc_dec    => enc_dec_reg,
        key_out    => expanded_key_comb
    );

    -- Input register capture
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            data_reg <= (others => '0');
            key_reg <= (others => '0');
            enc_dec_reg <= '0';
        elsif rising_edge(clk) then
            -- Only capture inputs when DUT reports ready
            if start = '1' and fsm_ready = '1' then
                data_reg <= data_in;
                key_reg <= key_in;
                enc_dec_reg <= enc_dec;
                report "AES_TOP_CAPTURE: data_in=" & slv_to_hstring(data_in) &
                       " key_in=" & slv_to_hstring(key_in) &
                       " enc_dec=" & std_logic'image(enc_dec) severity note;
            end if;
        end if;
    end process;

    -- Output assignments
    data_out <= datapath_state_out;
    done <= fsm_done;
    ready <= fsm_ready;
    error <= fsm_error;

    process(datapath_state_out, fsm_done)
    begin
        if fsm_done = '1' then
            report "AES_TOP_OUTPUT: data_out=" & slv_to_hstring(datapath_state_out) severity note;
        end if;
    end process;

end architecture rtl;
