------------------------------------------------------------------------------------------------------
--! @Author:         Anthony A. Stock (GRC-LCI0)[NIP]
--! @Creation-Date:  1 November 2020
--! @Module-Name:    Maximum Function
--! @Project-Name:   Space Telecommunications Radio System
--! @Target-Device:  xc7z045fbg676-1
--! @Vivado-Version: 2019.1.3
--! @Git-Tag:        xxxx
--!
--! @Version: 1.0
--! Anthony A. Stock (GRC-LCI0)[NIP] -- File created.
--!
--! @ToDo: Ideally, the VHDL-2008 function "MAXIMUM" would be used, but  it is not supported in 
--! Vivado versions under 2020.2.  If using a newer version of Vivado replace this function with the 
--! native one.  After 2020.2 is normalized, this file becomes obsolete.
------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! @Module-Description
--! This module contains the implementation of the max() function,
--! which returns the greater of the two arguments.
package max_pkg is
  function MAX(LEFT, RIGHT: INTEGER) return INTEGER;
end max_pkg;

package body max_pkg is
  function MAX(LEFT, RIGHT: INTEGER) return INTEGER is
  begin
    if LEFT > RIGHT then 
        return LEFT;
    else 
        return RIGHT;
    end if; -- comp
  end; -- max
  
end max_pkg;
