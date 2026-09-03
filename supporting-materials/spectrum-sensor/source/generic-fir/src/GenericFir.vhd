-----------------------------------------------------------------------------
--! @author: Mike Evans, NASA Glenn Research Center
--! @date Creation Date: 10/15/2017
--! @Module Name: GenericTapFIR.vhd
--! @details Project Name: N/A
--! @details Target Devices: N/A
--! @version Xilinx ISE / Vivado
--! @version SVN revision: $Id$
--! @version Version: 1.1.0
--! @details Additional Comments: This VHDL module implements a FIR filter
--! with four coefficients, passed through the top-level of the module.

--! Revision 1:  Dylan Gormley NASA GRC/LCI0.
--! Changed from four taps to generic number of taps.
--! Revision 2: Anthony Stock, intern, NASA GRC LCI
--! Added control signals, removed hardcoded ranges, indices, etc. and
--! replaced with dynamic values. Added underflow/overflow detection and
--! correction.
-----------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.math_real.all;

library work;
use     work.GenericFir_pkg.all; -- Define arrays in this package to be used throughout this file and above

--! @Module-Description
--! This is an implementation of a basic FIR filter using a generic number of coeffecients. Coeffs are passed in.
--! Includes dynamic data widths and underflow/overflow handling.
entity GenericFIR is
  generic (
    HIGH_OFFSET     :     natural := 1;
    LATENCY         :     natural := 2  
  );
   port (
     Clock          : in  std_logic;                                 --! Global clock.
     Reset          : in  std_logic;                                 --! Synchronous reset.
     IncomingSample : in  signed(FIR_BIT_WIDTH-1 downto 0);          --! Two's complement sample
     SampleInValid  : in  std_logic;                                 --! Input being driven into multiplier is ready to be read
     SampleInLast   : in  std_logic;                                 --! marker to delineate two back-to-back sequences of inputs
     SampleOutReady : in  std_logic;                                 --! is following module ready to accept input
     Coeffs         : in  CoeffArray(TAP_COUNT-1 downto 0);          --! Each of the coefficients are two's complement.
     -- Module outputs
     OutgoingSample : out signed(FIR_BIT_WIDTH-1 downto 0);         --! Two's complement sample.
     SampleOutValid : out std_logic;                                --! Data on output is valid
     SampleOutLast  : out std_logic;                                --! marker to delineate two back-to-back sequences of inputs
     SampleInReady  : out std_logic                                 --! tell preceding module that we're ready for input
   );
end GenericFIR;

architecture Behavioral of GenericFIR is

  ------------------------------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------------------------------
  component GenericSignedMultiply
   generic (
     LengthA          : natural;  --! Number of bits in operand A.
     LengthB          : natural;  --! Number of bits in operand B.
     Latency          : natural;  --! Total cycles of latency to do an operation.
     BitstoTrunc      : natural;  --! Allows the ability to trim most significant bits (without saturation!).
     BitstoRound      : natural   --! Allows the ability to trim least significant bits through symmetric rounding.
   );
   port (
     -- Module inputs
     Clock            : in  std_logic;                  --! Global clock
     Reset            : in  std_logic;                  --! Synchronous reset
     A_in             : in  signed(LengthA-1 downto 0); --! Signed input 1
     B_in             : in  signed(LengthB-1 downto 0); --! Signed input 2
     SampleInValid    : in  std_logic;                  --! Input being driven into multiplier is ready to be read
     SampleInLast     : in  std_logic;                  --! marker to delineate two back-to-back sequences of inputs
     SampleOutReady   : in  std_logic;                  --! is following module ready to accept input
     -- Module outputs
     C_out            : out signed(LengthA+LengthB-1-BitstoTrunc-BitstoRound downto 0);  --! C_out = A_in * B_in
     SampleOutValid   : out std_logic;                  --! Data on output is valid
     SampleOutLast    : out std_logic;                  --! marker to delineate two back-to-back sequences of inputs
     SampleInReady    : out std_logic                   --! tell preceding module that we're ready for input
   );
   end component; 

   ------------------------------------------------------------------------------------------------------
   -- Signals
   ------------------------------------------------------------------------------------------------------
   -- This array keep a delayed version of the incoming samples.
   signal SampleDelay           : DelayArray(TAP_COUNT-1 downto 0)       := (others => (others => '0'));
   signal CoeffDelay            : CoeffArray(TAP_COUNT-1 downto 0)       := (others => (others => '0'));

   -- This array holds the result from the operation of scaling each of the delayed samples.
   signal Result                : ResultArray(TAP_COUNT-1 downto 0)      := (others => (others => '0'));
   signal SampleValidDelay      : unsigned(TAP_COUNT-1 downto 0)         := (others => '0'); -- shift register
   signal ResultValid           : unsigned(TAP_COUNT-1 downto 0)         := (others => '0'); -- output valids from multipliers
   signal SampleReadyDelay      : unsigned(TAP_COUNT-1 downto 0)         := (others => '0'); -- shift register
   signal SampleLastDelay       : unsigned(TAP_COUNT-1 downto 0)         := (others => '0'); -- shift register
   signal SampleOutReadyBuffer  : std_logic_vector(TAP_COUNT-1 downto 0) := (others => '0'); -- shift register
   signal SampleInLastBuffer    : std_logic_vector(TAP_COUNT-1 downto 0) := (others => '0'); -- shift register

   ------------------------------------------------------------------------------------------------------
   -- Constants
   ------------------------------------------------------------------------------------------------------

   ------------------------------------------------------------------------------------------------------
   -- Attributes
   ------------------------------------------------------------------------------------------------------
  attribute dont_touch                 : string;
  attribute dont_touch of Result       : signal is "true";

begin
  
  -- just to help timing
  register_coeffs : process(all)
  begin
    if rising_edge(Clock) then
      if Reset then  
        CoeffDelay <= (others => (others => '0'));
      else
        CoeffDelay <= Coeffs;
      end if;
    end if;
 end process register_coeffs;


  -- This process registers each of the incoming samples.
  register_inputs : process(all)
  begin
    if rising_edge(Clock) then
        if Reset then
          SampleDelay      <= (others => (others => '0'));
          SampleValidDelay <= (others => '0');
        else
          -- shift valid buffer and put in new InValid value
          SampleValidDelay(SampleValidDelay'high downto SampleValidDelay'low + 1) <= SampleValidDelay(SampleValidDelay'high - 1 downto SampleValidDelay'low); -- concurrent left shift
          SampleValidDelay(SampleValidDelay'low) <= SampleInValid;
    
          -- shift sample buffer
          SampleDelay(SampleDelay'high downto SampleDelay'low + 1) <= SampleDelay(SampleDelay'high - 1 downto SampleDelay'low); -- concurrent left shift
    
          -- if incoming sample isn't valid, put zero in it's place
          if SampleInValid then
            SampleDelay(SampleDelay'low) <= IncomingSample;
          else
            SampleDelay(SampleDelay'low) <= (others => '0');
          end if;
       end if;
    end if;
  end process register_inputs;

  -- This generate statement creates each of the multiplications needed.
  DoAll : for k in 0 to TAP_COUNT - 1 generate
    GenericSignedMultiply_inst : GenericSignedMultiply
    generic map (
      LengthA     => FIR_BIT_WIDTH,
      LengthB     => TAP_WIDTH,
      Latency     => LATENCY,
      BitstoTrunc => 0,
      BitstoRound => 0
    )
    port map (
      Clock           => Clock,
      Reset           => Reset,
      A_in            => SampleDelay(k),
      B_in            => CoeffDelay(k),
      SampleInValid   => SampleValidDelay(k),
      SampleInLast    => SampleInLast,
      SampleOutReady  => SampleOutReady,
      C_out           => Result(k),
      SampleOutValid  => ResultValid(k),
      SampleOutLast   => SampleLastDelay(k),
      SampleInReady   => SampleReadyDelay(k)
    );
  end generate;

  -- This process sums the scaled numbers to generate the module's result.
  output_result : process(Clock)
    -- We don't have to account for overflow from (TAP_COUNT-1) additions because a signal at unity, when filtered, will not go over 1.
    variable ResultWidth   : natural                        := FIR_BIT_WIDTH + TAP_WIDTH;
    variable ResultSum     : signed(ResultWidth-1 downto 0) := (others => '0');   -- added +1 after removing trunc bit
    --variable ResultSum_tmp : signed(ResultWidth-1 downto 0) := (others => '0');
  begin
    if rising_edge(Clock) then
        if Reset then
          OutgoingSample <= (others => '0');
          ResultSum      := (others => '0');
          --ResultSum_tmp  := (others => '0');
        else

          -- compute sum of products of coefficients and samples
          ResultSum := (others => '0');
          for i in result'range loop
--            ResultSum_tmp := ResultSum + Result(i);
            ResultSum := ResultSum + Result(i);

--            -- detect overflow/underflow by comparing signs and replace with max or min value (saturation)
--            if ResultSum(ResultWidth-1) = Result(i)(ResultWidth-1) and ResultSum_tmp(ResultWidth-1) /= ResultSum(ResultWidth-1) then
--              ResultSum(ResultWidth-2 downto 0) := (others => not(ResultSum(ResultWidth-1)));
--            else
--              ResultSum := ResultSum_tmp;
--            end if;
          end loop;

          -- output of module. HIGH_OFFSET can discard redundant sign bits if necessary.
          OutgoingSample <= ResultSum(ResultSum'high-HIGH_OFFSET downto ResultSum'high-(FIR_BIT_WIDTH-1)-HIGH_OFFSET);
       end if;
    end if;
  end process output_result;

  -----------------------------------------------------------------------
  -- Synchronize Control Signals
  -----------------------------------------------------------------------
   control_signals : process(all)
   begin
     if rising_edge(Clock) then

       if Reset then
         SampleOutValid <= '0';
         SampleOutLast  <= '0';
         SampleInReady  <= '0';
         SampleOutReadyBuffer(SampleOutReadyBuffer'high downto SampleOutReadyBuffer'low)   <= (others => '0');
         SampleInLastBuffer(SampleInLastBuffer'high     downto SampleInLastBuffer'low)     <= (others => '0');
      else

       -- If the result from any of the multipliers is valid, output is valid.
--       if (ResultValid > 0) then
--         SampleOutValid <= '1';
--       else
--         SampleOutValid <= '0';
--       end if;   

       SampleOutValid   <=  ResultValid(ResultValid'high); 
       
       -- other control signals are simply buffered.
       SampleInReady    <=  SampleOutReadyBuffer(SampleOutReadyBuffer'high);
       SampleOutLast    <=  SampleInLastBuffer(SampleInLastBuffer'high);

       -- shift control signals
       SampleOutReadyBuffer(SampleOutReadyBuffer'high downto 0) <= (SampleOutReadyBuffer(SampleOutReadyBuffer'high-1 downto 0)) & SampleReadyDelay(SampleReadyDelay'high);
       SampleInLastBuffer(SampleInLastBuffer'high     downto 0) <= (SampleInLastBuffer(SampleInLastBuffer'high-1     downto 0)) & SampleLastDelay(SampleLastDelay'high);

       end if;
     end if;
   end process;

end Behavioral;
