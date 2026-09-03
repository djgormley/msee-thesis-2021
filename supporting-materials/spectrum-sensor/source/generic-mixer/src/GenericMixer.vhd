------------------------------------------------------------------------------------------------------
--! @Author:         Nicholas S. Tollis (NASA/GRC-LCI)[Vantage Partners, LLC]
--! @Creation-Date:  08 September 2015
--! @Module-Name:    Generic Mixer
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.1.3
--! @Git-Tag:        xxxx
--!
--! @Version 1.0:
--! Nicholas S. Tollis (NASA/GRC-LCI0)[Vantage Partners, LLC] - File Created.
--! @Version 2.0:
--! Charles A. Doxley (NASA/GRC-LEA0) - Upgraded modules to comply w/ 7-series devices.
--! @Version 3.0:
--! Dylan J. Gormley (NASA/GRC-LCI0) - Removed DVB-S2 specific dependencies. Replaced Xilinx Complex
--!     Multiplier with homegrown complex multiplier.  Format changes to better comply with coding 
--!     standard.
--! @Version 3.0:
--! Anthony A. Stock (NASA/GRC-LCI0)[NIP] - Replaced Xilinx BRAM with homegrown BRAM.  Added control
--!     signals.
--! @Version 4.0:
--! Anthony A. Stock (NASA/GRC-LCI0)[NIP] - Replaced unnecessarily sequential logic with combinational 
--! operations to reduce latency.
--!
--! @To-Do: Currently, this module performs a positive or negative shift by using either a positive or
--! negative signed-FCW.  A better method is for a given FCW, produce a right shift and calculate its'
--! left shift by negating the mixed Q (the conjugate).  The output now has four mixed signal outputs: 
--! Left-Shift I, Left-Shifted Q, Right-Shifted I, Right-Shifted Q.  Additionally, this frees up the 
--! FCW to provide greated range/resolution.  All of this for a small amount of logic and one delay.
--! Not compliant with coding standard's syntatical requirements.
------------------------------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

--! @Module-Description
--! This module performs a sin/cos coeffecient lookup and complex multiplication with I/Q to
--! adjust frequencies.
entity GenericMixer is
  generic (
    BIT_WIDTH      : natural range 8 to 32 := 16;
    LUT_PHASE      : std_logic             := '1';       --! 0 if using 1/4 sin LUT, 1 if using 1/4 cos LUT
    FCW_WIDTH      : natural               := 16;
    LATENCY        : natural               := 2  
  );
  port(
    -- inputs
    Clock          :  in std_logic;                      --! system clock
    Reset          :  in std_logic;                      --! system reset

    OscillatorFcw  :  in signed(FCW_WIDTH-1 downto 0);   --! s.31
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
end GenericMixer;

architecture behavioral of GenericMixer is

    ------------------------------------------------------------------------------------------------------
    -- Components
    ------------------------------------------------------------------------------------------------------
    component dual_port_rom is
      generic (
        addr_size : in natural := 14;  --! 2**14 coefficients (effectively 2**16)
        data_size : in natural := 15   --! bit width
      );
      port (
        clock     : in  std_logic;                              --! system clock
        reset     : in  std_logic;
        address1  : in  std_logic_vector(addr_size-1 downto 0); --! i index
        address2  : in  std_logic_vector(addr_size-1 downto 0); --! q index
        dataout1  : out std_logic_vector(data_size-1 downto 0); --! i data
        dataout2  : out std_logic_vector(data_size-1 downto 0)  --! q data
      );
    end component;
    
    component genericcomplexmultiply
       generic (
          lengtha     : natural range 2 to 32 := 32; --! number of bits in operand a.
          lengthb     : natural range 2 to 32 := 16; --! number of bits in operand b.
          latency     : natural range 2 to 32 := 2;  --! total cycles of latency to do an operation.
          bitstotrunc : natural               := 0;  --! allows the ability to trim most significant bits (without saturation!).
          bitstoround : natural               := 16  --! allows the ability to trim least significant bits through symmetric rounding.
       );
       port (
          -- Module inputs
          Clock           : in std_logic;                      --! Global clock
          Reset           : in std_logic;                      --! Synchronous reset
          RealA_in        : in signed(LengthA-1 downto 0);     --! Signed input 1
          ImagA_in        : in signed(LengthA-1 downto 0);     --! Signed input 2
          RealB_in        : in signed(LengthB-1 downto 0);     --! Signed input 3
          ImagB_in        : in signed(LengthB-1 downto 0);     --! Signed input 4
          SampleInValid   : in std_logic;                      --! is input valid
          SampleInLast    : in std_logic;                      --! marker to delineate two back-to-back sequences of inputs
          SampleOutReady  : in std_logic;                      --! is following module ready to accept input
    
          -- Module outputs
          ProductReal       : out signed(LengthA+LengthB-BitstoTrunc-BitstoRound downto 0);          --! ProductReal      = A_in * C_in - B_in * D_in
          ProductImaginary  : out signed(LengthA+LengthB-BitstoTrunc-BitstoRound downto 0);          --! ProductImaginary = A_in * D_in + B_in * C_in
          SampleOutValid    : out std_logic;                                                         --! Data on output is valid
          SampleOutLast     : out std_logic;                                                         --! marker to delineate two back-to-back sequences of inputs
          SampleInReady     : out std_logic                                                          --! tell preceding module that we're ready for input
        );
    end component;
    
    ------------------------------------------------------------------------------------------------------
    -- Constants
    ------------------------------------------------------------------------------------------------------
    constant addr_size : natural := 14; -- effectively 2*16
    constant data_size : natural := 15; -- coeffs are 1 bit longer than this after appending '0'
    
    ------------------------------------------------------------------------------------------------------
    -- Signals
    ------------------------------------------------------------------------------------------------------
    signal nco_count : std_logic_vector(FCW_WIDTH-1 downto 0) := (others => '0');-- := std_logic_vector(OscillatorFcw);
    --signal quad      : std_logic_vector(1           downto 0) := (others => '0'); -- determine which quadrant quarter sine LUT is being evaluated
    --signal addr      : std_logic_vector(addr_size-1 downto 0) := (others => '0'); -- determine index of quarter sine LUT
    signal sin_addr  : std_logic_vector(addr_size-1 downto 0) := (others => '0');
    signal sin_inv   : std_logic_vector(1           downto 0) := (others => '0');
    signal sin_out   : std_logic_vector(data_size-1 downto 0) := (others => '0');
    signal sin_coeff : std_logic_vector(data_size   downto 0) := (others => '0');--   := std_logic_vector(to_signed(3, data_size+1));
    signal cos_addr  : std_logic_vector(addr_size-1 downto 0) := (others => '0');
    signal cos_inv   : std_logic_vector(1           downto 0) := (others => '0');
    signal cos_out   : std_logic_vector(data_size-1 downto 0) := (others => '0');
    signal cos_coeff : std_logic_vector(data_size   downto 0) := (others => '0');
    signal pr_full   : signed(bit_width downto 0)             := (others => '0');
    signal pi_full   : signed(bit_width downto 0)             := (others => '0');
    
begin

-- addresses for sin and cos ports in ROM are taken from NCO and inverted depending on which quadrant we're in
-- use upper 2 bits to control lookup modifications (fwd/bkwd index and pos/neg data);
-- main lookup address is determined by the following (addr_size) bits.
sin_addr   <= nco_count(FCW_WIDTH-3 downto FCW_WIDTH-3-addr_size+1) when nco_count(FCW_WIDTH-2) = '0'                    else (others=>'0') when reset else not(nco_count(13 downto 13-addr_size+1));
cos_addr   <= nco_count(FCW_WIDTH-3 downto FCW_WIDTH-3-addr_size+1) when nco_count(FCW_WIDTH-2) = '1'                    else (others=>'0') when reset else not(nco_count(13 downto 13-addr_size+1));
sin_inv(0) <= '0'                                                   when nco_count(FCW_WIDTH-1) = nco_count(FCW_WIDTH-2) else ('0')         when reset else '1';
cos_inv(0) <= '0'                                                   when nco_count(FCW_WIDTH-1) = '0'                    else ('0')         when reset else '1';

sin_coeff <= std_logic_vector(-signed('0' & sin_out)) when sin_inv(1) else (others=>'0') when reset else '0' & sin_out;
cos_coeff <= std_logic_vector(-signed('0' & cos_out)) when cos_inv(1) else (others=>'0') when reset else '0' & cos_out;


-- count at oscillatorfcw rate, don't worry about rollover
-- use upper 2-bit to control lookup modifications (fwd/bkwd index and pos/neg data)
-- the next upper 11-bits will be the main lookup address (0 to 2047)
nco_step : process(all)
begin
  if rising_edge(Clock) then
      if reset then
        nco_count  <= (others => '0');
        sin_inv(1) <= '0';
        cos_inv(1) <= '0';
      else
        -- the following conditional is not really necessary except for reproducability of testbench results
        --if SampleInValid = '1' then
            nco_count  <= std_logic_vector(signed(nco_count) + oscillatorfcw);
            sin_inv(1) <= sin_inv(0);
            cos_inv(1) <= cos_inv(0);
        -- end if;
    end if;
  end if;
end process;


-- check for overflow through sign discrepancy and saturate output if detected; otherwise output (high-1 downto 0)
mixedsamplei <= pr_full(pr_full'high-1 downto 0)                                                   when     pr_full(pr_full'high) = pr_full(pr_full'high-1)  else
                (mixedsamplei'high => pr_full(pr_full'high), others => not(pr_full(pr_full'high))) when not(pr_full(pr_full'high) = pr_full(pr_full'high-1)) else
                (others=>'0');--                                                            when reset = '1';

mixedsampleq <= pi_full(pi_full'high-1 downto 0)                                                   when     pi_full(pi_full'high) = pi_full(pi_full'high-1)  else
                (mixedsampleq'high => pi_full(pi_full'high), others => not(pi_full(pi_full'high))) when not(pi_full(pi_full'high) = pi_full(pi_full'high-1)) else
                (others=>'0');--                                                            hen reset = '1';

-- overflow flag only goes high during the occurance of the overflow
OverflowStatus(1) <= '1' when not(pr_full(pr_full'high) = pr_full(pr_full'high-1)) else '0';
OverflowStatus(0) <= '1' when not(pi_full(pi_full'high) = pi_full(pi_full'high-1)) else '0';


  -- quarter-wave sine look-up table
  sin_lut : dual_port_rom
    generic map (
      addr_size => addr_size,
      data_size => data_size
    )
    port map (
      clock     => clock,
      reset     => reset,
      address1  => sin_addr,
      address2  => cos_addr,
      dataout1  => sin_out,
      dataout2  => cos_out
    );

  -- complex multiplier
  complex_mult_inst : genericcomplexmultiply
    generic map(
      lengtha     => samplei'length,
      lengthb     => cos_coeff'length,
      latency     => LATENCY,
      bitstotrunc => 1,
      bitstoround => data_size
    )
    port map(
      -- module inputs
      clock             => clock,
      reset             => reset,
      reala_in          => SampleI,
      imaga_in          => SampleQ,
      realb_in          => signed(cos_coeff),
      imagb_in          => signed(sin_coeff),
      SampleInValid     => SampleInValid,
      SampleInLast      => SampleInLast,
      SampleOutReady    => SampleOutReady,
      -- module outputs
      productreal       => pr_full,
      productimaginary  => pi_full,
      SampleOutValid    => SampleOutValid,
      SampleOutLast     => SampleOutLast,
      SampleInReady     => SampleInReady
    );

end behavioral;
