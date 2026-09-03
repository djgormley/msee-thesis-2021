------------------------------------------------------------------------------------------------------
--! @Author:         Anthony A. Stock, intern, NASA GRC/LCI
--! @Creation-Date:  15 October 2020
--! @Module-Name:    GenericFir testbench
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.2.1
--! @Git-Tag:        xxxx
--!
--! Revision 0.01 - Anthony A. Stock -- file created
------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;
use work.GenericFir_pkg.all;

--! @Module-Description
--! Testbench for GenericFir module.

entity Fir_tb is
end Fir_tb;

architecture Behavioral of Fir_tb is

  ------------------------------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------------------------------
  component GenericFIR
    generic (
      TAP_COUNT	       : in integer := 17;
      TAP_WIDTH        : in integer := 32;
      BIT_WIDTH        : in integer := 32
    );
    port (
      -- Module inputs
      Clock          : in  std_logic;                          --! Global clock.
      Reset          : in  std_logic;                          --! Asynchronous reset.
      IncomingSample : in  signed(BIT_WIDTH-1 downto 0);       --! Two's complement sample
      SampleInValid  : in  std_logic;                          --! Input being driven into multiplier is ready to be read
      SampleInLast   : in  std_logic;                          --! marker to delineate two back-to-back sequences of inputs
      SampleOutReady : in  std_logic;                          --! is following module ready to accept input
      Coeffs         : in  CoeffArray(TAP_COUNT-1 downto 0);   --! Each of the coefficients are two's complement.
      -- Module outputs
      OutgoingSample : out signed(BIT_WIDTH-1 downto 0);       --! Two's complement sample
      SampleOutValid : out std_logic;                          --! Data on output is valid
      SampleOutLast  : out std_logic;                          --! marker to delineate two back-to-back sequences of inputs
      SampleInReady  : out std_logic                           --! tell preceding module that we're ready for input
  );
  end component;

------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------
constant ClockPeriod          : time    := 10 ns; -- 100MHz
constant TAP_COUNT            : integer := 17;
constant TAP_WIDTH            : integer := 32;
constant BIT_WIDTH            : integer := 32;
constant tapFilename          : string := "../../../../../test/h_in.txt";
constant inputFilename        : string := "../../../../../test/i_in.txt";
constant outputFilename       : string := "../../../../../test/i_out.txt";

------------------------------------------------------------------------------------------------------
-- Signals
------------------------------------------------------------------------------------------------------
signal Clock                        :  std_logic                          := '0';
signal Reset                        :  std_logic                          := '1';
signal Coeffs                       :  CoeffArray(TAP_COUNT - 1 downto 0) := (others => (others =>'0'));

-- data in
signal SampleInValid                :  std_logic           := '0';
signal SampleInLast                 :  std_logic           := '0';
signal SampleOutReady               :  std_logic           := '0';
signal IncomingSample               :  signed(BIT_WIDTH - 1 downto 0) := (others => '0'); -- s4.27                     --ANTHONY: 64->32

-- data out
signal SampleOutValid               :  std_logic           := '0';
signal SampleOutLast                :  std_logic           := '0';
signal SampleInReady                :  std_logic           := '0';
signal OutgoingSample               :  signed(BIT_WIDTH - 1 downto 0) := (others => '0'); -- s4.27                     --ANTHONY: 64->32


begin

  --
  -- Unit Under Test
  --
  uut : GenericFIR
  generic map (
    TAP_COUNT             => TAP_COUNT,
    TAP_WIDTH             => TAP_WIDTH,
    BIT_WIDTH             => BIT_WIDTH
  )
  port map (
    Clock                 => Clock,
    Reset                 => Reset,
    SampleInValid         => SampleInValid,
    SampleInLast          => SampleInLast,
    SampleOutReady        => SampleOutReady,
    Coeffs                => Coeffs,
    IncomingSample        => IncomingSample,
    OutgoingSample        => OutgoingSample,
    SampleOutValid        => SampleOutValid,
    SampleOutLast         => SampleOutLast,
    SampleInReady         => SampleInReady
  );

  --
  -- clock
  --
  clock_gen : process
      begin
      wait for ClockPeriod/2;
      Clock <= not Clock;
  end process clock_gen;

  --
  -- stimulus
  --
  stimuli : process

  -- Local variables
  file     CoeffFileIn      : text;
  variable CoeffFileLine    : line;
  variable CoeffLineValue   : integer;
  file     IFileIn          : text;
  variable IFileLine        : line;
  variable ILineValue       : integer;


  begin
    wait until rising_edge(Clock);
    Reset <= '0';

    --
    -- load coefficients
    --

    -- Load a new filter coefficient
    file_open(CoeffFileIn, tapFilename, read_mode);

    for Tap in 0 to TAP_COUNT-1 loop
      wait until rising_edge(Clock);

      -- load coefficient samples
      readline(CoeffFileIn, CoeffFileLine);
      read(CoeffFileLine, CoeffLineValue);

      Coeffs(Tap) <= to_signed(CoeffLineValue, Coeffs(Tap)'length);

    end loop;

    wait until rising_edge(Clock);
    file_close(CoeffFileIn);

    --
    -- load data samples
    --
    file_open(IFileIn, inputFilename, read_mode);

    -- read in data from input files
    while not endfile(IFileIn) loop
      wait until rising_edge(Clock);

      readline(IFileIn, IFileLine);
      read(IFileLine, ILineValue);

      SampleInValid <= '1';

      -- UUT stimulus
      IncomingSample      <= to_signed(ILineValue, IncomingSample'length);
    end loop;

    -- last sample marker
    SampleInLast  <= '1';
    wait until rising_edge(Clock);
    SampleInLast  <= '0';

    -- input no longer valid
    SampleInValid   <= '0';
    IncomingSample  <= (others => '0');

    -- test SampleOutReady timing
    wait until rising_edge(Clock);
    SampleOutReady <= '1';
    wait until rising_edge(Clock);
    SampleOutReady <= '0';

    file_close(IFileIn);

    report "stimulus finished";
    wait;

  end process stimuli;


  --
  -- Ouput Results
  --
  results : process
  file     SampleIFileOut            : text;
  variable SampleIFileLine           : line;
  variable SampleILineValue          : integer;

  begin

    file_open(SampleIFileOut,        outputFilename, write_mode);

    -- trigger
    loop
      wait until rising_edge(Clock);
      exit when SampleOutValid = '1';
    end loop;

    loop
      -- write output to files
      write(SampleIFileLine,       integer'image(to_integer(OutgoingSample)));
      writeline(SampleIFileOut,    SampleIFileLine);

      wait until rising_edge(Clock);
      exit when SampleOutValid = '0';
    end loop;

    -- close file out
    file_close(SampleIFileOut);

    report "write finished";

    wait for 5*ClockPeriod;
    assert false report "test done" severity failure;
    wait;
  end process;

end Behavioral;
