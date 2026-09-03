------------------------------------------------------------------------------------------------------
--! @Author:         Anthony A. Stock, intern, NASA GRC/LCI
--! @Creation-Date:  5 October 2020
--! @Module-Name:    Instantaneous Power Testbench
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.2.1
--! @Git-Tag:        xxxx
--!
--! Revision 0.01 - Anthony A. Stock -- file created
------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use work.max_pkg.all;

entity InstantaneousPower_tb is
--  Port ( );
end InstantaneousPower_tb;

architecture Behavioral of InstantaneousPower_tb is
  component InstantaneousPower
    Generic (
      LengthA     : integer range 2 to 32 := 32;  --! Number of bits in operand A.
      LengthB     : integer range 2 to 32 := 32;  --! Number of bits in operand B.
      Latency     : integer range 2 to  6 := 2;   --! Total cycles of latency to do an operation.
      BitstoTrunc : integer := 0;                 --! Allows the ability to trim most significant bits. Does not used saturation.
      BitstoRound : integer := 0                  --! Allows the ability to trim least significant bits through symmetric rounding.
    );

    Port (
      -- Module inputs
      Clock               : in  std_logic;                  --! Global clock
      Reset               : in  std_logic;                  --! Synchronous reset
      A_in                : in  signed(LengthA-1 downto 0); --! Signed input 1
      B_in                : in  signed(LengthB-1 downto 0); --! Signed input 2
      SampleInValid       : in  std_logic;                  --! Input being driven into multiplier is ready to be read
      SampleInLast        : in  std_logic;                  --! marker to delineate two back-to-back sequences of inputs
      SampleOutReady      : in  std_logic;                  --! is following module ready to accept input
      -- Module outputs
      C_out               : out signed(max(LengthA,LengthB)*2-1-BitstoRound-BitstoTrunc downto 0); --! use max() function for full output. For the moment, reduced to 32-bit.
      SampleOutValid      : out std_logic;                                                         --! Data on output is valid
      SampleOutLast       : out std_logic;                                                         --! marker to delineate two back-to-back sequences of inputs
      SampleInReady       : out std_logic                                                          --! tell preceding module that we're ready for input
    );
  end component;

  -----------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------

  constant LengthA     : integer := 5;
  constant LengthB     : integer := 6;
  constant Latency     : integer := 2;  --! Total cycles of latency to do an operation.
  constant BitstoTrunc : integer := 1;  --! Allows the ability to trim most significant bits (without saturation!).
  constant BitstoRound : integer := 1;  --! Allows the ability to trim least significant bits through symmetric rounding.

  constant ClockPeriod    : time := 10 ns;
  constant read_filename  : string := "../../../../../test/inputs.csv";
  constant write_filename : string := "../../../../../test/output.txt";
  file write_file         : text;

  -----------------------------------------------------------------------
  -- Input signals
  -----------------------------------------------------------------------
  signal Clock            : std_logic := '0';           --! Global clock, init to 0
  signal Reset            : std_logic := '1';           --! Synchronous reset, init to 1
  signal A_in             : signed(LengthA-1 downto 0); --! Signed input 1
  signal B_in             : signed(LengthB-1 downto 0); --! Signed input 2
  signal SampleInValid    : std_logic := '0';           --! Input being driven into multiplier is ready to be read. Init to 0
  signal SampleInLast     : std_logic := '0';           --! marker to delineate two back-to-back sequences of inputs
  signal SampleOutReady   : std_logic := '0';           --! is following module ready to accept input
  
  -----------------------------------------------------------------------
  -- Output signals
  -----------------------------------------------------------------------
  signal C_out            : signed(max(LengthA,LengthB)*2-1-BitstoRound-BitstoTrunc downto 0);
  signal SampleOutValid   : std_logic;                  --! Data on output is valid
  signal SampleOutLast    : std_logic := '0';           --! marker to delineate two back-to-back sequences of inputs
  signal SampleInReady    : std_logic := '0';           --! ready to accept input

begin
  uut: InstantaneousPower
    generic map(
      LengthA => LengthA,
      LengthB => LengthB,
      Latency => Latency,
      BitstoTrunc => BitstoTrunc,
      BitstoRound => BitstoRound
    )
    port map(
      Clock            => Clock,
      Reset            => Reset,
      A_in             => A_in,
      B_in             => B_in,
      SampleInValid    => SampleInValid,
      SampleInLast     => SampleInLast,
      SampleOutReady   => SampleOutReady,
      C_out            => C_out,
      SampleOutValid   => SampleOutValid,
      SampleOutLast    => SampleOutLast,
      SampleInReady    => SampleInReady
    );
  

  -- Generate clock
  Clock_proc : process
  begin
    wait for ClockPeriod / 2;
    Clock <= not Clock;
  end process Clock_proc;


  -- Calculate Latency
  CheckLatency_proc : process
    variable InputStart      : time;
    variable OutputStart     : time;
    variable MeasuredLatency : integer;
  begin
    -- use control signals to find difference b/w when input starts and module begins producing output
    wait until rising_edge(SampleInValid);
    InputStart := now;
    wait until rising_edge(SampleOutValid);
    OutputStart := now;

    MeasuredLatency := (OutputStart - InputStart) / ClockPeriod;
    if Latency = measuredLatency then
      report "TEST PASS: Latency matches expected latency of " & integer'image(Latency);
    else
      report "TEST FAIL: Latency of " & integer'image(measuredLatency) & " does NOT match expected latency of " & integer'image(Latency);
    end if;


    wait;
  end process CheckLatency_proc;


  -- Read in test vectors from file
  ReadFile_proc : process
    file     inputFile  : text;
    variable fileLine   : line;
    variable comma_char : character;
    variable A_file_in  : string(LengthA downto 1);
    variable B_file_in  : string(LengthB downto 1);
    variable A_vector   : signed(LengthA-1 downto 0);
    variable B_vector   : signed(LengthB-1 downto 0);

  begin

    -- read in file
    wait until rising_edge(Clock);
    file_open(inputFile, read_filename, read_mode);
    Reset <= '0';

    -- loop through file line-by-line
    while not endfile(inputFile) loop
      -- trigger read
      wait until rising_edge(Clock);

      -- read in multiplicands and theoretical C_out generated by python
      readline(inputFile, fileLine);
      read(fileLine, A_file_in);
      read(fileLine, comma_char);
      read(fileLine, B_file_in);

      -- copy over A from file (string) into vector to be fed into A_in
      for i in LengthA downto 1 loop
        A_vector(i-1) := std_logic'value("'" & A_file_in(i) & "'");
      end loop;

      -- copy over B from file (string) into vector to be fed into B_in
      for i in LengthB downto 1 loop
        B_vector(i-1) := std_logic'value("'" & B_file_in(i) & "'");
      end loop;

      -- feed test multiplicands into multiplier
      A_in <= A_vector;
      B_in <= B_vector;

      -- input is valid for this clock
      SampleInValid <= '1';

    end loop;

    -- we're still on the clock where the last sample was driven into UUT.
    SampleInLast <= '1';
    wait for ClockPeriod;
    SampleInLast <= '0';

    -- input no longer valid.
    SampleInValid <= '0';

    -- test behavior of SampleInReady / SampleOutReady control signals
    wait for ClockPeriod;
    SampleOutReady <= '1';
    wait for ClockPeriod;
    SampleOutReady <= '0';

    wait for 10*ClockPeriod;
    file_close(inputFile);
    assert false report "test done" severity failure;

  end process ReadFile_proc;


  -- Write testbench results to file
  LogFile_proc : process
    variable Result  : line;
  begin

  -- open output file
  file_open(write_file, write_filename, write_mode);

  -- if output is valid, write C_out into output file
  loop
    if SampleOutValid = '1' then
      -- output from multiplier in binary string format
      for x in C_out'length-1 downto 0 loop
        if C_out(x) = '1' then
          write(Result, integer'image(1));
        elsif C_out(x) = '0' then
          write(Result, integer'image(0));
        else
          write(Result, string'("X"));
        end if;
      end loop;

    -- write line to file
    writeline(write_file, Result);
    end if;
    wait until rising_edge(Clock);
  end loop;

  -- close output file
  file_close(write_file);
  wait for 5*ClockPeriod;

  end process;

end Behavioral;
