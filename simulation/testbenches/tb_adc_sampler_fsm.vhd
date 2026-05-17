----------------------------------------------------------------------------------
-- Module Name:    tb_adc_sampler_fsm
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           17/05/2026
--
-- Description:
--   Unit testbench for the ADC sampler FSM. Validates periodic sampling, manual
--   trigger behavior, XADC request/response timing, plaintext padding, AES start
--   handshake, and result buffering.
--
--   Implementation: Behavioral XADC and AES stubs plus self-checking assertions.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_adc_sampler_fsm is
end entity tb_adc_sampler_fsm;

architecture sim of tb_adc_sampler_fsm is

    function slv_to_hstring(value : std_logic_vector) return string is
        variable result : string(1 to value'length / 4);
        variable nibble : std_logic_vector(3 downto 0);
        variable start_idx : integer;
    begin
        for i in 0 to result'length - 1 loop
            if value'ascending then
                start_idx := value'left + i * 4;
                nibble := value(start_idx to start_idx + 3);
            else
                start_idx := value'left - i * 4;
                nibble := value(start_idx downto start_idx - 3);
            end if;
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

    component adc_sampler_fsm
        generic (
            TIMER_MAX_CYCLES : integer := 500000000
        );
        port (
            clk           : in  std_logic;
            rst_n         : in  std_logic;
            manual_trigger : in  std_logic;
            xadc_valid    : in  std_logic;
            xadc_data     : in  std_logic_vector(15 downto 0);
            xadc_ready    : out std_logic;
            aes_start     : out std_logic;
            aes_done      : in  std_logic;
            aes_key       : in  std_logic_vector(127 downto 0);
            aes_data      : out std_logic_vector(127 downto 0);
            aes_out       : in  std_logic_vector(127 downto 0);
            result_ready  : out std_logic;
            encrypted     : out std_logic_vector(127 downto 0);
            adc_raw       : out std_logic_vector(11 downto 0);
            sample_count  : out std_logic_vector(31 downto 0)
        );
    end component adc_sampler_fsm;

    signal clk            : std_logic := '0';
    signal rst_n          : std_logic := '0';
    signal manual_trigger : std_logic := '0';
    signal xadc_valid     : std_logic := '0';
    signal xadc_data      : std_logic_vector(15 downto 0) := (others => '0');
    signal xadc_ready     : std_logic;
    signal aes_start      : std_logic;
    signal aes_done       : std_logic := '0';
    signal aes_data       : std_logic_vector(127 downto 0);
    signal aes_out        : std_logic_vector(127 downto 0) := (others => '0');
    signal result_ready   : std_logic;
    signal encrypted      : std_logic_vector(127 downto 0);
    signal adc_raw        : std_logic_vector(11 downto 0);
    signal sample_count   : std_logic_vector(31 downto 0);

    signal cycle_count        : integer := 0;
    signal prev_xadc_ready    : std_logic := '0';
    signal prev_aes_start     : std_logic := '0';
    signal xadc_request_cycle : integer := -1000;
    signal aes_request_cycle  : integer := -1000;
    signal xadc_mock_value    : std_logic_vector(11 downto 0) := x"123";

    constant CLK_PERIOD : time := 10 ns;
    constant AES_MASK   : std_logic_vector(127 downto 0) := x"0000000000000000000000000000AAAA";

begin

    u_dut : adc_sampler_fsm
        generic map (
            TIMER_MAX_CYCLES => 20
        )
        port map (
            clk           => clk,
            rst_n         => rst_n,
            manual_trigger => manual_trigger,
            xadc_valid    => xadc_valid,
            xadc_data     => xadc_data,
            xadc_ready    => xadc_ready,
            aes_start     => aes_start,
            aes_done      => aes_done,
            aes_key       => x"000102030405060708090A0B0C0D0E0F",
            aes_data      => aes_data,
            aes_out       => aes_out,
            result_ready  => result_ready,
            encrypted     => encrypted,
            adc_raw       => adc_raw,
            sample_count  => sample_count
        );

    clk <= not clk after CLK_PERIOD / 2;

    cycle_counter : process(clk)
    begin
        if rising_edge(clk) then
            cycle_count <= cycle_count + 1;

            if xadc_ready = '1' and prev_xadc_ready = '0' then
                xadc_request_cycle <= cycle_count;
                xadc_mock_value <= std_logic_vector(unsigned(xadc_mock_value) + 1);
                report "[XADC] Read requested at cycle " & integer'image(cycle_count) severity note;
            end if;

            if aes_start = '1' and prev_aes_start = '0' then
                aes_request_cycle <= cycle_count;
                report "[AES] Start observed at cycle " & integer'image(cycle_count) severity note;
            end if;

            prev_xadc_ready <= xadc_ready;
            prev_aes_start <= aes_start;
        end if;
    end process;

    xadc_model : process(clk)
    begin
        if rising_edge(clk) then
            if cycle_count = xadc_request_cycle + 2 then
                xadc_data <= (15 downto 12 => '0') & xadc_mock_value;
                xadc_valid <= '1';
                report "[XADC] Data valid, ADC = 0x" & slv_to_hstring(xadc_mock_value) severity note;
            else
                xadc_valid <= '0';
            end if;
        end if;
    end process;

    aes_model : process(clk)
    begin
        if rising_edge(clk) then
            if cycle_count = aes_request_cycle + 3 then
                aes_out <= aes_data xor AES_MASK;
                aes_done <= '1';
                report "[AES] Done asserted, output = 0x" & slv_to_hstring(aes_data xor AES_MASK) severity note;
            else
                aes_done <= '0';
            end if;
        end if;
    end process;

    stim_proc : process
        variable pass_cnt : integer := 0;
        variable fail_cnt : integer := 0;
        variable test_num : integer := 0;
        variable expected_plaintext : std_logic_vector(127 downto 0);
        variable expected_encrypted : std_logic_vector(127 downto 0);
    begin
        report "==============================" & character'val(10) &
            "Starting tb_adc_sampler_fsm" & character'val(10) &
            "==============================" severity note;

        rst_n <= '0';
        manual_trigger <= '0';
        wait for 50 ns;

        rst_n <= '1';
        wait for 30 ns;

        test_num := test_num + 1;
        if result_ready = '0' and sample_count = x"00000000" and adc_raw = x"000" then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS - reset clears sampler state" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL - reset state mismatch" severity warning;
        end if;

        test_num := test_num + 1;
        wait until result_ready = '1' for 10 us;
        if result_ready = '1' then
            expected_plaintext := (127 downto 12 => '0') & xadc_mock_value;
            expected_encrypted := expected_plaintext xor AES_MASK;

            wait for 1 ns;
            if adc_raw = xadc_mock_value and
               aes_data = expected_plaintext and
               encrypted = expected_encrypted and
               sample_count = x"00000001" then
                pass_cnt := pass_cnt + 1;
                report "Test " & integer'image(test_num) & ": PASS - automatic sample captured and encrypted" severity note;
            else
                fail_cnt := fail_cnt + 1;
                report "Test " & integer'image(test_num) & ": FAIL - automatic sample mismatch" severity warning;
                report "  ADC raw: 0x" & slv_to_hstring(adc_raw) severity warning;
                report "  AES data: 0x" & slv_to_hstring(aes_data) severity warning;
                report "  Encrypted: 0x" & slv_to_hstring(encrypted) severity warning;
            end if;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL - automatic sample timeout" severity warning;
        end if;

        wait for 200 ns;
        test_num := test_num + 1;
        manual_trigger <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        manual_trigger <= '0';

        wait until result_ready = '1' for 10 us;
        if result_ready = '1' then
            expected_plaintext := (127 downto 12 => '0') & xadc_mock_value;
            expected_encrypted := expected_plaintext xor AES_MASK;

            wait for 1 ns;
            if adc_raw = xadc_mock_value and
               aes_data = expected_plaintext and
               encrypted = expected_encrypted and
               sample_count = x"00000002" then
                pass_cnt := pass_cnt + 1;
                report "Test " & integer'image(test_num) & ": PASS - manual trigger captured second sample" severity note;
            else
                fail_cnt := fail_cnt + 1;
                report "Test " & integer'image(test_num) & ": FAIL - manual trigger mismatch" severity warning;
            end if;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL - manual trigger timeout" severity warning;
        end if;

        test_num := test_num + 1;
        if xadc_request_cycle >= 0 and aes_request_cycle >= 0 then
            pass_cnt := pass_cnt + 1;
            report "Test " & integer'image(test_num) & ": PASS - XADC and AES handshakes observed" severity note;
        else
            fail_cnt := fail_cnt + 1;
            report "Test " & integer'image(test_num) & ": FAIL - handshake observation missing" severity warning;
        end if;

        report "==============================" & character'val(10) &
            "FINAL REPORT" & character'val(10) &
            "PASS: " & integer'image(pass_cnt) & character'val(10) &
            "FAIL: " & integer'image(fail_cnt) & character'val(10) &
            "==============================" severity note;

        wait;
    end process;

end architecture sim;