------------------------------------------------------------------------------------------------------
--! @Author:         Dylan J. Gormley (NASA GRC/LCI)
--! @Creation-Date:  1 November 2020
--! @Module-Name:    Accumulator Testbench
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.1.3
--! @Git-Tag:        xxxx
------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;

entity Accumulator_tb is
  --  port ( );
end Accumulator_tb;

architecture Behavioral of Accumulator_tb is

  ------------------------------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------------------------------
  component Accumulator
    generic (
      N_SAMPLES      : natural := 2**16; --! number of samples until last
      BIT_WIDTH      : natural := 16     --! resolution of sample
    );
    port (
      -- inputs
      Clock          : in  std_logic; --!
      Reset          : in  std_logic; --! synchronous, active high

      SampleOutReady : in  std_logic; --! active high
      SampleInValid  : in  std_logic; --! active high
      SampleInLast   : in  std_logic; --! active high
      SampleIn       : in  signed(BIT_WIDTH-1 downto 0); --! s1.14

      -- outputs
      SampleInReady  : out std_logic; --! active high
      SampleOutValid : out std_logic; --! active high
      SampleOutLast  : out std_logic; --! active high
      SampleOut      : out signed(BIT_WIDTH-1 downto 0) --! s1.14
    );
  end component;

  ------------------------------------------------------------------------------------------------------
  -- Constants
  ------------------------------------------------------------------------------------------------------
  constant ADC_RATE     : real    := 100.0e6;                        --! samps/sec
  constant CLOCK_PERIOD : time    := natural(1.0e9/ADC_RATE) * 1 ns; --! ns
  constant N_SAMPLES    : natural := 2**16;
  constant BIT_WIDTH    : natural := 16;
  constant Latency      : natural := 1; -- clock cycles of latency b/w first input and first output. Latency=1 for current implementation

  ------------------------------------------------------------------------------------------------------
  -- Signals
  ------------------------------------------------------------------------------------------------------
  -- inputs
  signal Clock          : std_logic := '0';
  signal Reset          : std_logic := '0';

  signal SampleOutReady : std_logic := '0';
  signal SampleInValid  : std_logic := '0';
  signal SampleInLast   : std_logic := '0';
  signal SampleIn       : signed(BIT_WIDTH-1 downto 0) := (others => '0');

  type INT_ARRAY is array(0 to 6) of integer;
  signal INT_TABLE: INT_ARRAY := (2**(BIT_WIDTH-1)-1,-2,-1,0,1,2,-2**(BIT_WIDTH-1)); -- most positive, 0, most negative

  -- outputs
  signal SampleInReady  : std_logic := '0';
  signal SampleOutValid : std_logic := '0';
  signal SampleOutLast  : std_logic := '0';
  signal SampleOut      : signed(BIT_WIDTH-1 downto 0) := (others => '0');

begin


  ------------------------------------------------------------------------------------------------------
  -- Unit Under Test
  ------------------------------------------------------------------------------------------------------
  uut : Accumulator
    generic map (
      N_SAMPLES      => N_SAMPLES,
      BIT_WIDTH      => BIT_WIDTH
    )
    port map (
      -- inputs
      Clock          => Clock,
      Reset          => Reset,

      SampleOutReady => SampleOutReady,
      SampleInValid  => SampleInValid,
      SampleInLast   => SampleInLast,
      SampleIn       => SampleIn,

      -- outputs
      SampleInReady  => SampleInReady,
      SampleOutValid => SampleOutValid,
      SampleOutLast  => SampleOutLast,
      SampleOut      => SampleOut
    );

  ------------------------------------------------------------------------------------------------------
  -- Generate Clock
  ------------------------------------------------------------------------------------------------------
  clk_gen : process
  begin
    wait for CLOCK_PERIOD/2;
    Clock <= not Clock;
  end process clk_gen;

  ------------------------------------------------------------------------------------------------------
  -- Generate Reset
  ------------------------------------------------------------------------------------------------------
  rst_gen : process
  begin
   Reset <= '1';
   wait until rising_edge(Clock);
   Reset <= '0';
   wait;
  end process rst_gen;

  ------------------------------------------------------------------------------------------------------
  -- Check timing
  ------------------------------------------------------------------------------------------------------
  CheckTiming_proc : process
    variable InputStart      : time;
    variable OutputStart     : time;
    variable MeasuredLatency : integer;
  begin

    -- use control signals to find difference b/w when input starts and module begins producing output
    wait until rising_edge(SampleInValid);
    InputStart := now;
    wait until rising_edge(SampleOutValid);
    OutputStart := now;

    -- calculate latency and report to TCL
    MeasuredLatency := (OutputStart - InputStart) / CLOCK_PERIOD;
    if Latency = measuredLatency then
      report "TEST PASS: Latency matches expected latency of " & integer'image(Latency);
    else
      report "TEST FAIL: Latency of " & integer'image(measuredLatency) & " does NOT match expected latency of " & integer'image(Latency);
    end if;

    wait;
  end process CheckTiming_proc;

  ------------------------------------------------------------------------------------------------------
  -- Generate Stimulus
  ------------------------------------------------------------------------------------------------------
  stimulus : process
    variable SampleCount    : natural   := 0;
    variable SampleInLastv  : std_logic := '0';
  begin

    -- upstream module tells accumulator that it's ready for input
    wait until Reset = '0';
    wait until rising_edge(Clock);
    SampleOutReady <= '1';

    -- check for overflows and improper resets
    for i in INT_TABLE'range loop -- loop though step sizes
      while (SampleInLastV = '0') loop -- continue to use step size until N samples have been processed
        --if (SampleInReady = '1') then

           -- drive data to UUT
           SampleIn      <= to_signed(INT_TABLE(i), SampleIn'length);
           SampleInValid <= '1';

           -- set control signals and counter on last iteration
           if (SampleCount = N_SAMPLES-1) then
             SampleInLast  <= '1';
             SampleInLastv := '1';
           else
             SampleInLast  <= '0';
             SampleInLastv := '0';
             SampleCount   := SampleCount+1;

           end if; -- last check
        --end if;

        -- synchronize to clock
        wait until rising_edge(Clock);

      end loop;

      -- reset for next iteration
      SampleInLastv := '0';
      SampleCount   := 0;

    end loop; -- Step

    SampleOutReady <= '0';
    SampleInValid  <= '0';
    SampleIn       <= (others => '0');
    SampleInLast   <= '0';

    wait for 10*CLOCK_PERIOD;

    assert false report "test done" severity failure;

  end process stimulus;

  -- read output from UUT and write to file
--  read_output : process
--    file     FileOut      : text;
--    variable FileOutLine  : line;

--    begin
--      -- open files
--      file_open(FileOut, "../../../../../test/output.txt", write_mode);

--      loop
--        if SampleOutValid = '1' then
--          -- write MixedSampleI out
--          write(FileOutLine, integer'image(to_integer(signed(SampleOut))));
--          writeline(FileOut, FileOutLine);

--        end if;
--        wait until rising_edge(Clock);
--      end loop;

--      --close output files
--      file_close(FileOut);

--  end process;

end Behavioral;
