------------------------------------------------------------------------------------------------------
--! @Author:         Dylan J. Gormley (NASA GRC/LCI)
--! @Creation-Date:  1 November 2020
--! @Module-Name:    Single-Term Symbol Rate Estimator Testbench
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.2.1
--! @Git-Tag:        xxxx
------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity SingleTermSRE_tb is
--  port ( );
end SingleTermSRE_tb;

architecture Behavioral of SingleTermSRE_tb is

  ------------------------------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------------------------------
  component SingleTermSRE
    generic (
      N_SAMPLES            : natural := 2**8; 
      BIT_WIDTH            : natural := 16
    );
    port (
      -- inputs
      Clock                : in  std_logic;
      Reset                : in  std_logic; 
      
      OscillatorFcw        : in  signed(15 downto 0); 
  
      SampleOutReady       : in  std_logic; 
      SampleInValid        : in  std_logic; 
      SampleInLast         : in  std_logic; 
      SampleIn_I           : in  signed(BIT_WIDTH-1 downto 0); 
      SampleIn_Q           : in  signed(BIT_WIDTH-1 downto 0);
      
      -- outputs
      OverflowStatus       : out std_logic_vector(1 downto 0);
      
      SampleInReady        : out std_logic;
      SampleOutValid       : out std_logic;
      SampleOutLast        : out std_logic;
      SampleOut_I          : out signed(BIT_WIDTH-1 downto 0);
      SampleOut_Q          : out signed(BIT_WIDTH-1 downto 0)
    );
  end component;
 
  ------------------------------------------------------------------------------------------------------
  -- Constants
  ------------------------------------------------------------------------------------------------------ 
  constant ClockPeriod          : time    := 10 ns; -- 100MHz
  
  constant SAMPLES_PER_SYMBOL   : natural := 8;
  constant N_SYMBOLS            : natural := 2**12;
  constant N_SAMPLES            : natural := SAMPLES_PER_SYMBOL*N_SYMBOLS;
  constant BIT_WIDTH            : natural := 16;
  constant FCW_BITS             : natural := 16;
  constant N_SHIFTS             : natural := 5;
 
  ------------------------------------------------------------------------------------------------------
  -- Signals
  ------------------------------------------------------------------------------------------------------ 
  signal Clock                : std_logic := '1';
  signal Reset                : std_logic := '0';

  signal OscillatorFcw        : signed(15 downto 0)   := (others => '0');

  signal SampleOutReady       : std_logic := '0';
  signal SampleInValid        : std_logic := '0';
  signal SampleInLast         : std_logic := '0';
  signal SampleIn_I           : signed(BIT_WIDTH-1 downto 0) := (others => '0');
  signal SampleIn_Q           : signed(BIT_WIDTH-1 downto 0) := (others => '0');

  signal OverflowStatus       : std_logic_vector(1 downto 0) := (others => '0');
  signal SampleInReady        : std_logic := '0';
  signal SampleOutValid       : std_logic := '0';
  signal SampleOutLast        : std_logic := '0';
  signal SampleOut_I          : signed(BIT_WIDTH-1 downto 0) := (others => '0');
  signal SampleOut_Q          : signed(BIT_WIDTH-1 downto 0) := (others => '0');

begin

  ------------------------------------------------------------------------------------------------------
  -- Unit Under Test
  ------------------------------------------------------------------------------------------------------ 
  uut : SingleTermSRE
    generic map (
      N_SAMPLES            => N_SAMPLES,
      BIT_WIDTH            => BIT_WIDTH
    )
    port map (
      -- inputs
      Clock                => Clock,
      Reset                => Reset,
                           
      OscillatorFcw        => OscillatorFcw,
      
      SampleOutReady       => SampleOutReady,                    
      SampleInValid        => SampleInValid,     
      SampleInLast         => SampleInLast,     
      SampleIn_I           => SampleIn_I,
      SampleIn_Q           => SampleIn_Q,

      -- outputs
      OverflowStatus      => OverflowStatus,
    
      SampleInReady        => SampleInReady,                                           
      SampleOutValid       => SampleOutValid,    
      SampleOutLast        => SampleOutLast,     
      SampleOut_I          => SampleOut_I,
      SampleOut_Q          => SampleOut_Q
    );
 
  ------------------------------------------------------------------------------------------------------
  -- Generate Clock
  ------------------------------------------------------------------------------------------------------ 
  clk_gen : process
  begin
    wait for ClockPeriod/2;
    Clock <= not Clock;
  end process clk_gen;
 
 ------------------------------------------------------------------------------------------------------
  -- Generate Reset
  ------------------------------------------------------------------------------------------------------
  rst_gen : process
  begin
    Reset <= '1';
    wait for 10*ClockPeriod;
    Reset <= '0';
    wait;
  end process rst_gen;
 
  ------------------------------------------------------------------------------------------------------
  -- Generate Stimulus
  ------------------------------------------------------------------------------------------------------ 
  stimulus_gen : process
   
    file     FileIn_Q             : text;
    variable FileLine_Q           : line;
    variable LineValue_Q          : integer;
    variable Tmp_Q                : signed(BIT_WIDTH-1 downto 0);

    file     FileIn_I             : text;
    variable FileLine_I           : line;
    variable LineValue_I          : integer;
    variable Tmp_I                : signed(BIT_WIDTH-1 downto 0);

    variable OscillatorResolution : real    := real(2**FCW_BITS);
    variable ClockFrequency       : real    := real(100e6) ;     
    variable OscillatorFrequency  : real    := 0.0; 
    variable Fcw                  : real    := 0.0;
    variable FreqShiftSize        : real    := 0.5; -- sweep by multiples of Rs * FreqShiftSize
    
    variable SampleCount          : natural := 0;
    variable SampleInLastV        : std_logic := '0';
    
  begin
    
    -- FCW of 0 is the autocorrelation, which we don't care about
    for Shift in 1 to N_SHIFTS loop

      file_open(FileIn_Q, "../../../../../test/q_in.txt", read_mode);
      file_open(FileIn_I, "../../../../../test/i_in.txt", read_mode);

      OscillatorFrequency  := FreqShiftSize * real(Shift)*(ClockFrequency / real(SAMPLES_PER_SYMBOL));
      Fcw                  := -1.0 *(OscillatorResolution*OscillatorFrequency)/ClockFrequency;

      OscillatorFcw      <= to_signed(integer(Fcw), 16);
   
      while (SampleInLastV = '0') loop
        if (SampleInReady = '1') then

          -- T_HOLD, add a little delay to mimic hardware environments        
          --wait for 1 ns; 

          -- Q
          readline(FileIn_Q, FileLine_Q);
          read(FileLine_Q, LineValue_Q);
          Tmp_Q := to_signed(LineValue_Q, Tmp_Q'length);
          --report "q_in: " & integer'image(to_integer(signed(Tmp_Q)));
          
          -- I
          readline(FileIn_I, FileLine_I);
          read(FileLine_I, LineValue_I);
          Tmp_I := to_signed(LineValue_I, Tmp_I'length);
          --report "i_in: " & integer'image(to_integer(signed(Tmp_I)));
                  
          SampleInValid <= '1';
          SampleIn_Q    <= Tmp_Q;
          SampleIn_I    <= Tmp_I;
          
          if (SampleCount = N_SAMPLES-1) then
             SampleInLast <= '1';
             SampleInLastv := '1';
             --exit;
          else
            SampleInLast <= '0';
            SampleInLastv := '0';
            SampleCount  := SampleCount+1;
          end if;
        end if;
        
        -- sync to clock
        wait until rising_edge(Clock); 
         
     end loop; -- read loop

      file_close(FileIn_Q);
      file_close(FileIn_I);

      -- reset for next iteration     
      SampleInLastV := '0';
      SampleCount   := 0;
      
    end loop; -- step loop
    
    SampleInLast  <= '0';
    SampleInValid <= '0';
    SampleIn_I    <= (others => '0');
    SampleIn_Q    <= (others => '0');
    OscillatorFcw <= (others => '0');
    
    report "stimulus finished";
    wait;
    
  end process stimulus_gen;
 
  -----------------------------------------------------------------------
  -- Ouput Results
  -----------------------------------------------------------------------
  results : process
 
    file     FileOut_I   : text;
    variable FileLine_I  : line;
    file     FileOut_Q   : text;
    variable FileLine_Q  : line;
  begin
 
    file_open(FileOut_I, "sre_out_I.txt", write_mode);
    file_open(FileOut_Q, "sre_out_Q.txt", write_mode);
    
    wait until falling_edge(Reset);
    wait until rising_edge(Clock);
    SampleOutReady <= '1';
    wait until rising_edge(SampleOutValid);
 
    loop
      
      -- I
      --report "i_out: " &   integer'image(to_integer(signed(SampleOut_I(BIT_WIDTH-1 downto 0))));
      write(FileLine_I,    integer'image(to_integer(signed(SampleOut_I(BIT_WIDTH-1 downto 0)))));
      writeline(FileOut_I, FileLine_I);
      
      -- Q
      --report "q_out: " &   integer'image(to_integer(signed(SampleOut_Q(BIT_WIDTH-1 downto 0))));
      write(FileLine_Q,    integer'image(to_integer(signed(SampleOut_Q(BIT_WIDTH-1 downto 0)))));
      writeline(FileOut_Q, FileLine_Q);
      
      wait until rising_edge(Clock);
      exit when SampleOutValid = '0';
      
    end loop;

    SampleOutReady <= '0';
  
    file_close(FileOut_I);
    file_close(FileOut_Q);
    
    report "write finished";
    assert false report "test done" severity failure;
    wait;
  end process results;

end Behavioral;