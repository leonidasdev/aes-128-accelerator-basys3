----------------------------------------------------------------------------------
-- Module Name:    tb_key_expansion
-- Project:        AES-128 Hardware Accelerator
-- Author:         PHR26-T03
-- Date:           29/04/2026
--
-- Description:
--   Unit testbench for key expansion module. Validates all 11 round keys from
--   master key against FIPS-197 standard vectors for both encryption and decryption modes.
--
--   Implementation: Combinational verification across all 11 rounds with assertion-based reporting.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_key_expansion is
end entity;

architecture sim of tb_key_expansion is
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

    signal key_in   : std_logic_vector(127 downto 0);
    signal round    : std_logic_vector(3 downto 0);
    signal enc_dec  : std_logic;
    signal key_out  : std_logic_vector(127 downto 0);

    type t_keys is array (0 to 10) of std_logic_vector(127 downto 0);
    constant FWD : t_keys := (
        x"2b7e151628aed2a6abf7158809cf4f3c",
        x"a0fafe1788542cb123a339392a6c7605",
        x"f2c295f27a96b9435935807a7359f67f",
        x"3d80477d4716fe3e1e237e446d7a883b",
        x"ef44a541a8525b7fb671253bdb0bad00",
        x"d4d1c6f87c839d87caf2b8bc11f915bc",
        x"6d88a37a110b3efddbf98641ca0093fd",
        x"4e54f70e5f5fc9f384a64fb24ea6dc4f",
        x"ead27321b58dbad2312bf5607f8d292f",
        x"ac7766f319fadc2128d12941575c006e",
        x"d014f9a8c9ee2589e13f0cc8b6630ca6"
    );

    constant INV : t_keys := (
        x"d014f9a8c9ee2589e13f0cc8b6630ca6",
        x"ac7766f319fadc2128d12941575c006e",
        x"ead27321b58dbad2312bf5607f8d292f",
        x"4e54f70e5f5fc9f384a64fb24ea6dc4f",
        x"6d88a37a110b3efddbf98641ca0093fd",
        x"d4d1c6f87c839d87caf2b8bc11f915bc",
        x"ef44a541a8525b7fb671253bdb0bad00",
        x"3d80477d4716fe3e1e237e446d7a883b",
        x"f2c295f27a96b9435935807a7359f67f",
        x"a0fafe1788542cb123a339392a6c7605",
        x"2b7e151628aed2a6abf7158809cf4f3c"
    );
begin
    uut: entity work.key_expansion port map(key_in, round, enc_dec, key_out);

    process
        variable pass, fail : integer := 0;
    begin
        report "==============================" & character'val(10) &
               "Starting key_expansion testbench" & character'val(10) &
               "==============================" severity note;

        key_in <= x"2b7e151628aed2a6abf7158809cf4f3c";

        -- Encryption
        enc_dec <= '1';
        for r in 0 to 10 loop
            round <= std_logic_vector(to_unsigned(r, 4));
            wait for 1 ns;
            if key_out = FWD(r) then
                pass := pass + 1;
                report "Test " & integer'image(r+1) & " (encryption round " & integer'image(r) & "): PASS" severity note;
            else
                fail := fail + 1;
                report "Test " & integer'image(r+1) & " (encryption round " & integer'image(r) & "): FAIL" & character'val(10) &
                       "  Expected: " & slv_to_hstring(FWD(r)) & character'val(10) &
                       "  Got:      " & slv_to_hstring(key_out) severity warning;
            end if;
            wait for 50 ns;
        end loop;

        -- Decryption
        enc_dec <= '0';
        for r in 0 to 10 loop
            round <= std_logic_vector(to_unsigned(r, 4));
            wait for 1 ns;
            if key_out = INV(r) then
                pass := pass + 1;
                report "Test " & integer'image(12+r) & " (decryption round " & integer'image(r) & "): PASS" severity note;
            else
                fail := fail + 1;
                report "Test " & integer'image(12+r) & " (decryption round " & integer'image(r) & "): FAIL" & character'val(10) &
                       "  Expected: " & slv_to_hstring(INV(r)) & character'val(10) &
                       "  Got:      " & slv_to_hstring(key_out) severity warning;
            end if;
            wait for 50 ns;
        end loop;

        report "==============================" & character'val(10) &
               "FINAL REPORT" & character'val(10) &
               "PASS: " & integer'image(pass) & character'val(10) &
               "FAIL: " & integer'image(fail) & character'val(10) &
               "==============================" severity note;
        wait;
    end process;
end architecture;