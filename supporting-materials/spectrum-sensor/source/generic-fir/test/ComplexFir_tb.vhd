------------------------------------------------------------------------------------------------------
--! @Author:         Anthony A. Stock, intern, NASA GRC/LCI
--! @Creation-Date:  15 October 2020
--! @Module-Name:    ComplexFir testbench
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
--! Testbench for ComplexFir module.

entity ComplexFir_tb is
end ComplexFir_tb;

architecture Behavioral of ComplexFir_tb is

------------------------------------------------------------------------------------------------------
-- Components
------------------------------------------------------------------------------------------------------
component ComplexFir
generic (
  TAP_COUNT	      : in natural := 17;
  TAP_WIDTH       : in natural := 32;
  BIT_WIDTH       : in natural := 32;
  HIGH_OFFSET     : in natural := 1
);
port (
  -- Module inputs
  Clock            : in  std_logic;                            --! Global clock.
  Reset            : in  std_logic;                            --! Asynchronous reset.
  IncomingSample_I : in  signed(BIT_WIDTH - 1 downto 0);       --! Two's complement sample
  IncomingSample_Q : in  signed(BIT_WIDTH - 1 downto 0);       --! Two's complement sample
  SampleInValid    : in  std_logic;                            --! Input being driven into multiplier is ready to be read
  SampleInLast     : in  std_logic;                            --! marker to delineate two back-to-back sequences of inputs
  SampleOutReady   : in  std_logic;                            --! is following module ready to accept input
  Coeffs    	   : in  CoeffArray(TAP_COUNT - 1 downto 0);   --! Each of the coefficients are two's complement
  -- Module outputs
  OutgoingSample_I : out signed(BIT_WIDTH - 1 downto 0);       --! Two's complement sample
  OutgoingSample_Q : out signed(BIT_WIDTH - 1 downto 0);       --! Two's complement sample
  SampleOutValid   : out std_logic;                            --! Data on output is valid
  SampleOutLast    : out std_logic;                            --! marker to delineate two back-to-back sequences of inputs
  SampleInReady    : out std_logic                             --! tell preceding module that we're ready for input
);
end component;

------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------
constant ClockPeriod          : time    := 10 ns; -- 100MHz
constant TAP_COUNT            : natural := 17;
constant TAP_WIDTH            : natural := 32;
constant BIT_WIDTH            : natural := 32;
constant HIGH_OFFSET          : natural := 1;

constant tapFilename          : string := "../../../../../test/h_in.txt";
constant inputFilename_I      : string := "../../../../../test/i_in.txt";
constant inputFilename_Q      : string := "../../../../../test/q_in.txt";
constant outputFilename_I     : string := "../../../../../test/i_out.txt";
constant outputFilename_Q     : string := "../../../../../test/q_out.txt";

------------------------------------------------------------------------------------------------------
-- Input signals
------------------------------------------------------------------------------------------------------
signal Clock                        :  std_logic                          := '0';
signal Reset                        :  std_logic                          := '1';
signal Coeffs                       :  CoeffArray(TAP_COUNT - 1 downto 0) := (others => (others =>'0'));
signal SampleInValid                :  std_logic           := '0';
signal SampleInLast                 :  std_logic           := '0';
signal SampleOutReady               :  std_logic           := '0';
signal IncomingSample_I             :  signed(BIT_WIDTH - 1 downto 0) := (others => '0');
signal IncomingSample_Q             :  signed(BIT_WIDTH - 1 downto 0) := (others => '0');

------------------------------------------------------------------------------------------------------
-- Output signals
------------------------------------------------------------------------------------------------------
signal SampleOutValid               :  std_logic           := '0';
signal SampleOutLast                :  std_logic           := '0';
signal SampleInReady                :  std_logic           := '0';
signal OutgoingSample_I             :  signed(BIT_WIDTH - 1 downto 0) := (others => '0');
signal OutgoingSample_Q             :  signed(BIT_WIDTH - 1 downto 0) := (others => '0');


begin

  --
  -- Unit Under Test
  --
  uut : ComplexFir
  generic map (
    TAP_COUNT             => TAP_COUNT,
    TAP_WIDTH             => TAP_WIDTH,
    BIT_WIDTH             => BIT_WIDTH
  )
  port map (
    Clock                 => Clock,
    Reset                 => Reset,
    IncomingSample_I      => IncomingSample_I,
    IncomingSample_Q      => IncomingSample_Q,
    SampleInValid         => SampleInValid,
    SampleInLast          => SampleInLast,
    SampleOutReady        => SampleOutReady,
    Coeffs                => Coeffs,
    OutgoingSample_I      => OutgoingSample_I,
    OutgoingSample_Q      => OutgoingSample_Q,
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

  file     QFileIn          : text;
  variable QFileLine        : line;
  variable QLineValue       : integer;


  begin

    wait until rising_edge(Clock);
    Reset <= '0';

    -- Load a new filter coefficient set using the reload slave channel
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

    -- load data samples
    file_open(IFileIn, inputFilename_I, read_mode);
    file_open(QFileIn, inputFilename_Q, read_mode);

    while not (endfile(IFileIn) or endfile(QFileIn)) loop
      wait until rising_edge(Clock);

      -- read data from files
      readline(IFileIn, IFileLine);
      read(IFileLine, ILineValue);

      readline(QFileIn, QFileLine);
      read(QFileLine, QLineValue);

      -- uut stimulus
      SampleInValid <= '1';
      IncomingSample_I      <= to_signed(ILineValue, IncomingSample_I'length);
      IncomingSample_Q      <= to_signed(ILineValue, IncomingSample_Q'length);
    end loop;

    -- last sample.
    SampleInLast  <= '1';
    wait until rising_edge(Clock);
    SampleInLast  <= '0';

    -- done with stimulus.
    SampleInValid     <= '0';
    IncomingSample_I  <= (others => '0');
    IncomingSample_Q  <= (others => '0');

    -- test SampleOutReady timing.
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
  file     SampleQFileOut            : text;
  variable SampleQFileLine           : line;
  variable SampleQLineValue          : integer;

  begin

    -- open output files
    file_open(SampleIFileOut,        outputFilename_I, write_mode);
    file_open(SampleQFileOut,        outputFilename_Q, write_mode);

    -- trigger
    loop
      wait until rising_edge(Clock);
      exit when SampleOutValid = '1';
    end loop;

    -- write out samples to file
    loop
      write(SampleIFileLine,       integer'image(to_integer(OutgoingSample_I)));
      writeline(SampleIFileOut,    SampleIFileLine);

      write(SampleQFileLine,       integer'image(to_integer(OutgoingSample_Q)));
      writeline(SampleQFileOut,    SampleQFileLine);

      wait until rising_edge(Clock);

      exit when SampleOutValid = '0';
    end loop;

    -- close output files
    file_close(SampleIFileOut);
    file_close(SampleQFileOut);

    report "write finished";

    wait for 5*ClockPeriod;
    assert false report "test done" severity failure;
    wait;
  end process;

end Behavioral;
