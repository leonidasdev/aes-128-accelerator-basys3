----------------------------------------------------------------------------------
-- Module Name:    aes_datapath
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           29/04/2026
--
-- Description:
--   Main data processing element integrating state register, round key register,
--   and all transformation modules (SubBytes, ShiftRows, MixColumns, AddRoundKey).
--   Supports both encryption and decryption paths via control multiplexers.
--
--   Implementation: Pipelined datapath with byte-reversal adapters for state alignment.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity aes_datapath is
    port (
        clk          : in  std_logic;
        rst_n        : in  std_logic;
        state_in     : in  std_logic_vector(127 downto 0);
        key_in       : in  std_logic_vector(127 downto 0);
        enc_dec      : in  std_logic;                   -- 1 = encrypt, 0 = decrypt
        state_ld     : in  std_logic;                   -- state load enable
        key_ld       : in  std_logic;                   -- key load enable
        state_en     : in  std_logic;                   -- state update enable
        first_round  : in  std_logic;                   -- apply AddRoundKey only (initial)
        final_round  : in  std_logic;                   -- skip MixColumns (last round)
        state_out    : out std_logic_vector(127 downto 0)
    );
end entity aes_datapath;

architecture rtl of aes_datapath is

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

    -- Reverse byte order across a 128-bit state.
    -- Byte i in the output comes from byte (15 - i) in the input.
    function reverse_state_bytes(state : std_logic_vector(127 downto 0)) return std_logic_vector is
        variable result : std_logic_vector(127 downto 0);
    begin
        for i in 0 to 15 loop
            result(i * 8 + 7 downto i * 8) := state((15 - i) * 8 + 7 downto (15 - i) * 8);
        end loop;
        return result;
    end function;

    -- Internal state and key registers
    signal state_reg    : std_logic_vector(127 downto 0);
    signal key_reg      : std_logic_vector(127 downto 0);
    -- Transformation outputs
    signal sub_bytes_out   : std_logic_vector(127 downto 0);
    signal inv_subbytes_out : std_logic_vector(127 downto 0);
    signal shift_rows_out   : std_logic_vector(127 downto 0);
    signal inv_shift_rows_out : std_logic_vector(127 downto 0);
    signal mix_cols_out    : std_logic_vector(127 downto 0);
    signal inv_mix_cols_out : std_logic_vector(127 downto 0);
    signal shift_rows_raw_out : std_logic_vector(127 downto 0);
    signal inv_shift_rows_raw_out : std_logic_vector(127 downto 0);
    signal mix_cols_raw_out : std_logic_vector(127 downto 0);
    signal inv_mix_cols_raw_out : std_logic_vector(127 downto 0);
    signal add_key_out     : std_logic_vector(127 downto 0);
    signal inv_addkey_pre_mix : std_logic_vector(127 downto 0);

    -- Forward and inverse round paths
    signal forward_round_path : std_logic_vector(127 downto 0);
    signal inverse_round_path : std_logic_vector(127 downto 0);
    signal forward_final_path : std_logic_vector(127 downto 0);
    signal inverse_final_path : std_logic_vector(127 downto 0);
    signal next_state : std_logic_vector(127 downto 0);

    component sub_bytes
        port (
            state_in  : in  std_logic_vector(127 downto 0);
            state_out : out std_logic_vector(127 downto 0)
        );
    end component sub_bytes;

    component inv_sub_bytes
        port (
            state_in  : in  std_logic_vector(127 downto 0);
            state_out : out std_logic_vector(127 downto 0)
        );
    end component inv_sub_bytes;

    component shift_rows
        port (
            state_in  : in  std_logic_vector(127 downto 0);
            state_out : out std_logic_vector(127 downto 0)
        );
    end component shift_rows;

    component inv_shift_rows
        port (
            state_in  : in  std_logic_vector(127 downto 0);
            state_out : out std_logic_vector(127 downto 0)
        );
    end component inv_shift_rows;

    component mix_columns
        port (
            state_in  : in  std_logic_vector(127 downto 0);
            state_out : out std_logic_vector(127 downto 0)
        );
    end component mix_columns;

    component inv_mix_columns
        port (
            state_in  : in  std_logic_vector(127 downto 0);
            state_out : out std_logic_vector(127 downto 0)
        );
    end component inv_mix_columns;

    component add_round_key
        port (
            state_in  : in  std_logic_vector(127 downto 0);
            key_in    : in  std_logic_vector(127 downto 0);
            state_out : out std_logic_vector(127 downto 0)
        );
    end component add_round_key;

begin

    -- Instantiate transformation modules
    u_sub_bytes : sub_bytes port map (state_reg, sub_bytes_out);
    -- Decrypt ordering uses InvShiftRows first, then InvSubBytes.
    u_inv_sub_bytes : inv_sub_bytes port map (inv_shift_rows_out, inv_subbytes_out);
    -- Byte-order adapters are applied at datapath integration boundaries so top-level
    -- AES behavior matches FIPS vectors without changing leaf-module unit-test contracts.
    u_shift_rows : shift_rows port map (reverse_state_bytes(sub_bytes_out), shift_rows_raw_out);
    shift_rows_out <= reverse_state_bytes(shift_rows_raw_out);

    u_inv_shift_rows : inv_shift_rows port map (reverse_state_bytes(state_reg), inv_shift_rows_raw_out);
    inv_shift_rows_out <= reverse_state_bytes(inv_shift_rows_raw_out);

    u_mix_columns : mix_columns port map (reverse_state_bytes(shift_rows_out), mix_cols_raw_out);
    mix_cols_out <= reverse_state_bytes(mix_cols_raw_out);

    u_inv_mix_columns : inv_mix_columns port map (reverse_state_bytes(inv_addkey_pre_mix), inv_mix_cols_raw_out);
    inv_mix_cols_out <= reverse_state_bytes(inv_mix_cols_raw_out);
    -- Use current round key directly so AddRoundKey uses the right key each cycle.
    u_add_round_key : add_round_key port map (state_reg, key_in, add_key_out);

    -- Forward round path (normal encryption round): SubBytes -> ShiftRows -> MixColumns
    process(state_reg, key_in, sub_bytes_out, shift_rows_out, mix_cols_out)
        variable temp1, temp2, temp3 : std_logic_vector(127 downto 0);
    begin
        -- temp1 already has SubBytes output
        temp1 := sub_bytes_out;
        -- temp2 = ShiftRows(SubBytes)
        temp2 := shift_rows_out;
        -- temp3 = MixColumns(ShiftRows(SubBytes))
        temp3 := mix_cols_out;
        -- Apply AddRoundKey
        forward_round_path <= temp3 xor key_in;
    end process;

    -- Forward final round (skip MixColumns): SubBytes -> ShiftRows -> AddRoundKey
    process(state_reg, key_in, sub_bytes_out, shift_rows_out)
    begin
        forward_final_path <= shift_rows_out xor key_in;
    end process;

    -- Inverse round path (decryption round): InvShiftRows -> InvSubBytes -> AddRoundKey -> InvMixColumns
    -- The inv_addkey_pre_mix gets the result of XOR (AddRoundKey after InvSubBytes)
    -- Then InvMixColumns is applied to that XOR result
    process(inv_subbytes_out, key_in, inv_mix_cols_out)
    begin
        inv_addkey_pre_mix <= inv_subbytes_out xor key_in;
        inverse_round_path <= inv_mix_cols_out;  -- Output of InvMixColumns applied to AddRoundKey result
    end process;

    -- Inverse final round (skip InvMixColumns): InvShiftRows -> InvSubBytes -> AddRoundKey (no InvMixColumns)
    -- Simply perform InvSubBytes then AddRoundKey without InvMixColumns
    process(inv_subbytes_out, key_in)
    begin
        inverse_final_path <= inv_subbytes_out xor key_in;
    end process;

    -- Select between forward, inverse, or load operations
    process(enc_dec, state_en, first_round, final_round, forward_round_path, forward_final_path,
            inverse_round_path, inverse_final_path, state_ld, state_in,
            state_reg, add_key_out)
    begin
        if state_ld = '1' then
            next_state <= state_in;
        elsif state_en = '1' then
            if first_round = '1' then
                -- Initial AddRoundKey only (uses current state_reg and key_in)
                next_state <= add_key_out;
            elsif final_round = '1' then
                -- Final round (no MixColumns)
                if enc_dec = '1' then
                    next_state <= forward_final_path;
                else
                    next_state <= inverse_final_path;
                end if;
            else
                -- Normal round (with MixColumns / InvMixColumns)
                -- Use the output of the current round computation pipeline
                if enc_dec = '1' then
                    next_state <= forward_round_path;
                else
                    next_state <= inverse_round_path;
                end if;
            end if;
        else
            next_state <= state_reg;
        end if;
    end process;

    -- Sequential logic for state and key registers
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state_reg <= (others => '0');
            key_reg <= (others => '0');
        elsif rising_edge(clk) then
            if state_ld = '1' then
                state_reg <= state_in;
                  report "DATAPATH_LOAD: state_in=" & slv_to_hstring(state_in) severity note;
            elsif state_en = '1' then
                state_reg <= next_state;
                  report "DATAPATH_UPDATE: first=" & std_logic'image(first_round) & 
                      " final=" & std_logic'image(final_round) & 
                      " enc_dec=" & std_logic'image(enc_dec) &
                      " next_state=" & slv_to_hstring(next_state) &
                      " state_reg=" & slv_to_hstring(state_reg) severity note;
            end if;
            if key_ld = '1' then
                key_reg <= key_in;
            end if;
        end if;
    end process;

    state_out <= state_reg;

end architecture rtl;
