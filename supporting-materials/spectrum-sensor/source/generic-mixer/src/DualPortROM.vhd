------------------------------------------------------------------------------------------------------
--! @Author:         Anthony A. Stock (NASA GRC/LCI0)[NIP]
--! @Creation-Date:  1 November 2020
--! @Module-Name:    Dual-Port ROM
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.2.1
--! @Git-Tag:        xxxx
--! 
--! @Version 1.0:
--! Anthony A. Stock (NASA GRC/LCI0)[NIP] - File created.
--!
--! @ToDo: Logic may be a bit overcomplicated (e.g decoding hex strings) and is prone to error due to
--! padding.  Ideally, we could generate the LUT on build, here using VHDL functions (e.g. fixed point,
--! complex...)
------------------------------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.math_real.all;

use std.textio.all;

--! @Module-Description
--! This module implements a ROM of custom height/width in FPGA RAM (not LUTs).
--! Contains functions to populate ROM from a file of hex numbers.
--! NOTE: Smaller coefficients in the coefficient file should be padded with leading zeros
--!       such that all coefficients are the same number of characters (e.g. use 0001
--!       instead of 1). For n-bit coefficients, set data_size = n-1 as the entries are
--!       assumed to be positive for the application that this module was created for; the
--!       sign bit '0' is prepended in parent module to save memory here.

entity dual_port_rom is
  generic (
    addr_size : in natural := 14;  --! 2**14 coefficients (effectively 2**16)
    data_size : in natural := 15   --! bit width
  );
  port (
    clock     : in  std_logic;                              --! system clock
    reset     : in  std_logic;
    address1  : in  std_logic_vector(addr_size-1 downto 0); --! i index
    address2  : in  std_logic_vector(addr_size-1 downto 0); --! q index
    dataout1  : out std_logic_vector(data_size-1 downto 0); --! i data
    dataout2  : out std_logic_vector(data_size-1 downto 0)  --! q data
  );
end entity dual_port_rom;

architecture behavioral of dual_port_rom is

  ------------------------------------------------------------------------------------------------------
  -- constants
  ------------------------------------------------------------------------------------------------------
  constant hexLen        : natural := natural(ceil(real(data_size) / real(4))); -- there are 4 bits per hex character
  constant coeffFileName : string  := "../coe/quarter_cos.coe";

  ------------------------------------------------------------------------------------------------------
  -- functions
  ------------------------------------------------------------------------------------------------------
  
  -- function to convert hex coefficients into slv's
  function to_slv (tmp_hexnum : string) return std_logic_vector is
    variable temp  : std_logic_vector((hexLen*4)-1 downto 0);
    variable digit : natural;

  begin
    for i in tmp_hexnum'range loop
      case tmp_hexnum(i) is
      when '0' to '9' => 
        digit := Character'pos(tmp_hexnum(i)) - Character'pos('0');
      when 'A' to 'F' => 
        digit := Character'pos(tmp_hexnum(i)) - Character'pos('A') + 10;
      when 'a' to 'f' =>
        digit := Character'pos(tmp_hexnum(i)) - Character'pos('a') + 10;
      when others => digit := 0;
      end case;
      temp((i-1)*4+3 downto (i-1)*4) := std_logic_vector(to_unsigned(digit, 4));
    end loop;
    return temp(data_size-1 downto 0);  -- if data_size is not a multiple of 4, ignore MSB's which will be zero.
  end function;

  type ram_type is array (0 to (2**addr_size)-1) of bit_vector(data_size-1 downto 0);
  
  -- initialize ROM with values from coefficient file
  impure function InitRamFromFile (RamFileName : in string) return ram_type is
    file     RamFile     : text is in RamFileName;
    variable RamFileLine : line;
    variable RAM         : ram_type;
    variable hexStr      : string(hexLen downto 1);
  begin
    for I in ram_type'range loop
      -- read coeffs from file
      readline(RamFile, RamFileLine);
      read(RamFileLine, hexStr);
      -- populate ROM(i)
      RAM(I) := to_bitvector(to_slv(hexStr));
    end loop;
    return RAM;
  end function;
  
  ------------------------------------------------------------------------------------------------------
  -- Signals / Attributes
  ------------------------------------------------------------------------------------------------------
  
  -- create ROM, using function to load coefficients - specify that we want it implemented in RAM, not LUTs.
  signal    ram              : ram_type := InitRamFromFile(coeffFileName);
  attribute rom_style        : string;
  attribute rom_style of ram : signal is "block";

begin
  
  -- synchonous read
  process(all)
  begin
    if rising_edge(Clock) then
      if Reset then 
        dataout1 <= (others => '0');
        dataout2 <= (others => '0');
      else
        dataout1 <= to_stdlogicvector(ram(to_integer(unsigned(address1))));
        dataout2 <= to_stdlogicvector(ram(to_integer(unsigned(address2))));
      end if;
    end if;
  
  end process;

end architecture Behavioral;
