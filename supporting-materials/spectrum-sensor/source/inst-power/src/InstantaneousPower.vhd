------------------------------------------------------------------------------------------------------
--! @Author:         Dylan J. Gormley (NASA GRC/LCI)
--! @Creation-Date:  1 November 2020
--! @Module-Name:    Instantaneous Power
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.1.3
--! @Git-Tag:        xxxx
--!
--! @Version: 1.0
--! Dylan J. Gormley (GRC-LCI0) - File created.
--! @Version: 2.0
--! Anthony A. Stock (GRC-LCI0)[NIP]  - Disabled GenericSignedMultiply round/trunc inputs, replaced
--! with custom round/trunc, removed hardcoded indices/ranges and replaced with dynamic values.
--! @Version: 3.0
--! W. Peter Simon (GRC-LEA0) - Added registering of output values.
--!
--! @ToDo: Replace max_pkg with VHDL-2008's MAXIMUM function when using Vivado 2020.2+.
------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.max_pkg.all; -- must use custom max b/c Xilinx doesn't support MAXIMUM in sim

--! @Module-Description
--! This module takes the instantaneous power of a complex signal at the current sample.
--! The instantaneous power in this use case is defined as the magnitude squared of the incoming
--! sample.  That is, Px = |x|^2.  Because x is complex we can rewite |x|^2 as sum[(a)^2+(jb)^2]^2.
--! Simplifying we find that Px = a^2+b^2.
entity InstantaneousPower is
  generic (
    LengthA          : natural range 2 to 32  := 16;      --! number of bits in operand A.
    LengthB          : natural range 2 to 32  := 16;      --! number of bits in operand B.
    Latency          : natural range 2 to 32  := 2;       --! total cycles of latency to do an operation.
    BitstoTrunc      : natural range 0 to 32  := 0;       --! Allows the ability to trim most significant bits. Does not used saturation.
    BitstoRound      : natural range 0 to 32  := 0        --! allows the ability to trim least significant bits through symmetric rounding.
  );
  port (
    -- Module inputs
    Clock            : in  std_logic;                  --! global clock
    Reset            : in  std_logic;                  --! synchronous reset
    A_in             : in  signed(LengthA-1 downto 0); --! signed input 1
    B_in             : in  signed(LengthB-1 downto 0); --! signed input 2
    SampleInValid    : in  std_logic;                  --! input being driven into multiplier is ready to be read
    SampleInLast     : in  std_logic;                  --! marker to delineate two back-to-back sequences of inputs
    SampleOutReady   : in  std_logic;                  --! is following module ready to accept input

    -- Module outputs
    C_out            : out unsigned(MAX(LengthA,LengthB)*2-1-BitstoRound-BitstoTrunc downto 0); --! instantaneous power
    SampleOutValid   : out std_logic;                                                           --! data on output is valid
    SampleOutLast    : out std_logic;                                                           --! marker to delineate two back-to-back sequences of inputs
    SampleInReady    : out std_logic                                                            --! tell preceding module that we're ready for input
  );
end InstantaneousPower;


architecture RTL of InstantaneousPower is

  -----------------------------------------------------------------------
  -- Components
  -----------------------------------------------------------------------
  component GenericSignedMultiply
    generic (
      LengthA            : natural;  --! number of bits in operand A.
      LengthB            : natural;  --! number of bits in operand B.
      Latency            : natural;  --! total cycles of latency to do an operation.
      BitstoTrunc        : natural;  --! allows the ability to trim most significant bits (without saturation!).
      BitstoRound        : natural   --! allows the ability to trim least significant bits through symmetric rounding.
   );
   port (
     -- Module inputs
     Clock               : in  std_logic;                  --! global clock
     Reset               : in  std_logic;                  --! synchronous reset
     A_in                : in  signed(LengthA-1 downto 0); --! signed input 1
     B_in                : in  signed(LengthB-1 downto 0); --! signed input 2
     SampleInValid       : in  std_logic;                  --! input being driven into multiplier is ready to be read
     SampleInLast        : in  std_logic;                  --! marker to delineate two back-to-back sequences of inputs
     SampleOutReady      : in  std_logic;                  --! is following module ready to accept input

     -- Module outputs
     C_out               : out signed(LengthA+LengthB-1-BitstoTrunc-BitstoRound downto 0);  --! C_out = A_in * B_in
     SampleOutValid      : out std_logic;                                                   --! Data on output is valid
     SampleOutLast       : out std_logic;                                                   --! marker to delineate two back-to-back sequences of inputs
     SampleInReady       : out std_logic                                                    --! tell preceding module that we're ready for input
   );
  end component;

  -----------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------
  signal ASquared         : signed(2*LengthA-1 downto 0)              := (others => '0');
  signal BSquared         : signed(2*LengthB-1 downto 0)              := (others => '0');
  signal C_out_tmp        : signed(MAX(LengthA,LengthB)*2-1 downto 0) := (others => '0');

  signal SampleOutValid_A : std_logic := '0';
  signal SampleOutValid_B : std_logic := '0';
  signal SampleOutLast_A  : std_logic := '0';
  signal SampleInReady_A  : std_logic := '0';
  signal SampleOutLast_B  : std_logic := '0';
  signal SampleInReady_B  : std_logic := '0';

  -----------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------
  constant RND           : signed(C_out_tmp'range) := to_signed(natural(2**BitstoRound-1), C_out_tmp'length);
  constant DEBUG         : string                  := "true"; 

  -----------------------------------------------------------------------
  -- Attributes
  -----------------------------------------------------------------------
--  attribute mark_debug                       : string;
--  attribute mark_debug of Reset              : signal is DEBUG;
--  attribute mark_debug of A_in               : signal is DEBUG;
--  attribute mark_debug of B_in               : signal is DEBUG;
--  attribute mark_debug of SampleInValid      : signal is DEBUG;
--  attribute mark_debug of SampleInLast       : signal is DEBUG;
--  attribute mark_debug of SampleOutReady     : signal is DEBUG;
--  attribute mark_debug of C_out              : signal is DEBUG;
--  attribute mark_debug of SampleOutValid     : signal is DEBUG;
--  attribute mark_debug of SampleOutLast      : signal is DEBUG;
--  attribute mark_debug of SampleInReady      : signal is DEBUG;
--  attribute mark_debug of ASquared           : signal is DEBUG;
--  attribute mark_debug of BSquared           : signal is DEBUG;
--  attribute mark_debug of C_out_tmp          : signal is DEBUG;
--  attribute mark_debug of SampleOutValid_A   : signal is DEBUG;
--  attribute mark_debug of SampleOutValid_B   : signal is DEBUG;
--  attribute mark_debug of SampleOutLast_A    : signal is DEBUG;
--  attribute mark_debug of SampleInReady_A    : signal is DEBUG;
--  attribute mark_debug of SampleOutLast_B    : signal is DEBUG;
--  attribute mark_debug of SampleInReady_B    : signal is DEBUG;

begin

  square_a_inst : GenericSignedMultiply
    generic map(
      LengthA          => LengthA,
      LengthB          => LengthA,
      Latency          => Latency,
      BitstoTrunc      => 0,
      BitstoRound      => 0
    )
    port map(
      -- Module inputs
      Clock            => Clock,
      Reset            => Reset,
      A_in             => A_in,
      B_in             => A_in,
      SampleInValid    => SampleInValid,
      SampleInLast     => SampleInLast,
      SampleOutReady   => SampleOutReady,

      -- Module outputs
      C_out            => ASquared,
      SampleOutValid   => SampleOutValid_A,
      SampleOutLast    => SampleOutLast_A,
      SampleInReady    => SampleInReady_A
    );

  -- result is automatically rounded by at least 1 to prepare for addition
  square_b_inst : GenericSignedMultiply
    generic map(
      LengthA     => LengthB,
      LengthB     => LengthB,
      Latency     => Latency,
      BitstoTrunc => 0,
      BitstoRound => 0
    )
    port map(
      -- Module inputs
      Clock            => Clock,
      Reset            => reset,
      A_in             => B_in,
      B_in             => B_in,
      SampleInValid    => SampleInValid,
      SampleInLast     => SampleInLast,
      SampleOutReady   => SampleOutReady,

      -- Module outputs
      C_out            => BSquared,
      SampleOutValid   => SampleOutValid_B,
      SampleOutLast    => SampleOutLast_B,
      SampleInReady    => SampleInReady_B
    );

  -- Sum of A**2 and B**2, plus first step of symmetrical rounding
  REG_C_OUT : process(all)
  begin
    if rising_edge(Clock) then
      if Reset then
        C_out_tmp <= (others => '0');
      elsif BitstoRound > 0 then
        C_out_tmp <= ASquared + BSquared + rnd;
      else
        C_out_tmp <= ASquared + BSquared;
      end if;
    end if;
  end process;

  REG_OUTPUTS : process(all)
  begin
    if rising_edge(Clock) then
      if Reset then
        SampleOutValid <= '0';
        SampleOutLast  <= '0';
        SampleInReady  <= '0';
      else
        SampleOutValid <= SampleOutValid_A and SampleOutValid_B;
        SampleOutLast  <= SampleOutLast_A  and SampleOutLast_B;
        SampleInReady  <= SampleInReady_A  and SampleInReady_B;
      end if;
    end if;
  end process;

  -- After adding 2**BitstoRound-1 we can trim off LSB's. Detect overflow and saturate; truncate.
  -- Does not saturate to compensate for truncation. See documentation for more info.
  C_out <= unsigned(C_out_tmp(C_out_tmp'high-BitstoTrunc downto BitstoRound)) when not C_out_tmp(C_out_tmp'high) else
           (C_out'high => '0', others => '1');

end RTL;
