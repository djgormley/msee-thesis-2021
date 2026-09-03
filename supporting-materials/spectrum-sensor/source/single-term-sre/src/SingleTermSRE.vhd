------------------------------------------------------------------------------------------------------
--! @Author:         Dylan J. Gormley (NASA GRC/LCI0)
--! @Creation-Date:  1 November 2020
--! @Module-Name:    Single-Term Symbol Rate Estimator
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.1.3
--! @Git-Tag:        xxxx
--!
--! @Version 1.0:
--! Dylan J. Gormley (NASA GRC/LCI0) - File created.
--! @Version 2.0:
--! Anthony A. Stock (NAS/GRC-LCI0)[NIP] - Updated design to use control signals that had been added to
--!     submodules since file's initial creation. Changed rounding and truncation in submodules to 
--!     handle radix point correctly.
--!
--! @ToDo:
------------------------------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

--! @Module-Description
--! This module implements a Symbol Rate Estimator using the conjugate cyclic autocorrelation
--! function evaluated at (alpha=R_s, Tau=0).  The power of the result is then calculated.
--! Samples are input and output serially.  The result is considered to be valid when N_SAMPLES has
--! been received.  Counting of samples is not handled by this module, and must be handled by the
--! module top to this one.  SampleInLast indicates that the Nth sample has been received. The
--! output is considered valid and the module is then reset.
--!
--! Further details on Symbol Rate Estimation can be found at https://ieeexplore.ieee.org/document/6594921
entity SingleTermSRE is
  generic (
    N_SAMPLES            : natural := 2**16; --! number of samples until last
    BIT_WIDTH            : natural := 16;    --! resolution of sample
    FCW_WIDTH            : natural := 16;
    LATENCY              : natural := 2  
  );
  port (
    -- inputs
    Clock                : in  std_logic; --! synchronous
    Reset                : in  std_logic; --! asynchronous, active high

    OscillatorFcw        : in  unsigned(FCW_WIDTH-1 downto 0);
    --OverflowClear        : in  std_logic;

    SampleOutReady       : in  std_logic; --! active high
    SampleInValid        : in  std_logic; --! active high
    SampleInLast         : in  std_logic; --! active high
    
    SampleIn_I           : in  signed(BIT_WIDTH-1 downto 0);
    SampleIn_Q           : in  signed(BIT_WIDTH-1 downto 0);

    -- outputs
    OverflowStatus       : out std_logic_vector(1 downto 0);

    SampleInReady        : out std_logic; --! active high
    SampleOutValid       : out std_logic; --! active high
    SampleOutLast        : out std_logic; --! active high
    SampleOut_I          : out signed(BIT_WIDTH-1 downto 0);
    SampleOut_Q          : out signed(BIT_WIDTH-1 downto 0)
  );
end SingleTermSRE;

architecture RTL of SingleTermSRE is

  -----------------------------------------------------------------------
  -- Components
  -----------------------------------------------------------------------
  component InstantaneousPower
    generic (
      LengthA             : natural range 2 to 32 := 16;    --! number of bits in operand A.
      LengthB             : natural range 2 to 32 := 16;    --! number of bits in operand B.
      Latency             : natural range 2 to 32 := 2;     --! total cycles of latency to do an operation.
      BitstoTrunc         : natural               := 0;     --! allows the ability to trim most significant bits (without saturation!).
      BitstoRound         : natural               := 0      --! allows the ability to trim least significant bits through symmetric rounding.
    );
    port (
      -- moddule inputs
      Clock               : in  std_logic;                  --! global clock
      Reset               : in  std_logic;                  --! synchronous reset
      A_in                : in  signed(LengthA-1 downto 0); --! signed input 1
      B_in                : in  signed(LengthB-1 downto 0); --! signed input 2
      SampleInValid       : in  std_logic;                  --! input being driven into multiplier is ready to be read
      SampleInLast        : in  std_logic;                  --! marker to delineate two back-to-back sequences of inputs
      SampleOutReady      : in  std_logic;                  --! is following module ready to accept input
      
      -- Module outputs
      C_out               : out unsigned(BIT_WIDTH*2-BitstoRound-BitstoTrunc-1 downto 0);      --! max(LengthA,LengthB)*2-1-BitstoTrunc-BitstoRound downto 0); -- use max() function for full output. For the moment, reduced to 32-bit.
      SampleOutValid      : out std_logic;                  --! data on output is valid
      SampleOutLast       : out std_logic;                  --! marker to delineate two back-to-back sequences of inputs
      SampleInReady       : out std_logic                   --! tell preceding module that we're ready for input
    );
  end component;

  component SingleTermDft
    generic (
      N_SAMPLES            : natural := 2**16; --! number of samples until last
      BIT_WIDTH            : natural := 16;   --! resolution of sample
      FCW_WIDTH            : natural := 16;
      LATENCY              : natural := 2  
    );
    port (
      -- inputs
      Clock                : in  std_logic; --! synchronous clock
      Reset                : in  std_logic; --! synchronous reset
      OscillatorFcw        : in  signed(FCW_WIDTH-1 downto 0);

      SampleOutReady       : in  std_logic; --! active high
      SampleInValid        : in  std_logic; --! active high
      SampleInLast         : in  std_logic; --! active high
      SampleIn_I           : in  signed(BIT_WIDTH-1 downto 0);
      SampleIn_Q           : in  signed(BIT_WIDTH-1 downto 0);

      -- outputs
      OverflowStatus       : out std_logic_vector(1 downto 0);
      
      SampleInReady        : out std_logic; --! active high
      SampleOutValid       : out std_logic; --! active high
      SampleOutLast        : out std_logic; --! active high
      SampleOut_I          : out signed(BIT_WIDTH-1 downto 0);
      SampleOut_Q          : out signed(BIT_WIDTH-1 downto 0)
    );
  end component;

  -----------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------
  signal InstantaneousPowerOutValid : std_logic := '0'; -- intermediate signal between instantaneous_power and single_term_dft
  signal InstantaneousPowerOutLast  : std_logic := '0'; -- intermediate signal between instantaneous_power and single_term_dft

  signal DftIn_I                    : unsigned(BIT_WIDTH-1 downto 0) := (others => '0'); -- intermediate signal between InstantaneousPowerOut and single_term_dft
  signal DftIn_Q                    : unsigned(BIT_WIDTH-1 downto 0) := (others => '0');
  signal InstPowerReady             : std_logic := '0';

  -----------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------
  constant DEBUG                    : string := "true";

  -----------------------------------------------------------------------
  -- Attributes
  -----------------------------------------------------------------------
--  attribute mark_debug                               : string;
--  attribute mark_debug of Reset                      : signal is DEBUG;
--  attribute mark_debug of OscillatorFcw              : signal is DEBUG;
--  attribute mark_debug of SampleOutReady             : signal is DEBUG;
--  attribute mark_debug of SampleInValid              : signal is DEBUG;
--  attribute mark_debug of SampleInLast               : signal is DEBUG;
--  attribute mark_debug of SampleIn_I                 : signal is DEBUG;
--  attribute mark_debug of SampleIn_Q                 : signal is DEBUG;
--  attribute mark_debug of OverflowStatus             : signal is DEBUG;
--  attribute mark_debug of SampleInReady              : signal is DEBUG;
--  attribute mark_debug of SampleOutValid             : signal is DEBUG;
--  attribute mark_debug of SampleOutLast              : signal is DEBUG;
--  attribute mark_debug of SampleOut_I                : signal is DEBUG;
--  attribute mark_debug of SampleOut_Q                : signal is DEBUG;
--  attribute mark_debug of InstantaneousPowerOutValid : signal is DEBUG;
--  attribute mark_debug of InstantaneousPowerOutLast  : signal is DEBUG;
--  attribute mark_debug of DftIn_I                    : signal is DEBUG;
--  attribute mark_debug of InstPowerReady             : signal is DEBUG;

begin

  -----------------------------------------------------------------------
  -- |x[n]|^2
  -----------------------------------------------------------------------
  mag_sq : InstantaneousPower
    generic map (
      LengthA           => SampleIn_I'length,
      LengthB           => SampleIn_Q'length,
      Latency           => LATENCY,
      BitstoTrunc       => 2, -- experimentally found
      BitstoRound       => BIT_WIDTH-2
    )
    port map (
      -- module inputs
      Clock             => Clock,
      Reset             => Reset,
      A_in              => SampleIn_I,
      B_in              => SampleIn_Q,
      SampleInValid     => SampleInValid,
      SampleInLast      => SampleInLast,
      SampleOutReady    => InstPowerReady,
    
      -- module outputs
      C_out             => DftIn_I,
      SampleOutValid    => InstantaneousPowerOutValid,
      SampleOutLast     => InstantaneousPowerOutLast,
      SampleInReady     => SampleInReady
    );

  -----------------------------------------------------------------------
  -- sum[|x[n]|^2*exp(-j*2*pi*Rs/Fs*n)] from 0 to N-1
  -----------------------------------------------------------------------
  single_term_dft : SingleTermDft
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

      OscillatorFcw        => signed(OscillatorFcw),

      SampleOutReady       => SampleOutReady,
      SampleInValid        => InstantaneousPowerOutValid,
      SampleInLast         => InstantaneousPowerOutLast,
      SampleIn_I           => signed(DftIn_I),
      SampleIn_Q           => signed(DftIn_Q),

      -- outputs
      OverflowStatus       => OverflowStatus,
      
      SampleInReady        => InstPowerReady,
      SampleOutValid       => SampleOutValid,
      SampleOutLast        => SampleOutLast,
      SampleOut_I          => SampleOut_I,
      SampleOut_Q          => SampleOut_Q
  );


end rtl;
