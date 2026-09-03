------------------------------------------------------------------------------------------------------
--! @Author:         Anthony A. Stock (NASA GRC/LCI - NIP)
--! @Creation-Date:  15 October 2020
--! @Module-Name:    Complex Fir
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.1.3
--! @Git-Tag:        xxxx
--!
--! Revision 0.01 - Anthony A. Stock -- file created
------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.GenericFir_pkg.all;

--! @Module-Description
--! This module is wrapper for the Generic Fir module. Filters real and imaginary components of a
--! signal through identical instances of the Generic Fir with real taps.
entity ComplexFir is
  generic (
    HIGH_OFFSET       : natural := 1;
    LATENCY           : natural := 2  
  );
  port (
    -- inputs
    Clock             : in  std_logic;                            --! Global clock.
    Reset             : in  std_logic;                            --! Asynchronous reset.
    IncomingSample_I  : in  signed(FIR_BIT_WIDTH-1 downto 0);     --! Two's complement sample
    IncomingSample_Q  : in  signed(FIR_BIT_WIDTH-1 downto 0);     --! Two's complement sample
    SampleInValid     : in  std_logic;                            --! Input being driven into multiplier is ready to be read
    SampleInLast      : in  std_logic;                            --! marker to delineate two back-to-back sequences of inputs
    SampleOutReady    : in  std_logic;                            --! is following module ready to accept input
    Coeffs    	      : in  CoeffArray(TAP_COUNT-1 downto 0);     --! Each of the coefficients are two's complement.
    -- outputs
    OutgoingSample_I  : out signed(FIR_BIT_WIDTH-1 downto 0);     --! Two's complement sample.
    OutgoingSample_Q  : out signed(FIR_BIT_WIDTH-1 downto 0);     --! Two's complement sample.
    SampleOutValid    : out std_logic;                            --! Data on output is valid
    SampleOutLast     : out std_logic;                            --! marker to delineate two back-to-back sequences of inputs
    SampleInReady     : out std_logic                             --! tell preceding module that we're ready for input
  );
end ComplexFir;

architecture Behavioral of ComplexFir is

 -----------------------------------------------------------------------
 -- Components
 -----------------------------------------------------------------------
 component GenericFir is
   generic (
     HIGH_OFFSET      : natural := 1;
     LATENCY          : natural := 2  
   );
   port (
     -- inputs
     Clock            : in  std_logic;                          --! Global clock.
     Reset            : in  std_logic;                          --! Asynchronous reset.
     IncomingSample   : in  signed(FIR_BIT_WIDTH-1 downto 0);   --! Two's complement sample
     SampleInValid    : in  std_logic;                          --! Input being driven into multiplier is ready to be read
     SampleInLast     : in  std_logic;                          --! marker to delineate two back-to-back sequences of inputs
     SampleOutReady   : in  std_logic;                          --! is following module ready to accept input
   	 Coeffs    	      : in  CoeffArray(TAP_COUNT-1 downto 0);   --! Each of the coefficients are two's complement
     -- outputs
     OutgoingSample   : out signed(FIR_BIT_WIDTH-1 downto 0);   --! Two's complement sample
     SampleOutValid   : out std_logic;                          --! Data on output is valid
     SampleOutLast    : out std_logic;                          --! marker to delineate two back-to-back sequences of inputs
     SampleInReady    : out std_logic                           --! tell preceding module that we're ready for input
   );
   end component;

 ------------------------------------------------------------------------------------------------------
 -- Input signals
 ------------------------------------------------------------------------------------------------------
 signal SampleOutValid_I : std_logic := '0';
 signal SampleOutlast_I  : std_logic := '0';
 signal SampleInReady_I  : std_logic := '0';

 ------------------------------------------------------------------------------------------------------
 -- Output signals
 ------------------------------------------------------------------------------------------------------
 signal SampleOutValid_Q : std_logic := '0';
 signal SampleOutLast_Q  : std_logic := '0';
 signal SampleInReady_Q  : std_logic := '0';

begin

  fir_i : GenericFir
    generic map (
	  HIGH_OFFSET  => HIGH_OFFSET,
	  LATENCY      => LATENCY
    )
  port map (
    -- inputs
    Clock            => Clock,
    Reset            => Reset,
    IncomingSample   => IncomingSample_I,
    SampleInValid    => SampleInValid,
    SampleInLast     => SampleInLast,
    SampleOutReady   => SampleOutReady,
    Coeffs    	     => Coeffs,

    -- outputs
    OutgoingSample   => OutgoingSample_I,
    SampleOutValid   => SampleOutValid_I,
    SampleOutLast    => SampleOutLast_I,
    SampleInReady    => SampleInReady_I
  );

  fir_q : GenericFir
    generic map (
	  HIGH_OFFSET    => HIGH_OFFSET,
	  LATENCY        => LATENCY
    )
  port map (
    -- inputs
    Clock            => Clock,
    Reset            => Reset,
    IncomingSample   => IncomingSample_Q,
    SampleInValid    => SampleInValid,
    SampleInLast     => SampleInLast,
    SampleOutReady   => SampleOutReady,
    Coeffs    	     => Coeffs,

    -- outputs
    OutgoingSample   => OutgoingSample_Q,
    SampleOutValid   => SampleOutValid_Q,
    SampleOutLast    => SampleOutLast_Q,
    SampleInReady    => SampleInReady_Q
  );

  -- control signals
  SampleOutValid <= SampleOutValid_I and SampleOutValid_Q;
  SampleOutLast  <= SampleOutLast_I  and SampleOutLast_Q;
  SampleInReady  <= SampleInReady_I  and SampleInReady_Q;

end Behavioral;
