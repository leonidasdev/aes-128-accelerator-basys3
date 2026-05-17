----------------------------------------------------------------------------------
-- Module Name:    tb_aes_datapath
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           17/05/2026
--
-- Description:
--   Unit testbench for the AES datapath. Verifies state/key load, initial
--   AddRoundKey behavior (first round), and register hold when enables are
--   inactive. Self-checking with report summaries.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_aes_datapath is
end entity tb_aes_datapath;

architecture sim of tb_aes_datapath is

    function slv_to_hstring(v : std_logic_vector) return string is
        variable res : string(1 to v'length/4);
        variable nib : std_logic_vector(3 downto 0);
    begin
        for i in 0 to res'length-1 loop
            nib := v(v'left - i*4 downto v'left - i*4 - 3);
            case to_integer(unsigned(nib)) is
                when 0 => res(i+1):='0'; when 1 => res(i+1):='1';
                when 2 => res(i+1):='2'; when 3 => res(i+1):='3';
                when 4 => res(i+1):='4'; when 5 => res(i+1):='5';
                when 6 => res(i+1):='6'; when 7 => res(i+1):='7';
                when 8 => res(i+1):='8'; when 9 => res(i+1):='9';
                when 10 => res(i+1):='A'; when 11 => res(i+1):='B';
                when 12 => res(i+1):='C'; when 13 => res(i+1):='D';
                when 14 => res(i+1):='E'; when others => res(i+1):='F';
            end case;
        end loop;
        return res;
    end function;

    function sl_to_string(sl : std_logic) return string is
    begin
        if sl = '1' then
            return "1";
        else
            return "0";
        end if;
    end function;

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
    end component;

    signal clk         : std_logic := '0';
    signal rst_n       : std_logic := '0';
    signal state_in    : std_logic_vector(127 downto 0) := (others => '0');
    signal key_in      : std_logic_vector(127 downto 0) := (others => '0');
    signal enc_dec     : std_logic := '1';
    signal state_ld    : std_logic := '0';
    signal key_ld      : std_logic := '0';
    signal state_en    : std_logic := '0';
    signal first_round : std_logic := '0';
    signal final_round : std_logic := '0';
    signal state_out   : std_logic_vector(127 downto 0);

    constant CLK_PERIOD : time := 10 ns;

begin

    u_dut : aes_datapath
        port map (
            clk => clk,
            rst_n => rst_n,
            state_in => state_in,
            key_in => key_in,
            enc_dec => enc_dec,
            state_ld => state_ld,
            key_ld => key_ld,
            state_en => state_en,
            first_round => first_round,
            final_round => final_round,
            state_out => state_out
        );

    clk <= not clk after CLK_PERIOD / 2;

    stim_proc : process
        variable pass_cnt : integer := 0;
        variable fail_cnt : integer := 0;
        variable test_num : integer := 0;
        variable expected  : std_logic_vector(127 downto 0);
    begin
        report "==============================" & character'val(10) &
               "Starting tb_aes_datapath" & character'val(10) &
               "==============================" severity note;

        -- Reset
        rst_n <= '0';
        state_ld <= '0'; key_ld <= '0'; state_en <= '0'; first_round <= '0'; final_round <= '0';
        wait for 100 ns;
        rst_n <= '1';
        wait for CLK_PERIOD * 2;

        -- TEST 1: State and Key Load
        test_num := test_num + 1;
        state_in <= x"00112233445566778899AABBCCDDEEFF";
        key_in   <= x"000102030405060708090A0B0C0D0E0F";
        state_ld <= '1';
        key_ld   <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;
        -- Deassert load after sampled edge
        state_ld <= '0';
        key_ld   <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;

        if state_out = x"00112233445566778899AABBCCDDEEFF" then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS - state loaded correctly" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL - state load mismatch" & character'val(10) &
                   "  Expected: " & slv_to_hstring(x"00112233445566778899AABBCCDDEEFF") & character'val(10) &
                   "  Got:      " & slv_to_hstring(state_out) severity warning;
        end if;

        -- TEST 2: First round (AddRoundKey) behavior
        test_num := test_num + 1;
        -- Ensure we keep the previously loaded key_in and state_in
        first_round <= '1';
        state_en <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;
        -- clear enables after sampling
        first_round <= '0';
        state_en <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;

        expected := x"00112233445566778899AABBCCDDEEFF" xor x"000102030405060708090A0B0C0D0E0F";
        if state_out = expected then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS - first round AddRoundKey applied" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL - AddRoundKey result mismatch" & character'val(10) &
                   "  Expected: " & slv_to_hstring(expected) & character'val(10) &
                   "  Got:      " & slv_to_hstring(state_out) severity warning;
        end if;

        -- TEST 3: Hold behavior when enables inactive
        test_num := test_num + 1;
        -- capture current value
        expected := state_out;
        -- toggle inputs (should not affect state when enables are 0)
        state_in <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";
        key_in <= x"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
        wait for CLK_PERIOD * 3;

        if state_out = expected then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS - state held when enables inactive" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL - state changed unexpectedly" & character'val(10) &
                   "  Expected hold: " & slv_to_hstring(expected) & character'val(10) &
                   "  Got:           " & slv_to_hstring(state_out) severity warning;
        end if;

        report "==============================" & character'val(10) &
               "FINAL REPORT" & character'val(10) &
               "PASS: " & integer'image(pass_cnt) & character'val(10) &
               "FAIL: " & integer'image(fail_cnt) & character'val(10) &
               "==============================" severity note;

        wait;
    end process;

end architecture sim;
