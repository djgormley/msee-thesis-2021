------------------------------------------------------------------------------------------------------
--! @Author:         Dylan J. Gormley (NASA GRC/LCI)
--! @Creation-Date:  1 November 2020
--! @Module-Name:    Accumulator
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.1.3
--! @Git-Tag:        xxxx
--! 
--! @Version: 1.0
--! Dylan J. Gormley (GRC-LCI0) - File created.
------------------------------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.math_real.all;

--! @Module-Description
--! This module serially accumulates input samples by adding the current sample
--! with a running total (Sum) of the previous samples. When the last signal is
--! received, the Sum is reset. In this way the module is able to function as an
--! "integrate and dump" circuit.
entity Accumulator is
  generic (
    N_SAMPLES      : natural := 2**16; --! number of samples until last
    BIT_WIDTH      : natural := 16     --! resolution of sample
  );
  port (
    -- inputs
    Clock          : in  std_logic; --! 
    Reset          : in  std_logic; --! synchronous, active high

    SampleOutReady : in  std_logic; --! active high
    SampleInValid  : in  std_logic; --! active high
    SampleInLast   : in  std_logic; --! active high
    SampleIn       : in  signed(BIT_WIDTH-1 downto 0); --! s.x

    -- outputs
    SampleInReady  : out std_logic; --! active high
    SampleOutValid : out std_logic; --! active high
    SampleOutLast  : out std_logic; --! active high, dump enable
    SampleOut      : out signed(BIT_WIDTH-1 downto 0) --! s.x
  );
end Accumulator;

architecture rtl of Accumulator is

  ------------------------------------------------------------------------------------------------------
  -- Constants
  ------------------------------------------------------------------------------------------------------
  constant DEBUG       : string  := "true";
  --constant NORM_FACTOR : natural := natural(ceil(log2(real(N_SAMPLES)))) + natural(BIT_WIDTH); -- theoretically the best norm factor
  constant NORM_FACTOR : natural := 28; -- found experimentally, so check here if debugging

  ------------------------------------------------------------------------------------------------------
  -- Signals
  ------------------------------------------------------------------------------------------------------
  signal Sum : signed(NORM_FACTOR-1 downto 0) := (others => '0'); -- running total

  ------------------------------------------------------------------------------------------------------
  -- Attributes
  ------------------------------------------------------------------------------------------------------
--  attribute mark_debug                   : string;
--  attribute mark_debug of Reset          : signal is DEBUG;
--  attribute mark_debug of SampleOutReady : signal is DEBUG;
--  attribute mark_debug of SampleInValid  : signal is DEBUG;
--  attribute mark_debug of SampleInLast   : signal is DEBUG;
--  attribute mark_debug of SampleIn       : signal is DEBUG;
--  attribute mark_debug of SampleInReady  : signal is DEBUG;
--  attribute mark_debug of SampleOutValid : signal is DEBUG;
--  attribute mark_debug of SampleOutLast  : signal is DEBUG;
--  attribute mark_debug of SampleOut      : signal is DEBUG;
--  attribute mark_debug of Sum            : signal is DEBUG;

begin

  ------------------------------------------------------------------------------------------------------
  -- Accumulator
  ------------------------------------------------------------------------------------------------------
  accumulator : process(all)
  begin

    if rising_edge(Clock) then

      if Reset then
        Sum              <= (others => '0');
        SampleInReady    <= '0';
        SampleOutValid   <= '0';
        SampleOutLast    <= '0';
        SampleOut        <= (others => '0');

      else
        if SampleInValid then
          -- dump
          if SampleInLast then
            Sum <= resize(SampleIn, Sum'length);
          -- integrate
          else
            Sum <= resize(SampleIn+Sum, Sum'length);
          end if; -- integrate & dump condition

          SampleOutLast  <= SampleInLast; 
          SampleOutValid <= SampleInValid;
          SampleInReady  <= SampleOutReady;

        -- else hold value
        end if; -- validity condition

        -- scale to s.x
        SampleOut        <= Sum(Sum'high downto Sum'high-BIT_WIDTH+1);

     end if; -- reset condition
    end if; -- clock condition

  end process accumulator;




end rtl;
