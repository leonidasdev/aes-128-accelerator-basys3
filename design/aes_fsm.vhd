----------------------------------------------------------------------------------
-- Module Name:    aes_fsm
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           29/04/2026
--
-- Description:
--   Sequences AES operations (IDLE → LOAD → ROUND_0..9 → FINAL_ROUND → OUTPUT).
--   Generates control signals for datapath and key scheduling.
--   Moore machine with registered outputs and synchronous transitions.
--
--   Implementation: 11 clocked states, control logic for 10 rounds plus initialization.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity aes_fsm is
    port (
        clk       : in  std_logic;
        rst_n     : in  std_logic;
        start     : in  std_logic;
        done      : out std_logic;
        round_idx : out std_logic_vector(3 downto 0);  -- current round (0..10)
        state_ld  : out std_logic;
        state_en  : out std_logic;
        key_ld    : out std_logic;
        first_rnd : out std_logic;      -- initial AddRoundKey only
        final_rnd : out std_logic;      -- skip MixColumns
        ready     : out std_logic;      -- 1 when idle and ready to accept start
        error     : out std_logic       -- 1 when watchdog or other error
    );
end entity aes_fsm;

architecture rtl of aes_fsm is

    type t_state is (ST_IDLE, ST_LOAD, ST_ADD_ROUND_0, ST_ROUND, ST_FINAL_ROUND, ST_OUTPUT, ST_ERROR);

    function state_to_string(s : t_state) return string is
    begin
        case s is
            when ST_IDLE => return "ST_IDLE";
            when ST_LOAD => return "ST_LOAD";
            when ST_ADD_ROUND_0 => return "ST_ADD_ROUND_0";
            when ST_ROUND => return "ST_ROUND";
            when ST_FINAL_ROUND => return "ST_FINAL_ROUND";
            when ST_OUTPUT => return "ST_OUTPUT";
            when others => return "ST_ERROR";
        end case;
    end function;

    signal current_state, next_state : t_state;
    signal round_counter, next_round_counter : integer range 0 to 10 := 0;
    signal watchdog_count : integer := 0;
    constant WATCHDOG_MAX : integer := 500; -- max cycles allowed for operation
    signal next_watchdog_count : integer := 0;
    signal internal_error : std_logic := '0';

begin

    -- Combinational next-state logic
    process(current_state, start, round_counter, watchdog_count)
    begin
        next_state <= current_state;
        next_round_counter <= round_counter;
        next_watchdog_count <= watchdog_count;

        case current_state is
            when ST_IDLE =>
                if start = '1' then
                    next_state <= ST_LOAD;
                    next_round_counter <= 0;
                    next_watchdog_count <= 0;
                end if;

            when ST_LOAD =>
                -- Load the plaintext/ciphertext state.
                next_state <= ST_ADD_ROUND_0;
                next_round_counter <= 0;
                next_watchdog_count <= 0;

            when ST_ADD_ROUND_0 =>
                -- Initial AddRoundKey only.
                next_state <= ST_ROUND;
                next_round_counter <= 1;
                next_watchdog_count <= 0;

            when ST_ROUND =>
                -- Normal rounds (1..9)
                if round_counter = 9 then
                    next_state <= ST_FINAL_ROUND;
                    next_round_counter <= 10;
                else
                    next_round_counter <= round_counter + 1;
                end if;
                -- increment watchdog while in rounds
                next_watchdog_count <= watchdog_count + 1;

            when ST_FINAL_ROUND =>
                -- Final round
                next_state <= ST_OUTPUT;
                next_round_counter <= 10;  -- round 10 (final)
                next_watchdog_count <= watchdog_count + 1;

            when ST_OUTPUT =>
                -- Result is ready, wait for next start or timeout
                if start = '0' then
                    next_state <= ST_IDLE;
                end if;
                next_watchdog_count <= 0;

            when others =>
                -- ST_ERROR
                next_state <= ST_ERROR;
        end case;
    end process;

    -- Sequential state update
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            current_state <= ST_IDLE;
            round_counter <= 0;
            watchdog_count <= 0;
            internal_error <= '0';
        elsif rising_edge(clk) then
            current_state <= next_state;
            round_counter <= next_round_counter;
            watchdog_count <= next_watchdog_count;

            if current_state /= ST_IDLE or start = '1' then
            end if;

            -- Watchdog: if exceeded while not idle, go to error
            if next_watchdog_count > WATCHDOG_MAX then
                current_state <= ST_ERROR;
                internal_error <= '1';
            end if;
        end if;
    end process;

    -- Output logic (Moore machine)
    process(current_state, round_counter)
    begin
        -- Default assignments
        done <= '0';
        state_ld <= '0';
        state_en <= '0';
        key_ld <= '0';
        first_rnd <= '0';
        final_rnd <= '0';
        round_idx <= std_logic_vector(to_unsigned(0, 4));
        ready <= '0';
        error <= '0';
        case current_state is
            when ST_IDLE =>
                done <= '0';
                ready <= '1';

            when ST_LOAD =>
                state_ld <= '1';
                round_idx <= std_logic_vector(to_unsigned(0, 4));

            when ST_ADD_ROUND_0 =>
                state_en <= '1';  -- Apply initial AddRoundKey
                first_rnd <= '1';
                round_idx <= std_logic_vector(to_unsigned(0, 4));

            when ST_ROUND =>
                state_en <= '1';  -- Update state
                final_rnd <= '0';
                round_idx <= std_logic_vector(to_unsigned(round_counter, 4));

            when ST_FINAL_ROUND =>
                state_en <= '1';  -- Update state
                final_rnd <= '1';
                round_idx <= std_logic_vector(to_unsigned(10, 4));  -- round 10

            when ST_OUTPUT =>
                done <= '1';
                round_idx <= std_logic_vector(to_unsigned(10, 4));
                ready <= '0';

            when ST_ERROR =>
                -- Error state does nothing
                error <= '1';
                done <= '0';
                ready <= '0';
        end case;
    end process;

end architecture rtl;
