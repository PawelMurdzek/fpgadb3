-------------------------------------------------------------------------------
-- Title      : Tang Nano 20K Board top module for communication with FPGADBG SPI CONVERTER
-- Project    : fpgadbg3
-------------------------------------------------------------------------------
-- File       : tang20k.vhd
-- Author     : Pawel A. Murdzek
-- University : Warsaw University of Technology, ISE
-- Created    : 2024-11-11
-- Last update: 2025-01-10
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: The code below is a example implementation of the fpgadbg 
-- interface as slave with some master device this file is exacly for Tang Nano 20K Board,
-- but can be used with many different boards 
-- with the fpgadbg core therefore it does not use buffering. 
-- This code has been written from scratch. Inspired by MANY sources.
-- Consider it to be a PUBLIC DOMAIN code. No warranty of any kind!!!
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
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity fpgadbg_tang20k is
  
  port (
    LED_OUT                   : out std_logic_vector(2 downto 0);
    sys_rst                   : in  std_logic;
    MOSI                 	  : in  std_logic;
    MISO      	              : out std_logic;
    sys_clk                   : in  std_logic;
	CE 						  : in  std_logic;
	SPI_clock				  : in  std_logic;
	record_data               : out std_logic
	);

end fpgadbg_tang20k;

architecture arch1 of fpgadbg_tang20k is

  component fpgadbg_spi
    generic (
      width       : integer;
      log2samples : integer;
      num_of_signals: integer);
    port (
      trigger                 : in  std_logic;
      data_in                 : in  std_logic_vector((width-1) downto 0);
      mosi                    : in  std_logic;
      miso                    : out std_logic;
      --dbg                     : out std_logic_vector(10 downto 0);
      sys_clk                 : in  std_logic;
      nrst                    : in  std_logic;
	  CE 		              : in std_logic;
	  fpga_spi_clock          : in std_logic;
	  record_data             : out std_logic 
	  );
  end component;

  type   bcdi is array(3 downto 0) of integer range 0 to 9;
  signal d : bcdi := (0, 0, 0, 0);

  signal   trigger        : std_logic;
  signal   data_in        : std_logic_vector(32 downto 0);
  signal   freqdiv        : integer   := 0;    -- divider producing 100Hz clock
  signal   count, count_a : std_logic := '0';  -- timer's state

  signal   start          : std_logic;         -- start the timer
  --signal stop           : std_logic;         -- stop the timer
----------------------------------------------------------  
--debug signals  
  --signal dbg            : std_logic_vector(7 downto 0);
  --signal   dbg_display    : std_logic_vector(10 downto 0);
  --signal internal_mosi  : std_logic;          -- for debugging
  --signal internal_CE    : std_logic;            -- for debugging
-----------------------------------------------------------

begin 
  start <='1';
  --stop <='0';
  -- Process for starting and stopping of the timer
  st1 : process (sys_rst,start)--start, stop,
  begin  -- process st1
    if sys_rst = '0' then
      count_a <= '0';
      LED_OUT(1 downto 0) <= "01";
    else
   -- elsif start = '1' then
      count_a <= '1';
      LED_OUT(1 downto 0) <= "00";
   -- elsif stop = '1' then
   --   count_a <= '0';
    end if;
  end process st1;
  -- Process for synchronization of the timer start and stop
  cnt1 : process (sys_clk, sys_rst)
  begin  -- process cnt1
    if sys_rst = '0' then               -- asynchronous reset (active high)
      count <= '0';
    elsif sys_clk'event and sys_clk = '1' then  -- rising clock edge
      count <= count_a;
    end if;
  end process cnt1;

  -- The main process of the timer
  process (sys_clk, sys_rst)
  begin  -- process
    if sys_rst = '0' then               -- asynchronous reset (active high)
      d(0) <= 0;
      d(1) <= 0;
      d(2) <= 0;
      d(3) <= 0;
    elsif sys_clk'event and sys_clk = '1' then  -- rising clock edge
      freqdiv <= freqdiv+1;
      if freqdiv = 100 then
        freqdiv <= 0;
        if count = '1' then
          d(0) <= d(0) + 1;
          if d(0) = 9 then
            d(1) <= d(1) + 1;
            d(0) <= 0;
            if d(1) = 9 then
              d(2) <= d(2) + 1;
              d(1) <= 0;
              if d(2) = 9 then
                d(3) <= d(3) + 1;
                d(2) <= 0;
                if d(3) = 9 then
                  d(3) <= 0;
                end if;
              end if;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Connection of the debug interface
  data_in(20 downto 0)  <= std_logic_vector(to_unsigned(freqdiv, 21));
  data_in(32 downto 21) <= "111111111111";
--  data_in(32 downto 0) <= "100000000000000110000000110111110";

  trigger <= '1' when d(1) = 1 else '0';
  LED_OUT(2) <= '1';
   --LED_OUT <= "0" & dbg_display(2 downto 0);

  --rgbLED_OUT <= dbg_display(4 downto 3) & "0000";
  fpgadbg_spi_1 : fpgadbg_spi
    generic map (
      width       => 33,
      log2samples => 10,
      num_of_signals => 2)
    port map (
      sys_clk        => sys_clk,
      trigger        => trigger,
      data_in        => data_in,
      mosi           => MOSI,--internal_mosi,
      miso           => MISO,
      --dbg          => dbg_display
      nrst           => sys_rst,
	  CE 	         => CE,--internal_CE,
	  record_data    => record_data,
	  fpga_spi_clock => SPI_clock
      
	  );
end arch1;
