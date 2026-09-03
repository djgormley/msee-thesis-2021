------------------------------------------------------------------------------------------------------
--! @Author:         Dylan J. Gormley (NASA GRC/LCI)
--! @Creation-Date:  1 November 2020
--! @Module-Name:    Single-Term Discrete Fourier Transform Testbench
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.2.1
--! @Git-Tag:        xxxx
------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity SingleTermDft_tb is
--  port ( );
end SingleTermDft_tb;

architecture Behavioral of SingleTermDft_tb is

  ------------------------------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------------------------------
  component SingleTermDft
    generic (
      N_SAMPLES            : natural := 2**12; --! number of samples until last
      BIT_WIDTH            : natural := 32     --! resolution of sample
    );
    port (
      -- inputs
      Clock                : in  std_logic; --! synchronous clock
      Reset                : in  std_logic; --! synchronous reset
      
      OscillatorFcw        : in  signed(15 downto 0);

      SampleOutReady       : in  std_logic; --! active high 
      SampleInValid        : in  std_logic; --! active high 
      SampleInLast         : in  std_logic; --! active high
      SampleIn_I           : in  signed(BIT_WIDTH-1 downto 0);
      SampleIn_Q           : in  signed(BIT_WIDTH-1 downto 0);

      -- outputs 
      OverflowStatus       : out std_logic_vector(1 downto 0); --! b[1]=q b[0]=i    

      SampleInReady        : out std_logic; --! active high 
      SampleOutValid       : out std_logic; --! active high 
      SampleOutLast        : out std_logic; --! active high
      SampleOut_I          : out signed(BIT_WIDTH-1 downto 0);
      SampleOut_Q          : out signed(BIT_WIDTH-1 downto 0)
    );
  end component;
 
  ------------------------------------------------------------------------------------------------------
  -- Constants
  ------------------------------------------------------------------------------------------------------ 
  constant ClockPeriod          : time    := 10 ns; -- 100MHz
  
  constant N_SAMPLES            : natural := 2**12;
  constant BIT_WIDTH            : natural := 32;
  constant FCW_BITS             : natural := 16;
  constant N_SHIFTS             : natural := 10;
  constant SHIFT_AMOUNT         : natural := 50e3;  
 
  ------------------------------------------------------------------------------------------------------
  -- Signals
  ------------------------------------------------------------------------------------------------------ 
  signal Clock                : std_logic := '1';
  signal Reset                : std_logic := '0';

  signal OscillatorFcw        : signed(FCW_BITS-1 downto 0);

  signal OverflowClear        : std_logic := '0';
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
  uut : SingleTermDft
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
      OverflowStatus       => OverflowStatus,    

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
  -- Generate Stimulus
  ------------------------------------------------------------------------------------------------------ 
  stimulus_gen : process
   
    file     FileIn_Q             : text;
    variable FileLine_Q           : line;
    variable LineValue_Q          : integer;

    file     FileIn_I             : text;
    variable FileLine_I           : line;
    variable LineValue_I          : integer;

    variable OscillatorResolution : real    := real(2**FCW_BITS);
    variable ClockFrequency       : real    := real(100e6) ;     
    variable OscillatorFrequency  : real    := 0.0; 
    variable Fcw                  : real    := 0.0;    
    
    variable SampleCount          : natural := 0;
    variable SampleInLastV        : std_logic := '0'; 
    
  begin
  
    OscillatorFcw <= (others => '0');
 
    loop
      wait until rising_edge(Clock);
      exit when Reset = '0';
    end loop;
    
    wait until rising_edge(SampleInReady);
    
    for ShiftIndex in 1 to N_SHIFTS loop
      
      file_open(FileIn_Q, "../../../../../test/q_in.txt", read_mode);
      file_open(FileIn_I, "../../../../../test/i_in.txt", read_mode);

      OscillatorFrequency  := real(ShiftIndex*Shift_Amount);
      Fcw                  := (1.0 * (OscillatorResolution*OscillatorFrequency) / ClockFrequency);

      OscillatorFcw      <= to_signed(integer(Fcw), FCW_BITS);
   
      while (not endfile(FileIn_Q) and not endfile(FileIn_I)) loop

        -- I
        readline(FileIn_I, FileLine_I);
        read(FileLine_I, LineValue_I);
        SampleIn_I <= to_signed(LineValue_I, SampleIn_I'length);
        --report "i_in: " & integer'image(to_integer(signed(SampleIn_I)));
        
        -- Q
        readline(FileIn_Q, FileLine_Q);
        read(FileLine_Q, LineValue_Q);
        SampleIn_Q <= to_signed(LineValue_Q, SampleIn_Q'length);
        --report "q_in: " & integer'image(to_integer(signed(SampleIn_Q)));
                        
        SampleInValid <= '1';
        
        if (SampleCount = N_SAMPLES-1) then
           SampleInLast <= '1';
           SampleInLastV := '1';
           SampleCount  := 0;
           exit;
         else
           SampleInLast <= '0';
           SampleInLastV := '0';
           SampleCount  := SampleCount+1;
         end if;
         
         wait until rising_edge(Clock);
         
     end loop; -- read loop

      file_close(FileIn_Q);
      file_close(FileIn_I);

      wait until rising_edge(Clock);      
      SampleInLast <= '0';
      
    end loop; -- step loop
    
    --wait until rising_edge(Clock);
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
 
    file     FileOut_Q   : text;
    variable FileLine_Q  : line;
    variable LineValue_Q : integer;
 
    file     FileOut_I   : text;
    variable FileLine_I  : line;
    variable LineValue_I : integer;

    variable SampleCount : natural := 0;
  begin
 
    file_open(FileOut_Q, "../../../../../test/q_out.txt", write_mode);
    file_open(FileOut_I, "../../../../../test/i_out.txt", write_mode);
    
    reset <= '1';
    wait until rising_edge(Clock);
    reset <= '0';
    wait until rising_edge(Clock);
    SampleOutReady <= '1';
    
    wait until rising_edge(SampleOutValid);
 
    loop
      
      -- I
      --report "i_out: " &   integer'image(to_integer(signed(SampleOut_I)));
      write(FileLine_I,    integer'image(to_integer(signed(SampleOut_I))));
      writeline(FileOut_I, FileLine_I);

      -- Q
      --report "q_out: " &   integer'image(to_integer(signed(SampleOut_Q)));
      write(FileLine_Q,    integer'image(to_integer(signed(SampleOut_Q))));
      writeline(FileOut_Q, FileLine_Q);
      
      wait until rising_edge(Clock);
  
      exit when SampleOutValid = '0';
    end loop;

    SampleOutReady <= '0';
  
    file_close(FileOut_Q);
    file_close(FileOut_I);
    
    wait for 10*ClockPeriod;
  
    report "write finished";
    assert false report "test done" severity failure;
    
    wait;
  end process results;

end Behavioral;