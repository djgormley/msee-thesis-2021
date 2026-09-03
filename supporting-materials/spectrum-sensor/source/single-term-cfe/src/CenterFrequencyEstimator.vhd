------------------------------------------------------------------------------------------------------
--! @Author:         Dylan J. Gormley (NASA GRC/LCI0)
--! @Creation-Date:  1 November 2020
--! @Module-Name:    Single-Term Center Frequency Estimator
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.1.3
--! @Git-Tag:        xxxx
--!
--! @Version 1.0:
--! Dylan J. Gormley (NASA GRC/LCI0) - File Created.
--! 
--! @ToDo: Improve usability of generic lengths and sizes.
------------------------------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.math_real.all;

library work;
use     work.GenericFir_pkg.all;
use     work.max_pkg.all; -- must use custom max b/c Xilinx doesn't support MAXIMUM in sim

--! @Module-Description
--! This module estimates the correlation between a signal, symbol rate, and center frequency.
--! First the signal is shifted down to center the spectrum at the desired center frequency.
--! A lowpass filter is then applied with a cutoff frequency equal to the symbol rate.
--! Lastly, the Symbol Rate Estimation is performed.
--!
--! Further details on Center Frequency Estimation can be found at https://ntrs.nasa.gov/citations/20190027051
entity SingleTermCFE is
  generic (
    N_SAMPLES          : natural := 2**16;        --! number of samples
    BIT_WIDTH          : natural := 16;           --! resolution of samples
    FCW_WIDTH          : natural := 16;
    LATENCY            : natural := 2      
  );
  port (
    -- inputs
    Clock              : in  std_logic;           --! 
    Reset              : in  std_logic;           --! synchronous reset

    CenterFrequencyFcw : in  signed(FCW_WIDTH-1   downto 0); --! Fc FCW for channelizer NCO
    SymbolRateFcw      : in  unsigned(FCW_WIDTH-1 downto 0); --! Rs FCW for Rs estimator

    SampleOutReady     : in  std_logic;
    SampleInValid      : in  std_logic;
    SampleInLast       : in  std_logic;

    SampleIn_I         : in  signed(BIT_WIDTH-1 downto 0);
    SampleIn_Q         : in  signed(BIT_WIDTH-1 downto 0);

    -- outputs
    SampleInReady      : out std_logic;
    OverflowStatus     : out std_logic_vector(3 downto 0);

    SampleOutValid     : out std_logic;
    SampleOutLast      : out std_logic;
    SampleOut          : out unsigned(2*BIT_WIDTH-1 downto 0)
  );
end SingleTermCFE;

architecture RTL of SingleTermCFE is

  -----------------------------------------------------------------------
  -- Components
  -----------------------------------------------------------------------

  component InstantaneousPower
    generic (
      LengthA             : natural range 2 to 32 := 32;    --! number of bits in operand A.
      LengthB             : natural range 2 to 32 := 32;    --! number of bits in operand B.
      Latency             : natural range 2 to 32 := 2;     --! total cycles of latency to do an operation.
      BitstoTrunc         : natural               := 0;     --! allows the ability to trim most significant bits (without saturation!).
      BitstoRound         : natural               := 0      --! allows the ability to trim least significant bits through symmetric rounding.
    );
    port (
      -- module inputs
      Clock               : in  std_logic;                  --! global clock
      Reset               : in  std_logic;                  --! synchronous reset
      A_in                : in  signed(LengthA-1 downto 0); --! signed input 1
      B_in                : in  signed(LengthB-1 downto 0); --! signed input 2
      SampleInValid       : in  std_logic;                  --! input being driven into multiplier is ready to be read
      SampleInLast        : in  std_logic;                  --! marker to delineate two back-to-back sequences of inputs
      SampleOutReady      : in  std_logic;                  --! is following module rMAX accept input

      -- Module outputs
      C_out               : out unsigned(MAX(LengthA,LengthB)*2-1-BitstoTrunc-BitstoRound downto 0); -- Instantaneous Power
      SampleOutValid      : out std_logic;                  --! data on output is valid
      SampleOutLast       : out std_logic;                  --! marker to delineate two back-to-back sequences of inputs
      SampleInReady       : out std_logic                   --! tell preceding module that we're ready for input
    );
  end component;

  component Channelizer is
    generic (
      BIT_WIDTH         : natural range 8 to 32 := 16;
      TAP_COUNT         : natural   := 1;
      LUT_PHASE         : std_logic := '1';                         --! 0 if using 1/4 sin LUT, 1 if using 1/4 cos LUT
      FCW_WIDTH         : natural   := 32;
      LATENCY           : natural   := 2  
    );
    port(
      -- inputs
      Clock             :  in std_logic;                           --! system clock
      Reset             :  in std_logic;                           --! system reset
      Coeffs       	    :  in CoeffArray(TAP_COUNT-1 downto 0);    --! FIR taps
  
      OscillatorFcw     :  in signed(FCW_WIDTH-1 downto 0);        --! s.31
      SampleIn_I        :  in signed(BIT_WIDTH-1 downto 0);        --! i input
      SampleIn_Q        :  in signed(BIT_WIDTH-1 downto 0);        --! unshifted q input
  
      SampleInValid     :  in std_logic;                           --! is input valid
      SampleInLast      :  in std_logic;                           --! marker to delineate two back-to-back sequences of inputs
      SampleOutReady    :  in std_logic;                           --! is following module ready to accept input
      
      -- outputs
      OutgoingSample_I  : out signed(BIT_WIDTH-1 downto 0);        --! Two's complement sample.
      OutgoingSample_Q  : out signed(BIT_WIDTH-1 downto 0);        --! Two's complement sample.
      
      OverflowStatus    : out std_logic_vector(1 downto 0);        --! b[1]=i b[0]=q
      
      SampleOutValid    : out std_logic;                           --! Data on output is valid
      SampleOutLast     : out std_logic;                           --! marker to delineate two back-to-back sequences of inputs
      SampleInReady     : out std_logic                            --! tell preceding module that we're ready for input
    );
  end component;

  component SingleTermSRE
    generic (
      N_SAMPLES            : natural := 2**16; --! number of samples until last
      BIT_WIDTH            : natural := 16;   --! resolution of sample
      FCW_WIDTH            : natural := 16;
      LATENCY              : natural := 2  
    );
    port (
      -- inputs
      Clock                : in  std_logic; 
      Reset                : in  std_logic;

      OscillatorFcw        : in  unsigned(FCW_WIDTH-1 downto 0);

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

  -----------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------
  -- intermediate signals between SRE and Inst. Power
  signal SREOut_I                         : signed(BIT_WIDTH-1 downto 0) := (others => '0');
  signal SREOut_Q                         : signed(BIT_WIDTH-1 downto 0) := (others => '0');

  signal SreOutValid                      : std_logic := '0';
  signal SreOutLast                       : std_logic := '0';
  signal InstPwrInReady                   : std_logic := '0';

  -- intermediate signals between lowpass_filters and spectrum_estimator
  signal SreInReady                       : std_logic := '0';
  signal ChannelizerOutValid              : std_logic := '0';
  signal ChannelizerOutLast               : std_logic := '0';
  signal ChannelizerOut_I                 : signed(BIT_WIDTH-1 downto 0) := (others => '0');
  signal ChannelizerOut_Q                 : signed(BIT_WIDTH-1 downto 0) := (others => '0');

  signal OverflowStatus_channelizer       : std_logic_vector(1 downto 0) := (others => '0'); --! mixer overflow
  signal OverflowStatus_sre               : std_logic_vector(1 downto 0) := (others => '0'); --! mixer overflow
  
  -- output reg
  signal SampleOut_reg                    : unsigned(2*BIT_WIDTH-2 downto 0) := (others => '0');

  -- taps
  signal Coeffs                           : CoeffArray(TAP_COUNT-1 downto 0) := (others => (others => '0'));  
  
  -----------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------  
  constant LUT_PHASE                      : std_logic                      := '1';               --! 0 if using 1/4 sin LUT, 1 if using 1/4 cos LUT
  constant DEBUG                          : string                         := "true";
  constant N_BANKS                        : natural                        := 128;               -- must match matlab
  constant BANK_STEP                      : natural                        := 2**(BIT_WIDTH-1)/N_BANKS; -- 256

  ------------------------------------------------------------------------------------------------------
  -- Attributes
  ------------------------------------------------------------------------------------------------------
--  attribute mark_debug                                     : string;
--  attribute mark_debug of Reset                            : signal is DEBUG;
--  attribute mark_debug of CenterFrequencyFcw               : signal is DEBUG;
--  attribute mark_debug of SymbolRateFcw                    : signal is DEBUG;
--  attribute mark_debug of SampleOutReady                   : signal is DEBUG;
--  attribute mark_debug of SampleInValid                    : signal is DEBUG;
--  attribute mark_debug of SampleInLast                     : signal is DEBUG;
--  attribute mark_debug of SampleIn_I                       : signal is DEBUG;
--  attribute mark_debug of SampleIn_Q                       : signal is DEBUG;
--  attribute mark_debug of SampleInReady                    : signal is DEBUG;
--  attribute mark_debug of OverflowStatus                   : signal is DEBUG;
--  attribute mark_debug of SampleOutValid                   : signal is DEBUG;
--  attribute mark_debug of SampleOutLast                    : signal is DEBUG;
--  attribute mark_debug of SampleOut                        : signal is DEBUG;
--  attribute mark_debug of SREOut_I                         : signal is DEBUG;
--  attribute mark_debug of SREOut_Q                         : signal is DEBUG;
--  attribute mark_debug of SreOutValid                      : signal is DEBUG;
--  attribute mark_debug of SreOutLast                       : signal is DEBUG;
--  attribute mark_debug of InstPwrInReady                   : signal is DEBUG;
--  attribute mark_debug of SreInReady                       : signal is DEBUG;
--  attribute mark_debug of ChannelizerOutValid              : signal is DEBUG;
--  attribute mark_debug of ChannelizerOutLast               : signal is DEBUG;
--  attribute mark_debug of ChannelizerOut_I                 : signal is DEBUG;
--  attribute mark_debug of ChannelizerOut_Q                 : signal is DEBUG;
--  attribute mark_debug of OverflowStatus_channelizer       : signal is DEBUG;
--  attribute mark_debug of OverflowStatus_sre               : signal is DEBUG;
--  attribute mark_debug of Coeffs                           : signal is DEBUG;

begin

  -- select best filter bank for sym rate
  Coeffs <= CoeffBank_1   when SymbolRateFcw >= 0*BANK_STEP   and SymbolRateFcw <= 1*BANK_STEP-1   else
            CoeffBank_2   when SymbolRateFcw >= 1*BANK_STEP   and SymbolRateFcw <= 2*BANK_STEP-1   else
            CoeffBank_3   when SymbolRateFcw >= 2*BANK_STEP   and SymbolRateFcw <= 3*BANK_STEP-1   else
            CoeffBank_4   when SymbolRateFcw >= 3*BANK_STEP   and SymbolRateFcw <= 4*BANK_STEP-1   else
            CoeffBank_5   when SymbolRateFcw >= 4*BANK_STEP   and SymbolRateFcw <= 5*BANK_STEP-1   else
            CoeffBank_6   when SymbolRateFcw >= 5*BANK_STEP   and SymbolRateFcw <= 6*BANK_STEP-1   else
            CoeffBank_7   when SymbolRateFcw >= 6*BANK_STEP   and SymbolRateFcw <= 7*BANK_STEP-1   else
            CoeffBank_8   when SymbolRateFcw >= 7*BANK_STEP   and SymbolRateFcw <= 8*BANK_STEP-1   else
            CoeffBank_9   when SymbolRateFcw >= 8*BANK_STEP   and SymbolRateFcw <= 9*BANK_STEP-1   else
            CoeffBank_10  when SymbolRateFcw >= 9*BANK_STEP   and SymbolRateFcw <= 10*BANK_STEP-1  else
            CoeffBank_11  when SymbolRateFcw >= 10*BANK_STEP  and SymbolRateFcw <= 11*BANK_STEP-1  else
            CoeffBank_12  when SymbolRateFcw >= 11*BANK_STEP  and SymbolRateFcw <= 12*BANK_STEP-1  else
            CoeffBank_13  when SymbolRateFcw >= 12*BANK_STEP  and SymbolRateFcw <= 13*BANK_STEP-1  else
            CoeffBank_14  when SymbolRateFcw >= 13*BANK_STEP  and SymbolRateFcw <= 14*BANK_STEP-1  else
            CoeffBank_15  when SymbolRateFcw >= 14*BANK_STEP  and SymbolRateFcw <= 15*BANK_STEP-1  else
            CoeffBank_16  when SymbolRateFcw >= 15*BANK_STEP  and SymbolRateFcw <= 16*BANK_STEP-1  else
            CoeffBank_17  when SymbolRateFcw >= 16*BANK_STEP  and SymbolRateFcw <= 17*BANK_STEP-1  else
            CoeffBank_18  when SymbolRateFcw >= 17*BANK_STEP  and SymbolRateFcw <= 18*BANK_STEP-1  else
            CoeffBank_19  when SymbolRateFcw >= 18*BANK_STEP  and SymbolRateFcw <= 19*BANK_STEP-1  else
            CoeffBank_20  when SymbolRateFcw >= 19*BANK_STEP  and SymbolRateFcw <= 20*BANK_STEP-1  else
            CoeffBank_21  when SymbolRateFcw >= 20*BANK_STEP  and SymbolRateFcw <= 21*BANK_STEP-1  else
            CoeffBank_22  when SymbolRateFcw >= 21*BANK_STEP  and SymbolRateFcw <= 22*BANK_STEP-1  else
            CoeffBank_23  when SymbolRateFcw >= 22*BANK_STEP  and SymbolRateFcw <= 23*BANK_STEP-1  else
            CoeffBank_24  when SymbolRateFcw >= 23*BANK_STEP  and SymbolRateFcw <= 24*BANK_STEP-1  else
            CoeffBank_25  when SymbolRateFcw >= 24*BANK_STEP  and SymbolRateFcw <= 25*BANK_STEP-1  else
            CoeffBank_26  when SymbolRateFcw >= 25*BANK_STEP  and SymbolRateFcw <= 26*BANK_STEP-1  else
            CoeffBank_27  when SymbolRateFcw >= 26*BANK_STEP  and SymbolRateFcw <= 27*BANK_STEP-1  else
            CoeffBank_28  when SymbolRateFcw >= 27*BANK_STEP  and SymbolRateFcw <= 28*BANK_STEP-1  else
            CoeffBank_29  when SymbolRateFcw >= 28*BANK_STEP  and SymbolRateFcw <= 29*BANK_STEP-1  else
            CoeffBank_30  when SymbolRateFcw >= 29*BANK_STEP  and SymbolRateFcw <= 30*BANK_STEP-1  else
            CoeffBank_31  when SymbolRateFcw >= 30*BANK_STEP  and SymbolRateFcw <= 31*BANK_STEP-1  else
            CoeffBank_32  when SymbolRateFcw >= 31*BANK_STEP  and SymbolRateFcw <= 32*BANK_STEP-1  else
            CoeffBank_33  when SymbolRateFcw >= 32*BANK_STEP  and SymbolRateFcw <= 33*BANK_STEP-1  else
            CoeffBank_34  when SymbolRateFcw >= 33*BANK_STEP  and SymbolRateFcw <= 34*BANK_STEP-1  else
            CoeffBank_35  when SymbolRateFcw >= 34*BANK_STEP  and SymbolRateFcw <= 35*BANK_STEP-1  else
            CoeffBank_36  when SymbolRateFcw >= 35*BANK_STEP  and SymbolRateFcw <= 36*BANK_STEP-1  else
            CoeffBank_37  when SymbolRateFcw >= 36*BANK_STEP  and SymbolRateFcw <= 37*BANK_STEP-1  else
            CoeffBank_38  when SymbolRateFcw >= 37*BANK_STEP  and SymbolRateFcw <= 38*BANK_STEP-1  else
            CoeffBank_39  when SymbolRateFcw >= 38*BANK_STEP  and SymbolRateFcw <= 39*BANK_STEP-1  else
            CoeffBank_40  when SymbolRateFcw >= 39*BANK_STEP  and SymbolRateFcw <= 40*BANK_STEP-1  else
            CoeffBank_41  when SymbolRateFcw >= 40*BANK_STEP  and SymbolRateFcw <= 41*BANK_STEP-1  else
            CoeffBank_42  when SymbolRateFcw >= 41*BANK_STEP  and SymbolRateFcw <= 42*BANK_STEP-1  else
            CoeffBank_43  when SymbolRateFcw >= 42*BANK_STEP  and SymbolRateFcw <= 43*BANK_STEP-1  else
            CoeffBank_44  when SymbolRateFcw >= 43*BANK_STEP  and SymbolRateFcw <= 44*BANK_STEP-1  else
            CoeffBank_45  when SymbolRateFcw >= 44*BANK_STEP  and SymbolRateFcw <= 45*BANK_STEP-1  else
            CoeffBank_46  when SymbolRateFcw >= 45*BANK_STEP  and SymbolRateFcw <= 46*BANK_STEP-1  else
            CoeffBank_47  when SymbolRateFcw >= 46*BANK_STEP  and SymbolRateFcw <= 47*BANK_STEP-1  else
            CoeffBank_48  when SymbolRateFcw >= 47*BANK_STEP  and SymbolRateFcw <= 48*BANK_STEP-1  else
            CoeffBank_49  when SymbolRateFcw >= 48*BANK_STEP  and SymbolRateFcw <= 49*BANK_STEP-1  else
            CoeffBank_50  when SymbolRateFcw >= 49*BANK_STEP  and SymbolRateFcw <= 50*BANK_STEP-1  else
            CoeffBank_51  when SymbolRateFcw >= 50*BANK_STEP  and SymbolRateFcw <= 51*BANK_STEP-1  else
            CoeffBank_52  when SymbolRateFcw >= 51*BANK_STEP  and SymbolRateFcw <= 52*BANK_STEP-1  else
            CoeffBank_53  when SymbolRateFcw >= 52*BANK_STEP  and SymbolRateFcw <= 53*BANK_STEP-1  else
            CoeffBank_54  when SymbolRateFcw >= 53*BANK_STEP  and SymbolRateFcw <= 54*BANK_STEP-1  else
            CoeffBank_55  when SymbolRateFcw >= 54*BANK_STEP  and SymbolRateFcw <= 55*BANK_STEP-1  else
            CoeffBank_56  when SymbolRateFcw >= 55*BANK_STEP  and SymbolRateFcw <= 56*BANK_STEP-1  else
            CoeffBank_57  when SymbolRateFcw >= 56*BANK_STEP  and SymbolRateFcw <= 57*BANK_STEP-1  else
            CoeffBank_58  when SymbolRateFcw >= 57*BANK_STEP  and SymbolRateFcw <= 58*BANK_STEP-1  else
            CoeffBank_59  when SymbolRateFcw >= 58*BANK_STEP  and SymbolRateFcw <= 59*BANK_STEP-1  else
            CoeffBank_60  when SymbolRateFcw >= 59*BANK_STEP  and SymbolRateFcw <= 60*BANK_STEP-1  else
            CoeffBank_61  when SymbolRateFcw >= 60*BANK_STEP  and SymbolRateFcw <= 61*BANK_STEP-1  else
            CoeffBank_62  when SymbolRateFcw >= 61*BANK_STEP  and SymbolRateFcw <= 62*BANK_STEP-1  else
            CoeffBank_63  when SymbolRateFcw >= 62*BANK_STEP  and SymbolRateFcw <= 63*BANK_STEP-1  else
            CoeffBank_64  when SymbolRateFcw >= 63*BANK_STEP  and SymbolRateFcw <= 64*BANK_STEP-1  else
            CoeffBank_65  when SymbolRateFcw >= 64*BANK_STEP  and SymbolRateFcw <= 65*BANK_STEP-1  else
            CoeffBank_66  when SymbolRateFcw >= 65*BANK_STEP  and SymbolRateFcw <= 66*BANK_STEP-1  else
            CoeffBank_67  when SymbolRateFcw >= 66*BANK_STEP  and SymbolRateFcw <= 67*BANK_STEP-1  else
            CoeffBank_68  when SymbolRateFcw >= 67*BANK_STEP  and SymbolRateFcw <= 68*BANK_STEP-1  else
            CoeffBank_69  when SymbolRateFcw >= 68*BANK_STEP  and SymbolRateFcw <= 69*BANK_STEP-1  else
            CoeffBank_70  when SymbolRateFcw >= 69*BANK_STEP  and SymbolRateFcw <= 70*BANK_STEP-1  else
            CoeffBank_71  when SymbolRateFcw >= 70*BANK_STEP  and SymbolRateFcw <= 71*BANK_STEP-1  else
            CoeffBank_72  when SymbolRateFcw >= 71*BANK_STEP  and SymbolRateFcw <= 72*BANK_STEP-1  else
            CoeffBank_73  when SymbolRateFcw >= 72*BANK_STEP  and SymbolRateFcw <= 73*BANK_STEP-1  else
            CoeffBank_74  when SymbolRateFcw >= 73*BANK_STEP  and SymbolRateFcw <= 74*BANK_STEP-1  else
            CoeffBank_75  when SymbolRateFcw >= 74*BANK_STEP  and SymbolRateFcw <= 75*BANK_STEP-1  else
            CoeffBank_76  when SymbolRateFcw >= 75*BANK_STEP  and SymbolRateFcw <= 76*BANK_STEP-1  else
            CoeffBank_77  when SymbolRateFcw >= 76*BANK_STEP  and SymbolRateFcw <= 77*BANK_STEP-1  else
            CoeffBank_78  when SymbolRateFcw >= 77*BANK_STEP  and SymbolRateFcw <= 78*BANK_STEP-1  else
            CoeffBank_79  when SymbolRateFcw >= 78*BANK_STEP  and SymbolRateFcw <= 79*BANK_STEP-1  else
            CoeffBank_80  when SymbolRateFcw >= 79*BANK_STEP  and SymbolRateFcw <= 80*BANK_STEP-1  else
            CoeffBank_81  when SymbolRateFcw >= 80*BANK_STEP  and SymbolRateFcw <= 81*BANK_STEP-1  else
            CoeffBank_82  when SymbolRateFcw >= 81*BANK_STEP  and SymbolRateFcw <= 82*BANK_STEP-1  else
            CoeffBank_83  when SymbolRateFcw >= 82*BANK_STEP  and SymbolRateFcw <= 83*BANK_STEP-1  else
            CoeffBank_84  when SymbolRateFcw >= 83*BANK_STEP  and SymbolRateFcw <= 84*BANK_STEP-1  else
            CoeffBank_85  when SymbolRateFcw >= 84*BANK_STEP  and SymbolRateFcw <= 85*BANK_STEP-1  else
            CoeffBank_86  when SymbolRateFcw >= 85*BANK_STEP  and SymbolRateFcw <= 86*BANK_STEP-1  else
            CoeffBank_87  when SymbolRateFcw >= 86*BANK_STEP  and SymbolRateFcw <= 87*BANK_STEP-1  else
            CoeffBank_88  when SymbolRateFcw >= 87*BANK_STEP  and SymbolRateFcw <= 88*BANK_STEP-1  else
            CoeffBank_89  when SymbolRateFcw >= 88*BANK_STEP  and SymbolRateFcw <= 89*BANK_STEP-1  else
            CoeffBank_90  when SymbolRateFcw >= 89*BANK_STEP  and SymbolRateFcw <= 90*BANK_STEP-1  else
            CoeffBank_91  when SymbolRateFcw >= 90*BANK_STEP  and SymbolRateFcw <= 91*BANK_STEP-1  else
            CoeffBank_92  when SymbolRateFcw >= 91*BANK_STEP  and SymbolRateFcw <= 92*BANK_STEP-1  else
            CoeffBank_93  when SymbolRateFcw >= 92*BANK_STEP  and SymbolRateFcw <= 93*BANK_STEP-1  else
            CoeffBank_94  when SymbolRateFcw >= 93*BANK_STEP  and SymbolRateFcw <= 94*BANK_STEP-1  else
            CoeffBank_95  when SymbolRateFcw >= 94*BANK_STEP  and SymbolRateFcw <= 95*BANK_STEP-1  else
            CoeffBank_96  when SymbolRateFcw >= 95*BANK_STEP  and SymbolRateFcw <= 96*BANK_STEP-1  else
            CoeffBank_97  when SymbolRateFcw >= 96*BANK_STEP  and SymbolRateFcw <= 97*BANK_STEP-1  else
            CoeffBank_98  when SymbolRateFcw >= 97*BANK_STEP  and SymbolRateFcw <= 98*BANK_STEP-1  else
            CoeffBank_99  when SymbolRateFcw >= 98*BANK_STEP  and SymbolRateFcw <= 99*BANK_STEP-1  else
            CoeffBank_100 when SymbolRateFcw >= 99*BANK_STEP  and SymbolRateFcw <= 100*BANK_STEP-1 else
            CoeffBank_101 when SymbolRateFcw >= 100*BANK_STEP and SymbolRateFcw <= 101*BANK_STEP-1 else
            CoeffBank_102 when SymbolRateFcw >= 101*BANK_STEP and SymbolRateFcw <= 102*BANK_STEP-1 else
            CoeffBank_103 when SymbolRateFcw >= 102*BANK_STEP and SymbolRateFcw <= 103*BANK_STEP-1 else
            CoeffBank_104 when SymbolRateFcw >= 103*BANK_STEP and SymbolRateFcw <= 104*BANK_STEP-1 else
            CoeffBank_105 when SymbolRateFcw >= 104*BANK_STEP and SymbolRateFcw <= 105*BANK_STEP-1 else
            CoeffBank_106 when SymbolRateFcw >= 105*BANK_STEP and SymbolRateFcw <= 106*BANK_STEP-1 else
            CoeffBank_107 when SymbolRateFcw >= 106*BANK_STEP and SymbolRateFcw <= 107*BANK_STEP-1 else
            CoeffBank_108 when SymbolRateFcw >= 107*BANK_STEP and SymbolRateFcw <= 108*BANK_STEP-1 else
            CoeffBank_109 when SymbolRateFcw >= 108*BANK_STEP and SymbolRateFcw <= 109*BANK_STEP-1 else
            CoeffBank_110 when SymbolRateFcw >= 109*BANK_STEP and SymbolRateFcw <= 110*BANK_STEP-1 else
            CoeffBank_111 when SymbolRateFcw >= 110*BANK_STEP and SymbolRateFcw <= 111*BANK_STEP-1 else
            CoeffBank_112 when SymbolRateFcw >= 111*BANK_STEP and SymbolRateFcw <= 112*BANK_STEP-1 else
            CoeffBank_113 when SymbolRateFcw >= 112*BANK_STEP and SymbolRateFcw <= 113*BANK_STEP-1 else
            CoeffBank_114 when SymbolRateFcw >= 113*BANK_STEP and SymbolRateFcw <= 114*BANK_STEP-1 else
            CoeffBank_115 when SymbolRateFcw >= 114*BANK_STEP and SymbolRateFcw <= 115*BANK_STEP-1 else
            CoeffBank_116 when SymbolRateFcw >= 115*BANK_STEP and SymbolRateFcw <= 116*BANK_STEP-1 else
            CoeffBank_117 when SymbolRateFcw >= 116*BANK_STEP and SymbolRateFcw <= 117*BANK_STEP-1 else
            CoeffBank_118 when SymbolRateFcw >= 117*BANK_STEP and SymbolRateFcw <= 118*BANK_STEP-1 else
            CoeffBank_119 when SymbolRateFcw >= 118*BANK_STEP and SymbolRateFcw <= 119*BANK_STEP-1 else
            CoeffBank_120 when SymbolRateFcw >= 119*BANK_STEP and SymbolRateFcw <= 120*BANK_STEP-1 else
            CoeffBank_121 when SymbolRateFcw >= 120*BANK_STEP and SymbolRateFcw <= 121*BANK_STEP-1 else
            CoeffBank_122 when SymbolRateFcw >= 121*BANK_STEP and SymbolRateFcw <= 122*BANK_STEP-1 else
            CoeffBank_123 when SymbolRateFcw >= 122*BANK_STEP and SymbolRateFcw <= 123*BANK_STEP-1 else
            CoeffBank_124 when SymbolRateFcw >= 123*BANK_STEP and SymbolRateFcw <= 124*BANK_STEP-1 else
            CoeffBank_125 when SymbolRateFcw >= 124*BANK_STEP and SymbolRateFcw <= 125*BANK_STEP-1 else
            CoeffBank_126 when SymbolRateFcw >= 125*BANK_STEP and SymbolRateFcw <= 126*BANK_STEP-1 else
            CoeffBank_127 when SymbolRateFcw >= 126*BANK_STEP and SymbolRateFcw <= 127*BANK_STEP-1 else
            CoeffBank_128 when SymbolRateFcw >= 127*BANK_STEP and SymbolRateFcw <= 128*BANK_STEP-1 else
            CoeffBank_128; -- all pass




  channelizer_inst : Channelizer
    generic map (
      BIT_WIDTH          => BIT_WIDTH,
      TAP_COUNT	         => TAP_COUNT,
      LUT_PHASE          => LUT_PHASE,
      FCW_WIDTH          => FCW_WIDTH,
      LATENCY            => LATENCY   
    )
    port map (
      Clock             => Clock,
      Reset             => Reset,
      Coeffs    	    => Coeffs,

      OscillatorFCW     => CenterFrequencyFcw,
      SampleIn_I        => SampleIn_I,
      SampleIn_Q        => SampleIn_Q,

      SampleInValid     => SampleInValid,
      SampleInLast      => SampleInLast,
      SampleOutReady    => SreInReady,

      OutgoingSample_I  => ChannelizerOut_I,
      OutgoingSample_Q  => ChannelizerOut_Q,
      
      OverflowStatus    => OverflowStatus_channelizer,
      
      SampleOutValid    => ChannelizerOutValid,
      SampleOutLast     => ChannelizerOutLast,
      SampleInReady     => SampleInReady
    );

  sre_upshift : SingleTermSRE
    generic map (
      N_SAMPLES            => N_SAMPLES,
      BIT_WIDTH            => BIT_WIDTH,
      FCW_WIDTH            => FCW_WIDTH,
      LATENCY              => LATENCY
     )
    port map (
      -- inputs
      Clock                => Clock,
      Reset                => Reset,
      OscillatorFcw        => SymbolRateFcw,

      SampleOutReady       => InstPwrInReady,
      SampleInValid        => ChannelizerOutValid,
      SampleInLast         => ChannelizerOutLast,
      SampleIn_I           => ChannelizerOut_I,
      SampleIn_Q           => ChannelizerOut_Q,

      -- outputs
      OverflowStatus       => OverflowStatus_sre,

      SampleInReady        => SreInReady,
      SampleOutValid       => SreOutValid,
      SampleOutLast        => SreOutLast,
      SampleOut_I          => SREOut_I,
      SampleOut_Q          => SREOut_Q
    );

  OverflowStatus <= OverflowStatus_Channelizer & OverflowStatus_sre;

  -----------------------------------------------------------------------
  -- |sum[|x[n]|^2*exp(-j*2*pi*Rs/Fs*n)]|^2 from 0 to N-1
  -----------------------------------------------------------------------
  spec_est : InstantaneousPower
    generic map (
      LengthA           => SampleIn_I'length,
      LengthB           => SampleIn_Q'length,
      Latency           => LATENCY,
      BitstoTrunc       => 1,
      BitstoRound       => 0
    )
    port map (
      -- module inputs
      Clock             => Clock,
      Reset             => Reset,

      A_in              => SREOut_I,
      B_in              => SREOut_Q,
      SampleInValid     => SreOutValid,
      SampleInLast      => SreOutLast,
      SampleOutReady    => SampleOutReady,

      -- module outputs
      C_out             => SampleOut_reg,
      SampleOutValid    => SampleOutValid,
      SampleOutLast     => SampleOutLast,
      SampleInReady     => InstPwrInReady
    );
   
   SampleOut <= resize(SampleOut_reg, SampleOut'length);
   
end RTL;
