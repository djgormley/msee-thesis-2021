------------------------------------------------------------------------------------------------------
--! @Author:         Anthony A. Stock (NASA GRC/LCI) [NIP]
--! @Creation-Date:  17 April 2021
--! @Module-Name:    Single-Term Center Frequency Detector Testbench
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.1.3
--! @Git-Tag:        xxxx
--! @Version 1.0:
--! Anthony A. Stock (NASA GRC/LCI) - File created.
--! @Version 2.0:
--! Dylan J. Gormley (NASA GRC/LCI) - Cleaned up code.  Made it a bit more efficient and clear.
------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;

entity CFD_tb is
--  port ( );
end CFD_tb;

architecture Behavioral of CFD_tb is

  ------------------------------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------------------------------
  component CenterFrequencyDetector is
    generic (
      N_SAMPLES          : natural := 2**16;         --! number of samples
      BIT_WIDTH          : natural := 16;            --! resolution of samples
      FCW_WIDTH          : natural := 16;
      LATENCY            : natural := 2    
    );
    port (
      -- inputs
      Clock              : in  std_logic; --! active high
      Reset              : in  std_logic; --! active high
  
      FcStep             : in  unsigned(FCW_WIDTH-1 downto 0); --! FC_FCW step size
      SymbolRateFcw      : in  unsigned(FCW_WIDTH-1 downto 0); --! Rs FCW
      SymbolRateValid    : in  std_logic;                      --! Rs Valid
  
      SampleOutReady     : in  std_logic; --! active high
      SampleInValid      : in  std_logic; --! active high
      SampleInLast       : in  std_logic; --! active high
  
      SampleIn_I         : in  signed(BIT_WIDTH-1 downto 0); -- Incoming I sample
      SampleIn_Q         : in  signed(BIT_WIDTH-1 downto 0); -- Incoming Q sample
  
      -- outputs
      SampleInReady      : out std_logic;
      OverflowStatus     : out std_logic_vector(3 downto 0); --! mixer overflow, not asynchronous
      SymbolRateFcwReady : out std_logic;
  
      SampleOutValid     : out std_logic; --! active high
      SampleOutLast      : out std_logic; --! active high    
      
      Rs_detected        : out unsigned(FCW_WIDTH-1 downto 0);
      Fc_detected        : out signed(FCW_WIDTH-1 downto 0);
      Peak_Value         : out unsigned(BIT_WIDTH-1 downto 0)
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
  
  constant RS_RES               : real    := 3.125e6; --! Bd
  constant N_RS_SHIFTS          : natural := natural((Fs/2.0)/RS_RES); -- 5, skip 0
  
  constant FC_RES               : real    := 3.125e6; --! Hz
  constant N_FC_SHIFTS          : natural := natural(Fs/FC_RES)+1;  -- 11, include 0
  constant FC_FCW               : natural := natural(FC_RES/Fs*N_SAMPLES); --! Hz

  ------------------------------------------------------------------------------------------------------
  -- Signals
  ------------------------------------------------------------------------------------------------------
    
  -- inputs
  signal Clock              : std_logic := '0'; --! active high
  signal Reset              : std_logic := '0'; --! active high

  signal FcStep             : unsigned(FCW_WIDTH-1 downto 0) := to_unsigned(FC_FCW, FCW_WIDTH); --! FC_FCW step size
  signal SymbolRateFcw      : unsigned(FCW_WIDTH-1 downto 0) := (others => '0');                --! Rs FCW
  signal SymbolRateValid    : std_logic := '0';                                                 --! Rs Valid

  signal SampleOutReady     : std_logic := '0'; --! active high
  signal SampleInValid      : std_logic := '0'; --! active high
  signal SampleInLast       : std_logic := '0'; --! active high

  signal SampleIn_I         : signed(BIT_WIDTH-1 downto 0) := (others => '0'); --! Incoming I sample
  signal SampleIn_Q         : signed(BIT_WIDTH-1 downto 0) := (others => '0'); --! Incoming Q sample

  -- out
  signal SampleInReady      : std_logic := '0';
  signal OverflowStatus     : std_logic_vector(3 downto 0) := (others => '0'); --! mixer overflow, not asynchronous
  signal SymbolRateFcwReady : std_logic := '0';

  signal SampleOutValid     : std_logic := '0'; --! active high
  signal SampleOutLast      : std_logic := '0'; --! active high    

  signal Rs_detected        : unsigned(FCW_WIDTH-1 downto 0) := (others => '0');
  signal Fc_detected        : signed(FCW_WIDTH-1 downto 0)   := (others => '0');
  signal Peak_Value         : unsigned(BIT_WIDTH-1 downto 0) := (others => '0');

  -- general
  signal SampleCount        : natural := 0;

begin

  ------------------------------------------------------------------------------------------------------
  -- Unit Under Test
  ------------------------------------------------------------------------------------------------------
  uut : CenterFrequencyDetector
    generic map (
      N_SAMPLES        => N_SAMPLES,
      BIT_WIDTH        => BIT_WIDTH,
      FCW_WIDTH        => FCW_WIDTH,
      LATENCY          => LATENCY
    )
    port map (
      -- inputs
      Clock              => Clock,
      Reset              => Reset,
                     
      FcStep             => FcStep,
      SymbolRateFcw      => SymbolRateFcw,
      SymbolRateValid    => SymbolRateValid,
                        
      SampleOutReady     => SampleOutReady,
      SampleInValid      => SampleInValid,
      SampleInLast       => SampleInLast,
                      
      SampleIn_I         => SampleIn_I,
      SampleIn_Q         => SampleIn_Q,
                        
      -- outputs        
      SampleInReady      => SampleInReady,
      OverflowStatus     => OverflowStatus,
      SymbolRateFcwReady => SymbolRateFcwReady,
                      
      SampleOutValid     => SampleOutValid,
      SampleOutLast      => SampleOutLast,
                
      Rs_detected        => Rs_detected,
      Fc_detected        => Fc_detected,
      Peak_Value         => Peak_Value         
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
  -- Generate Stimulus
  ------------------------------------------------------------------------------------------------------
  stimulus_gen : process
    file     FileIn_Q,    FileIn_I     : text;
    variable FileLine_Q,  FileLine_I   : line;
    variable LineValue_Q, LineValue_I  : integer;
    
    variable Rs_v                      : natural;
    
  begin
    -- reset
    wait for 10*CLOCK_PERIOD;
    reset <= '0';
    wait until rising_edge(clock);
        
    for Rs_Shift in 1 to 1 loop -- skip 0 (CAF)

      Rs_v           := natural(RS_RES/Fs*N_SAMPLES)*Rs_Shift;
      SymbolRateFcw  <= to_unsigned(Rs_v, SymbolRateFcw'length);      
      
      SymbolRateValid    <= '1';
      
      ------------------------------------------------------------------------------------------------------
      -- load data
      ------------------------------------------------------------------------------------------------------
      for Fc_shift in 0 to 3*N_FC_SHIFTS loop -- simple count

        -- open files here to run the same one over and over again.
        file_open(FileIn_I, "C:/Projects/cesium-dev/src/single-term-cfd/test/i_in_py.txt", read_mode);
        file_open(FileIn_Q, "C:/Projects/cesium-dev/src/single-term-cfd/test/q_in_py.txt", read_mode);
        wait until rising_edge(Clock);  

        loop
          --if (SampleInReady = '1') then
              
            SampleInValid <= '1';

            -- I
            readline(FileIn_I, FileLine_I);
            read(FileLine_I, LineValue_I);
            SampleIn_I <= to_signed(LineValue_I, SampleIn_I'length);
            --report "i_in: " & integer'image(to_integer(SampleIn_I));

            -- Q
            readline(FileIn_Q, FileLine_Q);
            read(FileLine_Q, LineValue_Q);
            SampleIn_Q <= to_signed(LineValue_Q, SampleIn_Q'length);
            --report "q_in: " & integer'image(to_integer(SampleIn_Q));
              
            -- track last sample
            if (SampleCount = N_SAMPLES-2) then
              SampleInLast <= '1';
              SampleCount  <= SampleCount+1;
            elsif (SampleCount = N_SAMPLES-1) then
              SampleInLast <= '0';
              SampleCount  <= 0;
              exit;
            else
              SampleInLast <= '0';
              SampleCount  <= SampleCount+1;
            end if;
    
          --end if; -- SampleInReady
        wait until rising_edge(Clock);            
      end loop; -- SampleCount
    end loop; -- N_FC_SHIFTS
  end loop; -- N_RS_SHIFTS
         
  file_close(FileIn_Q);
  file_close(FileIn_I);
  
  SampleCount   <= 0;
  SampleInLast  <= '0';
  SampleInValid <= '0';  
  SampleIn_I    <= (others => '0');
  SampleIn_Q    <= (others => '0');
  SymbolRateFcw <= (others => '0');
   
  wait for 10*CLOCK_PERIOD;
  wait until rising_edge(Clock);
  reset <= '1';
  wait for 2*CLOCK_PERIOD;
  wait until rising_edge(Clock);
  reset <= '0';
  wait for 10*CLOCK_PERIOD;
  wait until rising_edge(Clock);
  wait;
 
 end process stimulus_gen;
 
 
--  -----------------------------------------------------------------------
--  -- Ouput Results
--  -----------------------------------------------------------------------
--  results : process
 
--    file     FileOut_Rs,  FileOut_Fc,  FileOut_Peak  : text;
--    variable FileLine_Rs, FileLine_Fc, FileLine_Peak : line;

----    variable tupleCount     : natural := 0;
----    variable Rs_Num         : natural := 0;
    
--  begin
  
--    file_open(FileOut_Rs,   "C:/Projects/cesium-dev/src/single-term-cfd/test/rs.txt",   write_mode);
--    file_open(FileOut_Fc,   "C:/Projects/cesium-dev/src/single-term-cfd/test/fc.txt",   write_mode);
--    file_open(FileOut_Peak, "C:/Projects/cesium-dev/src/single-term-cfd/test/peak.txt", write_mode);
  
--    loop
--      wait until rising_edge(Clock);
--      exit when Reset = '0';
--    end loop;
    
--    SampleOutReady <= '1';
    
----    for Rs_num in 0 to N_RS_SHIFTS-1 loop
--    loop

--      -- trigger
--      loop
--        wait until rising_edge(Clock);
--        exit when SampleOutValid = '1';
--      end loop;

      
--      -- Results: (Rs, Fc, Peak) for each alpha
--      write(FileLine_Rs,      integer'image(to_integer(unsigned(Rs_detected))));
--      writeline(FileOut_Rs, FileLine_Rs); 
--      write(FileLine_Fc,      integer'image(to_integer(signed(Fc_detected))));
--      writeline(FileOut_Fc, FileLine_Fc);
--      write(FileLine_Peak,    integer'image(to_integer(unsigned(Peak_Value))));
--      writeline(FileOut_Peak, FileLine_Peak);
      
      
----      tupleCount := tupleCount + 1;
    
--    end loop;
    
----    tupleCount := 0;
----    SampleOutReady <= '0';
    
----    file_close(FileOut_Rs);
----    file_close(FileOut_Fc);
----    file_close(FileOut_Peak);
    
----    wait for 100*ClockPeriod;
----    report "stimulus finished";
----    assert false report "test done" severity failure;
    
--    wait;
--  end process results;

end Behavioral;
