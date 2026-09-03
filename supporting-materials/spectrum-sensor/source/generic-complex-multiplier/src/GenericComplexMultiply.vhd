-----------------------------------------------------------------------------------------------------
--! @Author:         Dylan J. Gormley (NASA GRC/LCI0)
--! @Creation-Date:  1 November 2020
--! @Module-Name:    Generic Complex Multiply
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.1.3
--! @Git-Tag:        xxxx
--!
--! @Version 1.0:
--! Dylan J. Gormley (NASA/GRC-LCI0) - File Created.
--! @Version 2.0:
--! Anthony A. Stock (NASA/GRC-LCI0)[NIP] - Added control signals.
--!
--! @ToDo: Reduce latency by using Gauss' Algorithm for Complex Multiplication.
------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! @Module-Description
--! Multiply two complex numbers of various lengths using (a+bi)(c+di) = (ac-bd)+(ad+bc)i.
--! Incurs an additional latency of 1, in addition to GenericSignedMultiply's latency
entity GenericComplexMultiply is
  generic (
    LengthA          : natural range 2 to 32 := 16; --! Number of bits in operand A.
    LengthB          : natural range 2 to 32 := 16; --! Number of bits in operand B.
    Latency          : natural range 2 to 32 := 2;  --! Total cycles of latency to do an operation.
    BitstoTrunc      : natural               := 0;  --! Allows the ability to trim most significant bits (without saturation!).
    BitstoRound      : natural               := 0   --! Allows the ability to trim least significant bits through symmetric rounding.
  );
  port (
    -- Module inputs
    Clock            : in  std_logic;                      --! Global clock
    Reset            : in  std_logic;                      --! Synchronous reset
    RealA_in         : in  signed(LengthA-1 downto 0);     --! Signed input 1
    ImagA_in         : in  signed(LengthA-1 downto 0);     --! Signed input 2
    RealB_in         : in  signed(LengthB-1 downto 0);     --! Signed input 3
    ImagB_in         : in  signed(LengthB-1 downto 0);     --! Signed input 4
    SampleInValid    : in  std_logic;                      --! is input valid
    SampleInLast     : in  std_logic;                      --! marker to delineate two back-to-back sequences of inputs
    SampleOutReady   : in  std_logic;                      --! is following module ready to accept input
    -- Module outputs
    ProductReal      : out signed(LengthA+LengthB-BitstoTrunc-BitstoRound downto 0);         --! ProductReal      = A_in * C_in - B_in * D_in
    ProductImaginary : out signed(LengthA+LengthB-BitstoTrunc-BitstoRound downto 0);         --! ProductImaginary = A_in * D_in + B_in * C_in
    SampleOutValid   : out std_logic := '0';                                                 --! Data on output is valid
    SampleOutLast    : out std_logic := '0';                                                 --! marker to delineate two back-to-back sequences of inputs
    SampleInReady    : out std_logic := '0'                                                  --! tell preceding module that we're ready for input
  );
end GenericComplexMultiply;

architecture behavioral of GenericComplexMultiply is

  ------------------------------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------------------------------
  component GenericSignedMultiply
    generic (
      LengthA        : natural;  --! Number of bits in operand A.
      LengthB        : natural;  --! Number of bits in operand B.
      Latency        : natural;  --! Total cycles of latency to do an operation.
      BitstoTrunc    : natural;  --! Allows the ability to trim most significant bits (without saturation!).
      BitstoRound    : natural   --! Allows the ability to trim least significant bits through symmetric rounding.
    );
    port (
      -- inputs
      Clock          : in std_logic;                  --! Global clock
      Reset          : in std_logic;                  --! Synchronous reset
      A_in           : in signed(LengthA-1 downto 0); --! Signed input 1
      B_in           : in signed(LengthB-1 downto 0); --! Signed input 2
      SampleInValid  : in std_logic;                  --! Input being driven into multiplier is ready to be read
      SampleInLast   : in std_logic;                  --! marker to delineate two back-to-back sequences of inputs
      SampleOutReady : in std_logic;                  --! is following module ready to accept input
      -- outputs
      C_out          : out signed(LengthA+LengthB-1-BitstoTrunc-BitstoRound downto 0);  --! C_out = A_in * B_in
      SampleOutValid : out std_logic;                                                   --! Data on output is valid
      SampleOutLast  : out std_logic;                                                   --! marker to delineate two back-to-back sequences of inputs
      SampleInReady  : out std_logic                                                    --! tell preceding module that we're ready for input
    );
  end component;

  ------------------------------------------------------------------------------------------------------
  -- Signals
  ------------------------------------------------------------------------------------------------------

  -- generic multiplier products
  signal AC : signed(LengthA+LengthB-1-BitstoTrunc-BitstoRound downto 0) := (others => '0');
  signal BD : signed(LengthA+LengthB-1-BitstoTrunc-BitstoRound downto 0) := (others => '0');
  signal AD : signed(LengthA+LengthB-1-BitstoTrunc-BitstoRound downto 0) := (others => '0');
  signal BC : signed(LengthA+LengthB-1-BitstoTrunc-BitstoRound downto 0) := (others => '0');

  -- control signals
  signal SampleOutValid_AC : std_logic := '0';
  signal SampleOutValid_BD : std_logic := '0';
  signal SampleOutValid_AD : std_logic := '0';
  signal SampleOutValid_BC : std_logic := '0';

  signal SampleOutLast_AC  : std_logic := '0';
  signal SampleOutLast_BD  : std_logic := '0';
  signal SampleOutLast_AD  : std_logic := '0';
  signal SampleOutLast_BC  : std_logic := '0';

  signal SampleInReady_AC  : std_logic := '0';
  signal SampleInReady_BD  : std_logic := '0';
  signal SampleInReady_AD  : std_logic := '0';
  signal SampleInReady_BC  : std_logic := '0';

begin

  MultiplyAC_inst : GenericSignedMultiply
    generic map(
      LengthA        => LengthA,
      LengthB        => LengthB,
      Latency        => Latency,
      BitstoTrunc    => BitstoTrunc,
      BitstoRound    => BitstoRound
    )
    port map(
      -- inputs
      Clock          => Clock,
      Reset          => Reset,
      A_in           => RealA_in,
      B_in           => RealB_in,
      SampleInValid  => SampleInValid,
      SampleInLast   => SampleInLast,
      SampleOutReady => SampleOutReady,
      -- outputs
      C_out          => AC,
      SampleOutValid => SampleOutValid_AC,
      SampleOutLast  => SampleOutLast_AC,
      SampleInReady  => SampleInReady_AC
    );

  MultiplyBD_inst : GenericSignedMultiply
    generic map(
      LengthA        => LengthA,
      LengthB        => LengthB,
      Latency        => Latency,
      BitstoTrunc    => BitstoTrunc,
      BitstoRound    => BitstoRound
    )
    port map(
      -- inputs
      Clock          => Clock,
      Reset          => Reset,
      A_in           => ImagA_in,
      B_in           => ImagB_in,
      SampleInValid  => SampleInValid,
      SampleInLast   => SampleInLast,
      SampleOutReady => SampleOutReady,
      -- outputs
      C_out          => BD,
      SampleOutValid => SampleOutValid_BD,
      SampleOutLast  => SampleOutLast_BD,
      SampleInReady  => SampleInReady_BD
    );

  MultiplyAD_inst : GenericSignedMultiply
    generic map(
      LengthA        => LengthA,
      LengthB        => LengthB,
      Latency        => Latency,
      BitstoTrunc    => BitstoTrunc,
      BitstoRound    => BitstoRound
    )
    port map(
      -- inputs
      Clock          => Clock,
      Reset          => Reset,
      A_in           => RealA_in,
      B_in           => ImagB_in,
      SampleInValid  => SampleInValid,
      SampleInLast   => SampleInLast,
      SampleOutReady => SampleOutReady,
      -- outputs
      C_out          => AD,
      SampleOutValid => SampleOutValid_AD,
      SampleOutLast  => SampleOutLast_AD,
      SampleInReady  => SampleInReady_AD
    );

  MultiplyBC_inst : GenericSignedMultiply
    generic map(
      LengthA        => LengthA,
      LengthB        => LengthB,
      Latency        => Latency,
      BitstoTrunc    => BitstoTrunc,
      BitstoRound    => BitstoRound
    )
    port map(
      -- input
      Clock          => Clock,
      Reset          => Reset,
      A_in           => ImagA_in,
      B_in           => RealB_in,
      SampleInValid  => SampleInValid,
      SampleInLast   => SampleInLast,
      SampleOutReady => SampleOutReady,
      -- outputs
      C_out          => BC,
      SampleOutValid => SampleOutValid_BC,
      SampleOutLast  => SampleOutLast_BC,
      SampleInReady  => SampleInReady_BC
    );

  outs : process(all)
  begin
    if rising_edge(Clock) then
      if Reset then
          SampleOutLast    <= '0';
          SampleInReady    <= '0';
          SampleOutValid   <= '0';
          ProductReal      <= (others => '0');
          ProductImaginary <= (others => '0'); 
      else
          -- control signals coalesced from generic multipliers
          SampleOutLast  <= SampleOutLast_AC  and SampleOutLast_BD  and SampleOutLast_AD  and SampleOutLast_BC;
          SampleInReady  <= SampleInReady_AC  and SampleInReady_BD  and SampleInReady_AD  and SampleInReady_BC;
          SampleOutValid <= SampleOutValid_AC and SampleOutValid_BD and SampleOutValid_AD and SampleOutValid_BC;
        
          -- sign extend before adding intermediate products
          ProductReal      <= (AC(AC'high) & AC) - (BD(BD'high) & BD); -- (AC-BD)
          ProductImaginary <= (AD(AD'high) & AD) + (BC(BC'high) & BC); -- (AD+BC)
      end if; -- rst
    end if; -- clk
   end process outs;

end behavioral;
