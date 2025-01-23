-------------------------------------------------------------------------------
-- Title      : sampler - three state probe sampling
-- Project    : fpgadbg3
-------------------------------------------------------------------------------
-- File       : sampler.vhd
-- Author     : Pawel A. Murdzek
-- University : Warsaw University of Technology, ISE
-- Created    : 2023-12-31
-- Last update: 2023-12-31
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Simple debouncer using 2-bit shift register flip flops 
-- and majority voting to debounce clock and data signals. 
-- This code has been written from scratch, however it was
-- inspired by many different existing sampler implementations.
-- Therefore please consider this code to be PUBLIC DOMAIN
-- No warranty of any kind!!!
-------------------------------------------------------------------------------
-- Copyright (c) 2023 Pawel A. Murdzek (pawel.murdzek.stud@pw.edu.pl) 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2023-12-18  1.0      pmurdzek      Created
-------------------------------------------------------------------------------
--  
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
--
--  IMPORTANT EXTENSION OF YOUR RIGHTS:
--  You may also link this code with any other VHDL, Verilog, EDIF or other similar
--  code and distribute the resulting FPGA core in a binary form (as a configuration
--  bitstream or programmed FLASH memory or programmed FPGA chips) without the need
--  to disclose sources of your design (unless the license for that other code
--  disallows that).
--
--
-------------------------------------------------------------------------------


library ieee;
use     ieee.std_logic_1164.all;
use     ieee.std_logic_unsigned.all;
use     ieee.std_logic_misc.all;
use     ieee.numeric_std.all;
use     ieee.std_logic_arith.all;

entity sampler is
    Port(   clock               : in std_logic; --On-board ZYBO clock (125MHz)
            reset               : in std_logic;
			sampling_enable     : in std_logic; 
            samples_in          : in std_logic;   --read line
            samples_out         : out std_logic --return sampled
            );
end sampler;

architecture Behavioral of sampler is

signal smpl : std_logic_vector(1 downto 0) := (others => '0');

begin
	-- This process samples the samples_in line three times and uses the majority voting
	  -- to assess the state of the line
	  rcv_smpl : process (clock, reset)
	  begin  -- process rcv_smpl
		if reset = '0' then                  -- asynchronous reset (active low)
		  smpl <= (others => '1');
		elsif (clock'event and clock = '1') then  -- rising clock edge
		  if sampling_enable = '1' then
			smpl(1) <= smpl(0);
			smpl(0) <= samples_in;
			if (smpl(1) = '1' and smpl(0) = '1') or
			  (smpl(1) = '1' and samples_in = '1') or
			  (smpl(0) = '1' and samples_in = '1') then
			  samples_out <= '1';
			else
			  samples_out <= '0';
			end if;
		  else
			samples_out <= samples_in;
		  end if;
		end if;
	  end process rcv_smpl;

end Behavioral;
