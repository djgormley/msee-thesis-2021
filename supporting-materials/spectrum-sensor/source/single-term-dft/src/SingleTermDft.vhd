------------------------------------------------------------------------------------------------------
--! @Author:         Dylan J. Gormley (NASA GRC/LCI)
--! @Creation-Date:  1 November 2020
--! @Module-Name:    Single-Term Discrete Fourier Transform
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.2.1
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
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! @Module-Description
--! This module produces a single coeffecient for the Discrete Fourier Transform.
--! Definition a single term of the DFT: X_k = sum[x_n*exp(-j2pikn/N)] for 0 to N-1.
--! This equation is accomplished by creating a local oscillator for exp(-j2pikn/N),
--! using a complex multiply for element-wise multiplication with x_n, and finally
--! an accumulator to accomplish the summation.

entity SingleTermDft is
  generic (
    N_SAMPLES      : natural := 2**16;
    BIT_WIDTH      : natural := 16;
    FCW_WIDTH      : natural := 16;
    LATENCY        : natural := 2  
  );
  port (
    -- inputs
    Clock          : in  std_logic;
    Reset          : in  std_logic;
    OscillatorFcw  : in  signed(FCW_WIDTH-1 downto 0);

    SampleOutReady : in  std_logic;
    SampleInValid  : in  std_logic;
    SampleInLast   : in  std_logic;
    SampleIn_I     : in  signed(BIT_WIDTH-1 downto 0);
    SampleIn_Q     : in  signed(BIT_WIDTH-1 downto 0);

    -- outputs
    OverflowStatus : out std_logic_vector(1 downto 0);
    SampleInReady  : out std_logic;
    SampleOutValid : out std_logic;
    SampleOutLast  : out std_logic;
    SampleOut_I    : out signed(BIT_WIDTH-1 downto 0);
    SampleOut_Q    : out signed(BIT_WIDTH-1 downto 0)
  );
end SingleTermDft;

architecture rtl of SingleTermDft is

  ------------------------------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------------------------------
  component GenericMixer
    generic (
      BIT_WIDTH     : in natural range 8 to 32 := 32;
      LUT_PHASE     : in std_logic := '1';
      FCW_WIDTH     : natural := 16;
      LATENCY       : natural := 2  
    );
    port(
      -- inputs
      Clock          :  in std_logic;                    --! system clock
      Reset          :  in std_logic;                    --! system reset

      OscillatorFcw  :  in signed(FCW_WIDTH-1 downto 0); --! s.31
      SampleI        :  in signed(BIT_WIDTH-1 downto 0); --! unshifted i input
      SampleQ        :  in signed(BIT_WIDTH-1 downto 0); --! unshifted q input

      SampleInValid  :  in std_logic;                    --! is input valid
      SampleInLast   :  in std_logic;                    --! marker to delineate two back-to-back sequences of inputs
      SampleOutReady :  in std_logic;                    --! is following module ready to accept input

      -- ouptuts
      OverflowStatus : out std_logic_vector(1 downto 0); --! overflow flags, b1=q b0=i

      MixedSampleI   : out signed(BIT_WIDTH-1 downto 0); --! shifted i output
      MixedSampleQ   : out signed(BIT_WIDTH-1 downto 0); --! shifted q output

      SampleOutValid : out std_logic;             --! is output valid
      SampleOutLast  : out std_logic;             --! marker to delineate two back-to-back sequences of inputs
      SampleInReady  : out std_logic              --! tell preceding module that we're ready for input
    );
  end component;

  component Accumulator
    generic (
      N_SAMPLES      : natural := 2**16;
      BIT_WIDTH      : natural := 16
    );
    port (
      -- inputs
      Clock          : in  std_logic;
      Reset          : in  std_logic;

      SampleOutReady : in  std_logic;
      SampleInValid  : in  std_logic;
      SampleInLast   : in  std_logic;
      SampleIn       : in  signed(BIT_WIDTH-1 downto 0);

      -- outputs
      SampleInReady  : out std_logic;
      SampleOutValid : out std_logic;
      SampleOutLast  : out std_logic;
      SampleOut      : out signed(BIT_WIDTH-1 downto 0)
    );
  end component;

  ------------------------------------------------------------------------------------------------------
  -- Signals
  ------------------------------------------------------------------------------------------------------
  signal MixerOutValid        : std_logic                      := '0'; -- intermediate signal between oscillator and integrate_and_dump
  signal MixerOutLast         : std_logic                      := '0'; -- intermediate signal between oscillator and integrate_and_dump
  signal MixerOutReady        : std_logic                      := '0'; -- intermediate signal between integrate_and_dump and oscillator
  signal MixerOut_I           : signed(BIT_WIDTH-1 downto 0)   := (others => '0'); -- intermediate signal between oscillator and integrate_and_dump
  signal MixerOut_Q           : signed(BIT_WIDTH-1 downto 0)   := (others => '0'); -- intermediate signal between oscillator and integrate_and_dump

  signal SampleOutValid_I     : std_logic                      := '0'; -- and'd with SampleOutValid_Q to produce SampleOutValid
  signal SampleOutValid_Q     : std_logic                      := '0'; -- and'd with SampleOutValid_I to produce SampleOutValid

  signal SampleOutLast_I      : std_logic                      := '0'; -- and'd with SampleOutLast_Q to produce SampleOutValid
  signal SampleOutLast_Q      : std_logic                      := '0'; -- and'd with SampleOutLast_I to produce SampleOutValid

  signal AccumulatorInReady_I : std_logic                      := '0'; -- intermediate signal between integrate_and_dump and oscillator
  signal AccumulatorInReady_Q : std_logic                      := '0'; -- intermediate signal between integrate_and_dump and oscillator

  ------------------------------------------------------------------------------------------------------
  -- Constants
  ------------------------------------------------------------------------------------------------------
  constant DEBUG : string := "true";

  ------------------------------------------------------------------------------------------------------
  -- Attributes
  ------------------------------------------------------------------------------------------------------
--  attribute mark_debug                         : string;
--  attribute mark_debug of Reset                : signal is DEBUG;
--  attribute mark_debug of OscillatorFcw        : signal is DEBUG;
--  attribute mark_debug of SampleOutReady       : signal is DEBUG;
--  attribute mark_debug of SampleInValid        : signal is DEBUG;
--  attribute mark_debug of SampleInLast         : signal is DEBUG;
--  attribute mark_debug of SampleIn_I           : signal is DEBUG;
--  attribute mark_debug of SampleIn_Q           : signal is DEBUG;
--  attribute mark_debug of OverflowStatus       : signal is DEBUG;
--  attribute mark_debug of SampleInReady        : signal is DEBUG;
--  attribute mark_debug of SampleOutValid       : signal is DEBUG;
--  attribute mark_debug of SampleOutLast        : signal is DEBUG;
--  attribute mark_debug of SampleOut_I          : signal is DEBUG;
--  attribute mark_debug of SampleOut_Q          : signal is DEBUG;
--  attribute mark_debug of MixerOutValid        : signal is DEBUG;
--  attribute mark_debug of MixerOutLast         : signal is DEBUG;
--  attribute mark_debug of MixerOutReady        : signal is DEBUG;
--  attribute mark_debug of MixerOut_I           : signal is DEBUG;
--  attribute mark_debug of MixerOut_Q           : signal is DEBUG;
--  attribute mark_debug of SampleOutValid_I     : signal is DEBUG;
--  attribute mark_debug of SampleOutValid_Q     : signal is DEBUG;
--  attribute mark_debug of SampleOutLast_I      : signal is DEBUG;
--  attribute mark_debug of SampleOutLast_Q      : signal is DEBUG;
--  attribute mark_debug of AccumulatorInReady_I : signal is DEBUG;
--  attribute mark_debug of AccumulatorInReady_Q : signal is DEBUG;
  --attribute mark_debug of OscReset             : signal is DEBUG;

begin

  ------------------------------------------------------------------------------------------------------
  -- Oscillate
  ------------------------------------------------------------------------------------------------------
  oscillator : GenericMixer
    generic map (
      BIT_WIDTH     => BIT_WIDTH,
      FCW_WIDTH     => FCW_WIDTH,
      LATENCY       => LATENCY
    )
    port map(
      -- inputs
      Clock          => Clock,
      Reset          => Reset,

      OscillatorFcw  => OscillatorFcw,
      SampleI        => SampleIn_I,
      SampleQ        => SampleIn_Q,

      SampleInValid  => SampleInValid,
      SampleInLast   => SampleInLast,
      SampleOutReady => MixerOutReady,

      -- ouptuts
      OverflowStatus => OverflowStatus,

      MixedSampleI   => MixerOut_I,
      MixedSampleQ   => MixerOut_Q,

      SampleOutValid => MixerOutValid,
      SampleOutLast  => MixerOutLast,
      SampleInReady  => SampleInReady
    );

  ------------------------------------------------------------------------------------------------------
  -- Integrate & Dump
  ------------------------------------------------------------------------------------------------------
  integrate_and_dump_i : Accumulator
    generic map (
      N_SAMPLES      => N_SAMPLES,
      BIT_WIDTH      => BIT_WIDTH
    )
    port map (
      -- inputs
      Clock          => Clock,
      Reset          => Reset,

      SampleOutReady => SampleOutReady,
      SampleInValid  => MixerOutValid,
      SampleInLast   => MixerOutLast,
      SampleIn       => MixerOut_I,

      -- outputs
      SampleInReady  => AccumulatorInReady_I,
      SampleOutValid => SampleOutValid_I,
      SampleOutLast  => SampleOutLast_I,
      SampleOut      => SampleOut_I
    );

  integrate_and_dump_q : Accumulator
    generic map (
      N_SAMPLES      => N_SAMPLES,
      BIT_WIDTH      => BIT_WIDTH
    )
    port map (
      -- inputs
      Clock          => Clock,
      Reset          => Reset,

      SampleOutReady => SampleOutReady,
      SampleInValid  => MixerOutValid,
      SampleInLast   => MixerOutLast,
      SampleIn       => MixerOut_Q,

      -- outputs
      SampleInReady  => AccumulatorInReady_Q,
      SampleOutValid => SampleOutValid_Q,
      SampleOutLast  => SampleOutLast_Q,
      SampleOut      => SampleOut_Q
    );

  -----------------------------------------------------------------------
  -- Synchronize Control Signals
  -----------------------------------------------------------------------
  MixerOutReady  <= AccumulatorInReady_Q and AccumulatorInReady_I;
  SampleOutValid <= SampleOutValid_Q     and SampleOutValid_I and SampleOutValid_Q;
  SampleOutLast  <= SampleOutLast_Q      and SampleOutLast_I  and SampleOutLast_Q;

end rtl;
