------------------------------------------------------------------------------------------------------
--! @Author:         Anthony Stock (NASA GRC/LCI)
--! @Creation-Date:  9 November 2020
--! @Module-Name:    Generic Mixer
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.2.1
--! @Git-Tag:        xxxx
------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;

--! @Module-Description
--! This testbench reads in real and imaginary components of a test signal through
--! the Generic Mixer module. Output is written to two files and interpreted by a
--! python script to verify correct functionality.

entity GenericMixer_tb is
end GenericMixer_tb;

architecture behavior of GenericMixer_tb is

  ------------------------------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------------------------------
  component GenericMixer is
    generic (
      BIT_WIDTH      : natural range 8 to 32 := 32;
      LUT_PHASE      : std_logic             := '1';       --! 0 if using 1/4 sin LUT, 1 if using 1/4 cos LUT
      FCW_WIDTH      : natural               := 32;
      LATENCY        : natural               := 2  
    );
    port(
      -- inputs
      Clock          :  in std_logic;                      --! system clock
      Reset          :  in std_logic;                      --! system reset
  
      OscillatorFcw  :  in signed(FCW_WIDTH-1 downto 0);   --! s.31
      SampleI        :  in signed(BIT_WIDTH-1 downto 0);   --! unshifted i input
      SampleQ        :  in signed(BIT_WIDTH-1 downto 0);   --! unshifted q input
  
      SampleInValid  :  in std_logic;                      --! is input valid
      SampleInLast   :  in std_logic;                      --! marker to delineate two back-to-back sequences of inputs
      SampleOutReady :  in std_logic;                      --! is following module ready to accept input
  
      -- ouptuts
      OverflowStatus : out std_logic_vector(1 downto 0);   --! overflow flags, b1=q b0=i
  
      MixedSampleI   : out signed(BIT_WIDTH-1 downto 0);   --! shifted i output
      MixedSampleQ   : out signed(BIT_WIDTH-1 downto 0);   --! shifted q output
  
      SampleOutValid : out std_logic := '0';               --! data on output is valid
      SampleOutLast  : out std_logic := '0';               --! marker to delineate two back-to-back sequences of inputs
      SampleInReady  : out std_logic := '0'                --! tell preceding module that we're ready for  input
    );
  end component;
    
  ------------------------------------------------------------------------------------------------------
  -- Constants
  ------------------------------------------------------------------------------------------------------

  constant N_SAMPLES            : natural := 2**16; --! DFT size
  constant BIT_WIDTH            : natural := 16;    --! ADC resolution
  constant FCW_WIDTH            : natural := 16;    --! Mixer resolution
  constant LATENCY              : natural := 3;     --! 3 for 16b res

  constant Fs                   : real    := 12.50e6; --! Hz
  constant CLOCK_PERIOD         : time    := natural(1.0e9/Fs) * 1 ns; --! ns 

  constant F                    : real    := 1.0e6; --! Hz
  constant F_FCW                : natural := natural(F/Fs*N_SAMPLES); --! Hz

  constant LUT_PHASE            : std_logic := '0';
  
  ------------------------------------------------------------------------------------------------------
  -- Input signals
  ------------------------------------------------------------------------------------------------------
  signal Clock          : std_logic := '0';
  signal Reset          : std_logic := '1';
 
  signal OscillatorFcw  : signed(BIT_WIDTH-1 downto 0) := to_signed(F_FCW, BIT_WIDTH);
  signal SampleI        : signed(BIT_WIDTH-1 downto 0) := (others => '0');
  signal SampleQ        : signed(BIT_WIDTH-1 downto 0) := (others => '0');
  
  signal SampleInValid  : std_logic := '0';
  signal SampleInLast   : std_logic := '0';
  signal SampleOutReady : std_logic := '0';
  
  ------------------------------------------------------------------------------------------------------
  -- Output signals
  ------------------------------------------------------------------------------------------------------
  signal OverflowStatus : std_logic_vector(1 downto 0) := (others => '0');
  signal MixedSampleI   : signed(BIT_WIDTH-1 downto 0) := (others => '0');
  signal MixedSampleQ   : signed(BIT_WIDTH-1 downto 0) := (others => '0');
  
  signal SampleOutValid : std_logic := '0';
  signal SampleOutLast  : std_logic := '0';
  signal SampleInReady  : std_logic := '0';
  
begin
  
  uut : GenericMixer
  generic map(
    BIT_WIDTH      => BIT_WIDTH,
    LUT_PHASE      => LUT_PHASE
  )
  port map (
    Clock          => Clock,
    Reset          => Reset,
    OscillatorFcw  => OscillatorFcw,
    SampleI        => SampleI,
    SampleQ        => SampleQ,
    SampleInValid  => SampleInValid,
    SampleInLast   => SampleInLast,
    SampleOutReady => SampleOutReady,
    OverflowStatus => OverflowStatus,
    MixedSampleI   => MixedSampleI,
    MixedSampleQ   => MixedSampleQ,
    SampleOutValid => SampleOutValid,
    SampleOutLast  => SampleOutLast,
    SampleInReady  => SampleInReady
  );
  
  clock_proc : process
  begin
      clock <= '0';
      wait for CLOCK_PERIOD / 2;
      clock <= '1';
      wait for CLOCK_PERIOD / 2;
  end process;
  
  -- read in samples from file to UUT
  samples_in_proc : process
    file     SampleIFileIn         : text;
    variable SampleIFileLine       : line;
    variable SampleILineValue      : integer;
    file     SampleQFileIn         : text;
    variable SampleQFileLine       : line;
    variable SampleQLineValue      : integer;
 
    begin
      -- open input files
      file_open(SampleIFileIn,     "C:/Users/astock1/Desktop/Projects/spectrum-sensing/generic-mixer/test/i_in.txt",  read_mode);
      file_open(SampleQFileIn,     "C:/Users/astock1/Desktop/Projects/spectrum-sensing/generic-mixer/test/q_in.txt",  read_mode);
      
      SampleInValid <= '0';

      wait until rising_edge(Clock);
      Reset <= '0';
      wait for 10*CLOCK_PERIOD;
      wait until rising_edge(Clock);

      -- loop through input files and stimulate UUT
      while (not endfile(SampleIFileIn) and not endfile(SampleQFileIn)) loop

        wait until rising_edge(Clock);

        Reset <= '0';
        SampleInValid <= '1';

        -- read I sample
        readline(SampleIFileIn, SampleIFileLine);
        read(SampleIFileLine, SampleILineValue);
        SampleI <= to_signed(SampleILineValue, SampleI'length);

        -- read Q sample
        readline(SampleQFileIn, SampleQFileLine);
        read(SampleQFileLine, SampleQLineValue);
        SampleQ <= to_signed(SampleQLineValue, SampleQ'length);

      end loop;

      -- SampleInLast demarcates end of this series of inputs.
      SampleInLast <= '1';

      -- We've just put in the last valid input.
      wait for CLOCK_PERIOD;
      SampleInValid <= '0';
      SampleInLast <= '0';
      SampleI <= to_signed(0, SampleI'length);
      SampleQ <= to_signed(0, SampleQ'length);

      -- test behavior of SampleInReady / SampleOutReady control signals
      wait for CLOCK_PERIOD;
      SampleOutReady <= '1';
      wait for CLOCK_PERIOD;
      SampleOutReady <= '0';

      wait for 10*CLOCK_PERIOD;
      file_close(SampleIFileIn);
      file_close(SampleQFileIn);
      assert false report "test done" severity failure;
      wait;

  end process;
  
  -- read output from UUT and write to file
  read_output : process
    file     MixedSampleIFileOut   : text;
    variable MixedSampleIFileLine  : line;
    file     MixedSampleQFileOut   : text;
    variable MixedSampleQFileLine  : line;
 
    begin
      -- open files
      file_open(MixedSampleIFileOut, "../../../../../test/i_out.txt", write_mode);
      file_open(MixedSampleQFileOut, "../../../../../test/q_out.txt", write_mode);

      loop
        if SampleOutValid = '1' then
          -- write MixedSampleI out
          write(MixedSampleIFileLine, integer'image(to_integer(signed(MixedSampleI))));
          writeline(MixedSampleIFileOut, MixedSampleIFileLine);

          -- write MixedSampleQ out
          write(MixedSampleQFileLine, integer'image(to_integer(signed(MixedSampleQ))));
          writeline(MixedSampleQFileOut, MixedSampleQFileLine);
        end if;
        wait until rising_edge(Clock);
      end loop;
      
      --close output files
      file_close(MixedSampleIFileOut);
      file_close(MixedSampleQFileOut);
      
  end process;

end;
