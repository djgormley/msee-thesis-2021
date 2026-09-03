------------------------------------------------------------------------------------------------------
--! @Author:         Dylan J. Gormley (NASA GRC/LCI)
--! @Creation-Date:  1 November 2020
--! @Module-Name:    Single-Term Center Frequency Estimator Testbench
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
use work.GenericFir_pkg.all;

entity SingleTermCFE_tb is
--  port ( );
end SingleTermCFE_tb;

architecture Behavioral of SingleTermCFE_tb is

  ------------------------------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------------------------------
  component SingleTermCFE
    generic (
      N_SAMPLES          : natural := 2**8; --! number of samples until last
      BIT_WIDTH          : natural := 16    --! resolution of sample
    );
    port (
      -- inputs
      Clock              : in  std_logic; --! synchronous, active high
      Reset              : in  std_logic; --! synchronous, active high
  
      CenterFrequencyFcw : in  signed(15 downto 0);
      SymbolRateFcw      : in  signed(15 downto 0);
  
      SampleOutReady     : in  std_logic; --! active high
      SampleInValid      : in  std_logic; --! active high
      SampleInLast       : in  std_logic; --! active high
      
      SampleIn_I         : in  signed(BIT_WIDTH-1 downto 0);
      SampleIn_Q         : in  signed(BIT_WIDTH-1 downto 0);
      
      -- outputs
      SampleInReady      : out std_logic;
      OverflowStatus     : out std_logic_vector(3 downto 0); --! mixer overflow
  
      SampleOutValid   : out std_logic; --! active high
      SampleOutLast    : out std_logic; --! active high
      SampleOut        : out signed(31 downto 0)
    );
  end component;
  
  ------------------------------------------------------------------------------------------------------
  -- Constants
  ------------------------------------------------------------------------------------------------------
  constant ClockPeriod          : time    := 1.0 us;

  constant Fs                   : real    := 1.0e6; -- 1 Msample/sec
  constant BIT_WIDTH            : natural := 16;
  constant FCW_BITS             : natural := 16;
  constant OscillatorResolution : real    := real(2**FCW_BITS);
  
  constant TAP_COUNT            : natural := 2;
  constant N_SAMPLES            : natural := 2**12;
  
  constant RS_INIT              : real    := 0.1;
  constant RS_STEP              : real    := 0.1;
  constant N_RS_SHIFTS          : natural := natural(((Fs/1.0e6)/2.0)/RS_STEP);
  
  constant FC_INIT              : real    := -(Fs/1.0e6)/2.0;
  constant FC_STEP              : real    := 0.05;
  constant N_FC_SHIFTS          : natural := natural(((Fs/1.0e6))/FC_STEP) + 1;
  
  constant SIMNAME              : string  := "Baseline";
  constant SIMNUM               : natural := 1;

  ------------------------------------------------------------------------------------------------------
  -- Signals
  ------------------------------------------------------------------------------------------------------
  signal Clock                     : std_logic := '0';
  signal Reset                     : std_logic := '0';

  signal CenterFrequencyFcw        : signed(15 downto 0)     := (others => '0');
  signal SymbolRateFcw             : signed(15 downto 0)     := (others => '0');
  signal Coeffs                    : CoeffArray(TAP_COUNT-1 downto 0) := (others => (others =>  '0'));
 
  -- mixer data
  signal SampleOutReady            : std_logic := '0';
  signal SampleInValid             : std_logic := '0';
  signal SampleInLast              : std_logic := '0';
  signal SampleIn_I                : signed(BIT_WIDTH-1  downto 0) := (others => '0');
  signal SampleIn_Q                : signed(BIT_WIDTH-1  downto 0) := (others => '0');
  
  -- data out
  signal SampleInReady             : std_logic := '0';
  signal OverflowStatus            : std_logic_vector(3 downto 0) := (others => '0');
 
  signal SampleOutValid          : std_logic := '0';
  signal SampleOutLast           : std_logic := '0';
  signal SampleOut               : signed(31 downto 0) := (others => '0');

begin

  ------------------------------------------------------------------------------------------------------
  -- Unit Under Test
  ------------------------------------------------------------------------------------------------------
  uut : SingleTermCFE
    generic map(
        N_SAMPLES        => N_SAMPLES,
        BIT_WIDTH        => BIT_WIDTH
      )
    port map (
      -- inputs
      Clock              => Clock,
      Reset              => Reset,
      
      CenterFrequencyFcw => CenterFrequencyFcw,
      SymbolRateFcw      => SymbolRateFcw,

      SampleOutReady     => SampleOutReady,
      SampleInValid      => SampleInValid,
      SampleInLast       => SampleInLast,

      SampleIn_I         => SampleIn_I,
      SampleIn_Q         => SampleIn_Q,
      
      -- outputs
      SampleInReady      => SampleInReady,
      OverflowStatus     => OverflowStatus,
      
      SampleOutValid   => SampleOutValid,
      SampleOutLast    => SampleOutLast,
      SampleOut        => SampleOut
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

    file     CoeffFileIn          : text;
    variable CoeffFileLine        : line;
    variable CoeffLineValue       : integer;
   
    file     FileIn_Q             : text;
    variable FileLine_Q           : line;
    variable LineValue_Q          : integer;

    file     FileIn_I             : text;
    variable FileLine_I           : line;
    variable LineValue_I          : integer;
    
    variable Rs                   : real    := 0.0;
    variable RsFcw                : real    := 0.0;

    variable Fc                   : real    := 0.0;
    variable FcFcw                : real    := 0.0;

    variable TapCount             : natural := 0;
    variable SampleCount          : natural := 0;
    
    variable SampleInLastV        : std_logic := '0';

  begin
  
    loop
      wait until rising_edge(Clock);
      exit when Reset = '0';
    end loop;
    
    for Rs_Shift in 0 to N_RS_SHIFTS-1 loop
    
    Rs                 := (RS_INIT + RS_STEP*real(Rs_Shift)) * real(1e6);
    RsFcw              := 1.0*((OscillatorResolution-0.0)*Rs) / Fs;
    SymbolRateFcw      <= to_signed(integer(RsFcw), SymbolRateFcw'length);
    
      wait until rising_edge(Clock);
      
      ------------------------------------------------------------------------------------------------------
      -- Load Data
      ------------------------------------------------------------------------------------------------------
      for Shift in 0 to N_FC_SHIFTS-1 loop

        file_open(FileIn_I, "../../../../../test/i_in.txt", read_mode);
        file_open(FileIn_Q, "../../../../../test/q_in.txt", read_mode);


        Fc                 := (FC_INIT + FC_STEP*real(Shift))*real(1e6);
        FcFcw              := 1.0*((OscillatorResolution-0.0)*Fc)/Fs;
        CenterFrequencyFcw <= to_signed(integer(FcFcw), CenterFrequencyFcw'length);
        
        while (SampleInLastV = '0') loop
          if (SampleInReady = '1') then
            
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
            
            if (SampleCount = N_SAMPLES-1) then
               SampleInLast <= '1';
               SampleInLastv := '1';
               SampleCount  := 0;
               --exit;
            else
              SampleInLast <= '0';
              SampleInLastv := '0';
              SampleCount  := SampleCount+1;
            end if;
          end if;
          
          wait until rising_edge(Clock);
          
        end loop; -- fc loop
         
        file_close(FileIn_Q);
        file_close(FileIn_I);
        
        -- reset for next iteration     
        SampleInLastV := '0';
        SampleCount   := 0;
        SampleInLast  <= '0';
        SampleIn_I    <= (others => '0');
        SampleIn_Q    <= (others => '0');

     end loop; -- Rs loop
     
     SampleInValid <= '0';
     wait until SampleOutLast = '1';
   
   end loop;

   SampleInLast       <= '0';
   SampleInValid      <= '0';
   SampleIn_I         <= (others => '0');
   SampleIn_Q         <= (others => '0');
   SymbolRateFcw      <= (others => '0');
   CenterFrequencyFcw <= (others => '0');
    
   report "stimulus finished";
   wait until falling_edge(sampleoutvalid);
   wait for 5*ClockPeriod;
   assert false report "test done" severity failure;
   wait;
 
 end process stimulus_gen;
 
 
  -----------------------------------------------------------------------
  -- Ouput Results
  -----------------------------------------------------------------------
  results : process

 
    file     FileOut     : text;
    variable FileLine    : line;
    variable LineValue   : integer;

    variable SampleCount    : natural := 0;
    variable Rs_Num         : natural := 0;
    
  begin
  
    loop
      wait until rising_edge(Clock);
      exit when Reset = '0';
    end loop;
    
    wait until rising_edge(Clock);
    wait until rising_edge(Clock);
    wait until rising_edge(Clock);
  
    --file_open(FileOut,   "../../../../../test/tests/Experiment_" & integer'image(SIMNUM) & "--" & simName & "/" & integer'image(Rs_num) & "_out.txt",   write_mode);        -- for a single fc, many Rs's
    
    for Rs_num in 0 to N_RS_SHIFTS loop
 
      --file_open(FileOut,   "../../../../../test/tests/Experiment_" & integer'image(SIMNUM) & "--" & simName & "/" & integer'image(Rs_num) & "_out.txt",   write_mode);        -- for multiple fc's
      file_open(FileOut,   "../../../../../test/cfe_out.txt",   write_mode);

      SampleOutReady <= '1';

      loop
        -- trigger
        loop
          wait until rising_edge(Clock);
          exit when SampleOutLast = '1';
        end loop;

        
        -- Results
        --report "up_out: " &   integer'image(to_integer(signed(SampleOut)));
        write(FileLine,    integer'image(to_integer(signed(SampleOut))));
        writeline(FileOut, FileLine);
        
        SampleCount := SampleCount + 1;
 
        exit when SampleCount = N_FC_SHIFTS;
      end loop;
      
      SampleCount := 0;
      SampleOutReady <= '0';
      file_close(FileOut);    

    
    end loop;
    
    --file_close(FileOut);
    wait;
  end process results;

end Behavioral;
