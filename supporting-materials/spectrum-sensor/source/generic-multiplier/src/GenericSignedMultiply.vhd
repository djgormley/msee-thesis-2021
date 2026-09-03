------------------------------------------------------------------------------------------------------
--! @Author:         Michael A. Evans (GRC-LCI0)
--! @Creation-Date:  15 October 2017
--! @Module-Name:    Generic Signed Multiplier
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.1.3
--! @Git-Tag:        xxxx
--!
--! @Version: 1.0
--! Michael A. Evan (GRC-LCI0) - File created.
--! @version: 2.0
--! Anthony A. Stock (GRC-LCI0)[NIP] - Added control signals.
--! @Version: 3.0
--! Dylan J. Gormley (GRC-LCI0) - Added support for trunc = 0, updated design to infer
--!     with modern (7-series) DSP structures.
--!
--! @ToDo: Investige handling of -MAXVALUE*-MAXVALUE.  Disable AllOnes/AllOnes when trunc = 0.
------------------------------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.math_real.all;

--! @Module-Description
--! This module multiplies two numbers. Allows for symmetric rounding and truncation
--! with saturation logic.  A multiply structure is infered for the DSP hardware slice.
--! This module has a variable cycle latency between input and output.
entity GenericSignedMultiply is
  generic (
    LengthA             : natural range 2 to 32 := 18; --! Number of bits in operand A.
    LengthB             : natural range 2 to 32 := 18; --! Number of bits in operand B.
    Latency             : natural range 2 to 32 := 2;  --! Total cycles of latency to do an operation.
    BitstoTrunc         : natural               := 0;  --! Allows the ability to trim most significant bits (without saturation!).
    BitstoRound         : natural               := 0   --! Allows the ability to trim least significant bits through symmetric rounding.
  );
  port (
    -- Module inputs
    Clock               : in  std_logic;                  --! Global clock
    Reset               : in  std_logic;                  --! Synchronous reset
    A_in                : in  signed(LengthA-1 downto 0); --! Signed input 1
    B_in                : in  signed(LengthB-1 downto 0); --! Signed input 2
    SampleInValid       : in  std_logic;                  --! Input being driven into multiplier is ready to be read
    SampleInLast        : in  std_logic;                  --! marker to delineate two back-to-back sequences of inputs
    SampleOutReady      : in  std_logic;                  --! is following module ready to accept input
    -- Module outputs
    C_out               : out signed(LengthA+LengthB-1-BitstoTrunc-BitstoRound downto 0); --! C_out = A_in * B_in
    SampleOutValid      : out std_logic;                                                  --! Data on output is valid
    SampleOutLast       : out std_logic;                                                  --! marker to delineate two back-to-back sequences of inputs
    SampleInReady       : out std_logic                                                   --! tell preceding module that we're ready for input
  );
  -- Forces the logic to use the DSP in the event it is having trouble invoking
  attribute use_dsp : string;
  attribute use_dsp of GenericSignedMultiply : entity is "yes";
end GenericSignedMultiply;

architecture behavioral of GenericSignedMultiply is

  ------------------------------------------------------------------------------------------------------
  -- Signals
  ------------------------------------------------------------------------------------------------------
  -- These array apply delays to the incoming operands to match the desired latency.
  type   ADelayArray is array(Latency-2 downto 0) of signed(LengthA-1 downto 0);
  signal ADelays              : ADelayArray;
  type   BDelayArray is array(Latency-2 downto 0) of signed(LengthB-1 downto 0);
  signal BDelays              : BDelayArray;

  -- These arrays match control signals with the latency
  signal SampleOutReadyBuffer : std_logic_vector(LATENCY downto 0) := (others => '0'); -- shift register
  signal SampleInValidBuffer  : std_logic_vector(LATENCY downto 0) := (others => '0'); -- shift register
  signal SampleInLastBuffer   : std_logic_vector(LATENCY downto 0) := (others => '0'); -- shift register

  -- Used to register incoming control signals asynchronously
  signal SIV_reg              : std_logic := '0'; -- signal in valid
  signal SOR_reg              : std_logic := '0'; -- signal out ready
  signal SIL_reg              : std_logic := '0'; -- signal in last

  -- Various signals associated with delaying the appropriate signals so that the overall operation occurs in two clock cycles
  signal MultiplyResult       : signed(LengthA+LengthB-1 downto 0) := (others => '0');
  signal C_out_temp           : signed(LengthA+LengthB-1 downto 0) := (others => '0');

  ------------------------------------------------------------------------------------------------------
  -- Constants
  ------------------------------------------------------------------------------------------------------
  -- Constants related to saturation of the output signal.
  constant AllOnes            : signed(BitstoTrunc-1 downto 0) := (others => '1');
  constant AllZeros           : signed(BitstoTrunc-1 downto 0) := (others => '0');
  constant DEBUG              : string                         := "true";

  ------------------------------------------------------------------------------------------------------
  -- Attributes
  ------------------------------------------------------------------------------------------------------
--  attribute mark_debug                         : string;
--  attribute mark_debug of Clock                : signal is DEBUG;
--  attribute mark_debug of Reset                : signal is DEBUG;
--  attribute mark_debug of A_in                 : signal is DEBUG;
--  attribute mark_debug of B_in                 : signal is DEBUG;
--  attribute mark_debug of SampleInValid        : signal is DEBUG;
--  attribute mark_debug of SampleInLast         : signal is DEBUG;
--  attribute mark_debug of SampleOutReady       : signal is DEBUG;
--  attribute mark_debug of C_out                : signal is DEBUG;
--  attribute mark_debug of SampleOutValid       : signal is DEBUG;
--  attribute mark_debug of SampleOutLast        : signal is DEBUG;
--  attribute mark_debug of SampleInReady        : signal is DEBUG;
--  attribute mark_debug of ADelays              : signal is DEBUG;
--  attribute mark_debug of BDelays              : signal is DEBUG;
--  attribute mark_debug of SampleOutReadyBuffer : signal is DEBUG;
--  attribute mark_debug of SampleInValidBuffer  : signal is DEBUG;
--  attribute mark_debug of SampleInLastBuffer   : signal is DEBUG;
--  attribute mark_debug of SIV_reg              : signal is DEBUG;
--  attribute mark_debug of SOR_reg              : signal is DEBUG;
--  attribute mark_debug of SIL_reg              : signal is DEBUG;
--  attribute mark_debug of MultiplyResult       : signal is DEBUG;
--  attribute mark_debug of C_out_temp           : signal is DEBUG;

begin

  -- A combinational assignment here allows the multiply to be done in two or less cycles
  ADelays(ADelays'low) <= A_in when SampleInValid else (others => '0');
  BDelays(BDelays'low) <= B_in when SampleInValid else (others => '0');

  -- Use this process (if needed) to create additional pipelining for the DSP-based multiply
  AdditionalPipelining: if Latency > 2 generate
    process(all)
    begin
      if rising_edge(Clock) then
        if Reset then
          ADelays(ADelays'high downto ADelays'low+1) <= (others => (others => '0'));
          BDelays(BDelays'high downto BDelays'low+1) <= (others => (others => '0'));
        else
          ADelays(ADelays'high downto ADelays'low+1) <= ADelays(ADelays'high-1 downto ADelays'low);
          BDelays(BDelays'high downto BDelays'low+1) <= BDelays(BDelays'high-1 downto BDelays'low);
        end if;
      end if;
    end process;
  end generate;

  -- On the second-to-last cycle, the multiplication is completed
  mult: process(all)
  begin
    if rising_edge(Clock) then
        if Reset then
            MultiplyResult  <= (others => '0');
        else
            MultiplyResult  <= ADelays(ADelays'high) * BDelays(BDelays'high);
        end if;
    end if;
  end process;

  -- Ensure that we're not trying to perform negative exponentiation
  rnd: process(all)
  begin
    if rising_edge(Clock) then
        if Reset then
            C_out_temp <= (others => '0');
        elsif BitstoRound > 0 then
          C_out_temp <= MultiplyResult + to_signed(natural(real(2**BitstoRound-1))-1, MultiplyResult'length);
        else
          C_out_temp <= MultiplyResult;
        end if;
    end if;
  end process;

  -- This process outputs the full result from the module
  outs: process(all)
  begin
    if rising_edge(Clock) then
      if Reset then
        C_out <= (others => '0');
      else
        -- On the last cycle, the result is output
        if BitstoTrunc = 0 then
                C_out                  <= C_out_temp(C_out_temp'high downto BitstoRound);
        elsif ?? (not C_out_temp(C_out_temp'high)) and C_out_temp(C_out_temp'high-1 downto C_out_temp'high-BitstoTrunc) /= AllZeros then
          C_out(C_out'high)            <= '0';
          C_out(C_out'high-1 downto 0) <= (others => '1');
        elsif ?? C_out_temp(C_out_temp'high)       and C_out_temp(C_out_temp'high-1 downto C_out_temp'high-BitstoTrunc) /= AllOnes then
          C_out(C_out'high)            <= '1';
          C_out(C_out'high-1 downto 0) <= (others => '0');
        else
          C_out                        <= C_out_temp(C_out_temp'high-BitstoTrunc downto BitstoRound);
        end if;
      end if;
    end if;
  end process;

  -- Read control signals into buffers
  SampleOutReadyBuffer(SampleOutReadyBuffer'low) <= SampleOutReady;
  SampleInLastBuffer(SampleInLastBuffer'low)     <= SampleInLast;
  SampleInValidBuffer(SampleInValidBuffer'low)   <= SampleInValid;

  -- Synchronize control signals
  ctrl: process(all)
  begin
    if rising_edge(Clock) then
      if Reset then
        SampleOutReadyBuffer(SampleOutReadyBuffer'high downto SampleOutReadyBuffer'low+1) <= (others => '0');
        SampleInValidBuffer(SampleInValidBuffer'high   downto SampleInValidBuffer'low+1)  <= (others => '0');
        SampleInLastBuffer(SampleInLastBuffer'high     downto SampleInLastBuffer'low+1)   <= (others => '0');

        SampleInReady  <= '0';
        SampleOutValid <= '0';
        SampleOutLast  <= '0';
      else
        -- output top value of control signal buffers
        SampleInReady    <=  SampleOutReadyBuffer(SampleOutReadyBuffer'high);
        SampleOutValid   <=  SampleInValidBuffer(SampleInValidBuffer'high);
        SampleOutLast    <=  SampleInLastBuffer(SampleInLastBuffer'high);

        -- shift buffers
        SampleOutReadyBuffer(SampleOutReadyBuffer'high downto SampleOutReadyBuffer'low+1) <= SampleOutReadyBuffer(SampleOutReadyBuffer'high-1 downto SampleOutReadyBuffer'low);
        SampleInLastBuffer(SampleInLastBuffer'high     downto SampleInLastBuffer'low+1)   <= SampleInLastBuffer(SampleInLastBuffer'high-1     downto SampleInLastBuffer'low);
        SampleInValidBuffer(SampleInValidBuffer'high   downto SampleInValidBuffer'low+1)  <= SampleInValidBuffer(SampleInValidBuffer'high-1   downto SampleInValidBuffer'low);
      end if;
    end if;
  end process;


end behavioral;
