------------------------------------------------------------------------------------------------------
--! @Author:         Dylan J. Gormley (NASA GRC-LCI0)
--! @Creation-Date:  17 April 2021
--! @Module-Name:    Single-Term Center Frequency Detector
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.1.3
--! @Git-Tag:        xxxx
--! 
--! @Version 1.0:
--! Dylan J. Gormley (NASA GRC-LCI0) - File created.
--! @Version 1.1:
--! Dylan J. Gormley (NASA GRC-LCI0) - Moved threshold into its own module.
--! @Version 1.2:
--! Dylan J. Gormley (NASA GRC-LCI0) - Rewrote entire module to make timing clearer.  
--!
--! @ToDo: Remove dependence on GenericFir_Pkg.
------------------------------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.std_logic_misc.all;

library work;
use     work.genericfir_pkg.all;

--! @Module-Description
--! This module uses an instance of the Center Frequency Estimator to sweep across the center frequency
--! search space from -Fs/2 to Fs/2 in a user-defined step size. The sweep is performed for a single
--! value of alpha, the variable corresponding to the Symbol Rate axis of the Rs/fc autocorrelogram.
entity CenterFrequencyDetector is
  generic (
    N_SAMPLES          : natural := 2**16;         --! number of samples
    BIT_WIDTH          : natural := 16;            --! resolution of samples
    FCW_WIDTH          : natural := 16;            --! resolution of fcw 
    LATENCY            : natural := 2              --! size depends on bit width
  );
  port (
    -- inputs
    Clock              : in  std_logic;
    Reset              : in  std_logic; --! synchronous, active high

    FcStep             : in  unsigned(FCW_WIDTH-1 downto 0); --! FC_FCW step size
    SymbolRateFcw      : in  unsigned(FCW_WIDTH-1 downto 0); --! Rs FCW
    SymbolRateValid    : in  std_logic;                      --! Rs Valid

    SampleOutReady     : in  std_logic; --! active high
    SampleInValid      : in  std_logic; --! active high
    SampleInLast       : in  std_logic; --! active high

    SampleIn_I         : in  signed(BIT_WIDTH-1 downto 0); --! Incoming I sample
    SampleIn_Q         : in  signed(BIT_WIDTH-1 downto 0); --! Incoming Q sample

    -- outputs
    SampleInReady      : out std_logic; --! active high
    OverflowStatus     : out std_logic_vector(3 downto 0); --! mixer overflow, asynchronous
    SymbolRateFcwReady : out std_logic; --! active high

    SampleOutValid     : out std_logic; --! active high
    SampleOutLast      : out std_logic; --! active high    
    
    Rs_detected        : out unsigned(FCW_WIDTH-1 downto 0); -- FCW of detected Rs
    Fc_detected        : out   signed(FCW_WIDTH-1 downto 0); -- FCW of detected Fc
    Peak_Value         : out unsigned(BIT_WIDTH-1 downto 0)  -- correlation factor
  );
end CenterFrequencyDetector;

architecture Behavioral of CenterFrequencyDetector is

    -----------------------------------------------------------------------
    -- Components
    -----------------------------------------------------------------------
    component SingleTermCFE
      generic (
        N_SAMPLES          : natural := 2**16;        --! number of samples until last
        BIT_WIDTH          : natural := 16;           --! resolution of sample
        FCW_WIDTH          : natural := 16;
        LATENCY            : natural := 2  
      );
      port (
        -- inputs
        Clock              : in  std_logic;
        Reset              : in  std_logic;
    
        CenterFrequencyFcw : in    signed(FCW_WIDTH-1 downto 0);
        SymbolRateFcw      : in  unsigned(FCW_WIDTH-1 downto 0);
    
        SampleOutReady     : in  std_logic; --! active high
        SampleInValid      : in  std_logic; --! active high
        SampleInLast       : in  std_logic; --! active high
    
        SampleIn_I         : in  signed(BIT_WIDTH-1 downto 0);
        SampleIn_Q         : in  signed(BIT_WIDTH-1 downto 0);
    
        -- outputs
        SampleInReady      : out std_logic;
        OverflowStatus     : out std_logic_vector(3 downto 0); --! mixer overflow
    
        SampleOutValid     : out std_logic; --! active high
        SampleOutLast      : out std_logic; --! active high
        SampleOut          : out unsigned(2*BIT_WIDTH-1 downto 0)
      );
    end component;
    
    -----------------------------------------------------------------------
    -- Signals
    -----------------------------------------------------------------------
    
    -- SIL = SampleInLast:   (in) marks the end of a sequence of incoming samples
    -- SIV = SampleInValid:  (in) are incoming signals valid
    -- SOR = SampleOutReady: (in) is downstream module ready to accept input
    -- SOL = SampleOutLast:  (out) marks the end of a sequence of outgoing samples
    -- SOV = SampleOutValid: (out) are outgoing samples valid
    -- SIR = SampleInReady:  (out) is module ready to accept input from upstream module
    
    -- only allow these to change with each Rs
    signal FcStep_reg             : unsigned(FCW_WIDTH-1 downto 0) := (others => '0'); --! FC_FCW step size
    signal SymbolRateFcw_reg      : unsigned(FCW_WIDTH-1 downto 0) := (others => '0'); --! Rs FCW
    signal SymbolRateFcwReady_reg : std_logic                      := '1';
    signal FcFcw_reg              : signed(FCW_WIDTH-1 downto 0)   := x"8" & (FCW_WIDTH-5 downto 0 => '0'); --x"80000000"; -- Center Frequency FCW (as opposed to Rs FCW). Start at -Fs/2
    
    -- delay these to align with fcw
    signal SampleIn_I_reg         : signed(BIT_WIDTH-1 downto 0)   := (others => '0'); -- Incoming I sample
    signal SampleIn_Q_reg         : signed(BIT_WIDTH-1 downto 0)   := (others => '0'); -- Incoming Q sample
    signal SampleOutReady_reg     : std_logic                      := '0'; --! active high
    signal SampleInValid_reg      : std_logic                      := '0'; --! active high
    signal SampleInLast_reg       : std_logic                      := '0'; --! active high
    
    -- delayed versions of the stored inputs
    signal FcStep_prev            : unsigned(FCW_WIDTH-1 downto 0) := (others => '0'); --! FC_FCW step size
    signal SymbolRateFcw_prev     : unsigned(FCW_WIDTH-1 downto 0) := (others => '0'); --! Rs FCW
    signal FcFcw_prev             : signed(FCW_WIDTH-1 downto 0)   := x"8" & (FCW_WIDTH-5 downto 0 => '0'); --x"8000"; -- Center Frequency FCW (as opposed to Rs FCW). Start at -Fs/2
    
    -- intermit signals
    signal SOV_CFE                : std_logic                        := '0';
    signal SOL_CFE                : std_logic                        := '0';
    signal SampleOut_CFE          : unsigned(2*BIT_WIDTH-1 downto 0) := (others => '0');
    
    -- thresh logic
    signal PeakValue_reg          : unsigned(2*BIT_WIDTH-1 downto 0) := (others => '0');
    signal PeakFcw_reg            : signed(BIT_WIDTH-1 downto 0)     := (others => '0');
    signal PeakValue_prev         : unsigned(2*BIT_WIDTH-1 downto 0) := (others => '0');
    signal PeakFcw_prev           : signed(BIT_WIDTH-1 downto 0)     := (others => '0');
    signal SampleOutValid_reg     : std_logic                        := '0';
    signal SampleOutLast_reg      : std_logic                        := '0';
    
    -- wait until next frame
    signal SYNCING                : std_logic                        := '0';
    
    ------------------------------------------------------------------------------------------------------
    -- constants
    ------------------------------------------------------------------------------------------------------
    constant DEBUG                                : string       := "true";
    
    --------------------------------------------------------------------------------------------------------
    ---- Attributes
    --------------------------------------------------------------------------------------------------------
    --attribute mark_debug                           : string;
    --attribute mark_debug of Reset                  : signal is DEBUG;
    --attribute mark_debug of FcStep                 : signal is DEBUG;
    --attribute mark_debug of SymbolRateFcw          : signal is DEBUG;
    --attribute mark_debug of SymbolRateValid        : signal is DEBUG;
    --attribute mark_debug of SampleOutReady         : signal is DEBUG;
    --attribute mark_debug of SampleInValid          : signal is DEBUG;
    --attribute mark_debug of SampleInLast           : signal is DEBUG;
    --attribute mark_debug of SampleIn_I             : signal is DEBUG;
    --attribute mark_debug of SampleIn_Q             : signal is DEBUG;
    --attribute mark_debug of SampleInReady          : signal is DEBUG;
    --attribute mark_debug of OverflowStatus         : signal is DEBUG;
    --attribute mark_debug of SymbolRateFcwReady     : signal is DEBUG;
    --attribute mark_debug of SampleOutValid         : signal is DEBUG;
    --attribute mark_debug of SampleOutLast          : signal is DEBUG;
    --attribute mark_debug of Rs_detected            : signal is DEBUG;
    --attribute mark_debug of Fc_detected            : signal is DEBUG;
    --attribute mark_debug of Peak_Value             : signal is DEBUG;
    --attribute mark_debug of FcStep_reg             : signal is DEBUG;
    --attribute mark_debug of SymbolRateFcw_reg      : signal is DEBUG;
    --attribute mark_debug of SymbolRateFcwReady_reg : signal is DEBUG;
    --attribute mark_debug of FcFcw_reg              : signal is DEBUG;
    --attribute mark_debug of SampleIn_I_reg         : signal is DEBUG;
    --attribute mark_debug of SampleIn_Q_reg         : signal is DEBUG;
    --attribute mark_debug of SampleOutReady_reg     : signal is DEBUG;
    --attribute mark_debug of SampleInValid_reg      : signal is DEBUG;
    --attribute mark_debug of SampleInLast_reg       : signal is DEBUG;
    --attribute mark_debug of FcStep_prev            : signal is DEBUG;
    --attribute mark_debug of SymbolRateFcw_prev     : signal is DEBUG;
    --attribute mark_debug of FcFcw_prev             : signal is DEBUG;
    --attribute mark_debug of SOV_CFE                : signal is DEBUG;
    --attribute mark_debug of SOL_CFE                : signal is DEBUG;
    --attribute mark_debug of SampleOut_CFE          : signal is DEBUG;
    --attribute mark_debug of PeakValue_reg          : signal is DEBUG;
    --attribute mark_debug of PeakFcw_reg            : signal is DEBUG;
    --attribute mark_debug of PeakValue_prev         : signal is DEBUG;
    --attribute mark_debug of PeakFcw_prev           : signal is DEBUG;
    --attribute mark_debug of SampleOutValid_reg     : signal is DEBUG;
    --attribute mark_debug of SampleOutLast_reg      : signal is DEBUG;
    --attribute mark_debug of SYNCING                : signal is DEBUG;

begin ---------------------------------------------------------------------------------------------

    SymbolRateFcwReady_reg <= '0' when ?? (SymbolRateValid or SYNCING or Reset) or (FcFcw_reg /= (x"8" & (FCW_WIDTH-5 downto 0 => '0'))) else '1';
    SymbolRateFcwReady     <= SymbolRateFcwReady_reg;
    
    -- when starting a new Rs to evaluate, register all values to prevent mid sequence changes
    fcw_in: process(all)
    begin
        if rising_edge(Clock) then
            if Reset then
                FcStep_reg             <= (others => '0');
                SymbolRateFcw_reg      <= (others => '0');
                SYNCING                <= '0';
            elsif not SYNCING then
                -- we safely know this sequence indicated the processing of a new Rs
                if FcFcw_reg = (x"8" & (FCW_WIDTH-5 downto 0 => '0')) then
                    if SymbolRateValid then
                        FcStep_reg             <= FcStep;
                        SymbolRateFcw_reg      <= SymbolRateFcw;
                        SYNCING                <= '1';
                    else -- SymbolRateValid = '0'
                        SymbolRateFcw_reg  <= (others => '0');
                    end if; -- valid
                end if;
            -- hold these values until the next block of N_SAMPLES
            elsif SYNCING and SampleInLast_reg then
                SYNCING <= '0';
            end if; -- rst
        end if; -- clk
    end process fcw_in;
    
    -- delay these by one to account for registering of FcStep, SymRate, Thresh...
    ctrl: process(all)
    begin
        if rising_edge(Clock) then
            if Reset then        
              SampleIn_I_reg         <= (others => '0');
              SampleIn_Q_reg         <= (others => '0');
              SampleOutReady_reg     <= '0';
              SampleInValid_reg      <= '0';
              SampleInLast_reg       <= '0';
            else
              SampleIn_I_reg         <= SampleIn_I;         
              SampleIn_Q_reg         <= SampleIn_Q;         
              SampleOutReady_reg     <= SampleOutReady;     
              SampleInValid_reg      <= SampleInValid;      
              SampleInLast_reg       <= SampleInLast;
            end if; -- rst
         end if; -- clk
    end process ctrl;       
    
    -- now that we've frozen our values, we count our valid samples in
    -- however, we reset our count to zero when we hit N-1
    step: process(all)
    begin
        if rising_edge(Clock) then
            if Reset then
              FcFcw_reg    <= x"8" & (FCW_WIDTH-5 downto 0 => '0');
            elsif SampleInValid_reg and SampleInLast_reg then               
              -- whenever the sample counter hits N, it's time to increment to the next FcFcw
              -- however, if FcFcw hit's the end of its possible values, that's the end of FcFcw's for that Rs                
              if FcFcw_reg > 0 and FcFcw_reg+signed(FcStep_reg) < 0 then
                  FcFcw_reg <= x"8" & (FCW_WIDTH-5 downto 0 => '0'); -- reset
              else
                  FcFcw_reg <= FcFcw_reg+signed(FcStep_reg); -- step
              end if; -- fcw cnt
            end if; -- rst
        end if; -- clk
    end process step;
    
    cfe_inst : SingleTermCFE
      generic map (
        N_SAMPLES          => N_SAMPLES,
        BIT_WIDTH          => BIT_WIDTH,
        FCW_WIDTH          => FCW_WIDTH,
        LATENCY            => LATENCY
      )
      port map ( 
        -- input
        Clock              => Clock,
        Reset              => Reset,
    
        CenterFrequencyFcw => FcFcw_reg,
        SymbolRateFcw      => SymbolRateFcw_reg,
    
        SampleOutReady     => SampleOutReady_reg,
        SampleInValid      => SampleInValid_reg,
        SampleInLast       => SampleInLast_reg,
    
        SampleIn_I         => SampleIn_I_reg,
        SampleIn_Q         => SampleIn_Q_reg,
    
        -- output
        SampleInReady      => SampleInReady,
        OverflowStatus     => OverflowStatus,
    
        SampleOutValid     => SOV_CFE,
        SampleOutLast      => SOL_CFE,
        SampleOut          => SampleOut_CFE
      );
    
    -- Having the output keep track of it's own values prevents cases where values are misaligned/skipped
    -- when processing takes much longer than the data is being input (e.g. FcStep and N are both small)
    fcw_out: process(all)
    begin
        if rising_edge(Clock) then
            if Reset then
                FcStep_prev        <= (others => '0');
                SymbolRateFcw_prev <= (others => '0');
            -- we safely know this sequence indicated the processing of a new Rs
            elsif FcFcw_prev = x"8" & (FCW_WIDTH-5 downto 0 => '0') then
                FcStep_prev        <= FcStep_reg;
                SymbolRateFcw_prev <= SymbolRateFcw_reg;
            end if; -- rst
        end if; -- clk
    end process fcw_out;
    
    -- the output of the FCE/FIR uses old values that the generator isn't tracking anymore,
    -- so we need to track them seperately here
    -- these update when SampleOut is valid
    -- we will increment the delayed values every time there's a valid output
    detect: process(all)
    begin
        if rising_edge(Clock) then
            if Reset then      
              PeakValue_reg       <= (others => '0');
              PeakFcw_reg         <= (others => '0');
              FcFcw_prev          <= x"8" & (FCW_WIDTH-5 downto 0 => '0');
              PeakValue_prev      <= (others => '0'); -- reset
              PeakFcw_prev        <= (others => '0'); -- reset          
              SampleOutValid_reg  <= '0';
              SampleOutLast_reg   <= '0';          
            -- whenever SOL hits 1, it's time to increment the delayed FcFcw
            elsif SOV_CFE and SOL_CFE then
                -- when sampleoutvalid is thrown high these values haave already move on, so we delay them
                PeakValue_prev      <= PeakValue_reg;
                PeakFcw_prev        <= PeakFcw_reg;
   
                -- if FcFcw hit's the end of its possible values, that's the end of delayed FcFcw's for that Rs                
                if FcFcw_prev > 0 and FcFcw_prev+signed(FcStep_prev) < 0 then                                  
                    SampleOutValid_reg <= '1';
                    SampleOutLast_reg <= '1';
    
                    FcFcw_prev    <= x"8" & (FCW_WIDTH-5 downto 0 => '0'); -- reset
                    PeakValue_reg <= (others => '0'); -- reset
                    PeakFcw_reg   <= (others => '0'); -- reset
                else
                    FcFcw_prev         <= FcFcw_prev+signed(FcStep_prev);
                    SampleOutValid_reg <= '0';
                    SampleOutLast_reg  <= '0';                
                    
                    -- when changing fcws, only store the largest value
                    if SampleOut_CFE >= PeakValue_reg then
                        PeakValue_reg <= SampleOut_CFE;
                        PeakFcw_reg   <= FcFcw_prev;
                    end if; -- peak
                end if; -- fcw cnt
             else
                 SampleOutValid_reg <= '0';
                 SampleOutLast_reg  <= '0';
            end if; -- rst
        end if; -- clk
    end process detect;
    
    -- output 
    outs: process(all) 
    begin
        if rising_edge(Clock) then
            if Reset then
              Rs_detected        <= (others => '0');
              Fc_detected        <= (others => '0');
              Peak_Value         <= (others => '0');
           else
              Rs_detected        <= SymbolRateFcw_prev;
              Fc_detected        <= PeakFcw_prev;
              Peak_Value         <= PeakValue_prev(PeakValue_prev'high downto Peak_Value'length);
            end if; -- rst
        end if; -- clk
    end process outs;
    
    SampleOutValid <= SampleOutValid_reg;
    SampleOutLast  <= SampleOutLast_reg;
    
end Behavioral;
