------------------------------------------------------------------------------------------------------
--! @Author:         Anthony A. Stock (NASA GRC/LCI0)[NIP]
--! @Creation-Date:  March 2021
--! @Module-Name:    Channelizer Testbench
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.1.3
--! @Git-Tag:        xxxx
------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.genericfir_pkg.all;
use ieee.numeric_std.all;

--! @Module-Description
--! Down/Upconverts a complex baseband signal using a frequency mixer and followed by a FIR filter.
entity Channelizer is
  generic (
    BIT_WIDTH      : natural range 8 to 32 := 16;
    TAP_COUNT      : natural               := 2;
    LUT_PHASE      : std_logic             := '1';                 --! 0 if using 1/4 sin LUT, 1 if using 1/4 cos LUT
    FCW_WIDTH      : natural               := 32;
    LATENCY        : natural               := 2
  );
  port(
    -- inputs
    Clock             : in  std_logic;                           --! system clock
    Reset             : in  std_logic;                           --! system reset
    Coeffs    	      : in  CoeffArray(TAP_COUNT-1 downto 0);    --! FIR taps

    OscillatorFcw     : in  signed(FCW_WIDTH-1 downto 0);        --! NCO FCW
    SampleIn_I        : in  signed(BIT_WIDTH-1 downto 0);        --! i input
    SampleIn_Q        : in  signed(BIT_WIDTH-1 downto 0);        --! unshifted q input

    SampleInValid     : in  std_logic;                           --! is input valid
    SampleInLast      : in  std_logic;                           --! marker to delineate two back-to-back sequences of inputs
    SampleOutReady    : in  std_logic;                           --! is following module ready to accept input

    -- outputs
    OutgoingSample_I  : out signed(BIT_WIDTH-1 downto 0);        --! Two's complement sample.
    OutgoingSample_Q  : out signed(BIT_WIDTH-1 downto 0);        --! Two's complement sample.

    OverflowStatus    : out std_logic_vector(1 downto 0);        --! b[1]=i b[0]=q

    SampleOutValid    : out std_logic;                           --! Data on output is valid
    SampleOutLast     : out std_logic;                           --! marker to delineate two back-to-back sequences of inputs
    SampleInReady     : out std_logic                            --! tell preceding module that we're ready for input
  );
end Channelizer;

architecture Behavioral of Channelizer is

  -----------------------------------------------------------------------
  -- Components
  -----------------------------------------------------------------------
  component ComplexFir
    generic (
      HIGH_OFFSET       : natural := 1;
      LATENCY           : natural := 2
    );
    port (
      -- inputs
      Clock             : in std_logic;                            --! Global clock.
      Reset             : in std_logic;                            --! Asynchronous reset.
      IncomingSample_I  : in signed(FIR_BIT_WIDTH-1 downto 0);     --! Two's complement sample
      IncomingSample_Q  : in signed(FIR_BIT_WIDTH-1 downto 0);     --! Two's complement sample
      SampleInValid     : in std_logic;                            --! Input being driven into multiplier is ready to be read
      SampleInLast      : in std_logic;                            --! marker to delineate two back-to-back sequences of inputs
      SampleOutReady    : in std_logic;                            --! is following module ready to accept input
      Coeffs    	    : in CoeffArray(TAP_COUNT-1 downto 0);     --! Each of the coefficients are two's complement.
      -- outputs
      OutgoingSample_I  : out signed(FIR_BIT_WIDTH-1 downto 0);    --! Two's complement sample.
      OutgoingSample_Q  : out signed(FIR_BIT_WIDTH-1 downto 0);    --! Two's complement sample.
      SampleOutValid    : out std_logic;                           --! Data on output is valid
      SampleOutLast     : out std_logic;                           --! marker to delineate two back-to-back sequences of inputs
      SampleInReady     : out std_logic                            --! tell preceding module that we're ready for input
    );
  end component;
  
  component GenericMixer
    generic (
      BIT_WIDTH      : natural range 8 to 32 := 32;
      LUT_PHASE      : std_logic := '1';                 --! 0 if using 1/4 sin LUT, 1 if using 1/4 cos LUT
      FCW_WIDTH      : natural := 16;
      LATENCY        : natural := 2
    );
    port(
      -- inputs
      Clock          :  in std_logic;                      --! system clock
      Reset          :  in std_logic;                      --! system reset
      OscillatorFcw  :  in signed(FCW_WIDTH-1 downto 0);   --! NCO FCW
      SampleI        :  in signed(BIT_WIDTH-1 downto 0);   --! unshifted i input
      SampleQ        :  in signed(BIT_WIDTH-1 downto 0);   --! unshifted q input
      SampleInValid  :  in std_logic;                      --! is input valid
      SampleInLast   :  in std_logic;                      --! marker to delineate two back-to-back sequences of inputs
      SampleOutReady :  in std_logic;                      --! is following module ready to accept input
  
      -- ouptuts
      OverflowStatus : out std_logic_vector(1 downto 0);   --! overflow flags, b1=q b0=i
      MixedSampleI   : out signed(BIT_WIDTH-1 downto 0);   --! shifted i output
      MixedSampleQ   : out signed(BIT_WIDTH-1 downto 0);   --! shifted q output
      SampleOutValid : out std_logic;                      --! data on output is valid
      SampleOutLast  : out std_logic;                      --! marker to delineate two back-to-back sequences of inputs
      SampleInReady  : out std_logic                       --! tell preceding module that we're ready for  input
    );
  end component;


  ------------------------------------------------------------------------------------------------------
  -- Constants
  ------------------------------------------------------------------------------------------------------
  constant DEBUG                          : string       := "true";

  ------------------------------------------------------------------------------------------------------
  -- Signals
  ------------------------------------------------------------------------------------------------------

  -- intermediate signals between mixer and FIR
  signal MixerOutValid        : std_logic                    := '0';
  signal MixerOutLast         : std_logic                    := '0';
  signal MixerOutReady        : std_logic                    := '0';
  signal MixerOut_I           : signed(BIT_WIDTH-1 downto 0) := (others => '0');
  signal MixerOut_Q           : signed(BIT_WIDTH-1 downto 0) := (others => '0');
  signal OscReset             : std_logic                    := '0';

  ------------------------------------------------------------------------------------------------------
  -- Attributes
  ------------------------------------------------------------------------------------------------------
--  attribute mark_debug                      : string;
--  attribute mark_debug of Reset             : signal is DEBUG;
--  attribute mark_debug of Coeffs    	      : signal is DEBUG;
--  attribute mark_debug of OscillatorFcw     : signal is DEBUG;
--  attribute mark_debug of SampleIn_I        : signal is DEBUG;
--  attribute mark_debug of SampleIn_Q        : signal is DEBUG;
--  attribute mark_debug of SampleInValid     : signal is DEBUG;
--  attribute mark_debug of SampleInLast      : signal is DEBUG;
--  attribute mark_debug of SampleOutReady    : signal is DEBUG;
--  attribute mark_debug of OutgoingSample_I  : signal is DEBUG;
--  attribute mark_debug of OutgoingSample_Q  : signal is DEBUG;
--  attribute mark_debug of OverflowStatus    : signal is DEBUG;
--  attribute mark_debug of SampleOutValid    : signal is DEBUG;
--  attribute mark_debug of SampleOutLast     : signal is DEBUG;
--  attribute mark_debug of SampleInReady     : signal is DEBUG;
--  attribute mark_debug of MixerOutValid     : signal is DEBUG;
--  attribute mark_debug of MixerOutLast      : signal is DEBUG;
--  attribute mark_debug of MixerOutReady     : signal is DEBUG;
--  attribute mark_debug of MixerOut_I        : signal is DEBUG;
--  attribute mark_debug of MixerOut_Q        : signal is DEBUG;

begin


  oscillator : GenericMixer
    generic map (
      BIT_WIDTH      => BIT_WIDTH,
      LUT_PHASE      => LUT_PHASE,
      FCW_WIDTH      => FCW_WIDTH,
      LATENCY        => LATENCY
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

 fir_inst : ComplexFir
  generic map (
	HIGH_OFFSET  => HIGH_OFFSET,
	LATENCY      => LATENCY
  )
  port map (
    -- inputs
    Clock            => Clock,
    Reset            => Reset,
    IncomingSample_I => MixerOut_I,
    IncomingSample_Q => MixerOut_Q,
    SampleInValid    => MixerOutValid,
    SampleInLast     => MixerOutLast,
    SampleOutReady   => SampleOutReady,
    Coeffs    	     => Coeffs,

    -- outputs
    OutgoingSample_I => OutgoingSample_I,
    OutgoingSample_Q => OutgoingSample_Q,
    SampleOutValid   => SampleOutValid,
    SampleOutLast    => SampleOutLast,
    SampleInReady    => MixerOutReady
  );
    

end Behavioral;
