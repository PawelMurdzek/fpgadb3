-- Copyright (C) 2024  Intel Corporation. All rights reserved.
-- Your use of Intel Corporation's design tools, logic functions 
-- and other software and tools, and any partner logic 
-- functions, and any output files from any of the foregoing 
-- (including device programming or simulation files), and any 
-- associated documentation or information are expressly subject 
-- to the terms and conditions of the Intel Program License 
-- Subscription Agreement, the Intel Quartus Prime License Agreement,
-- the Intel FPGA IP License Agreement, or other applicable license
-- agreement, including, without limitation, that your use is for
-- the sole purpose of programming logic devices manufactured by
-- Intel and sold by Intel or its authorized distributors.  Please
-- refer to the applicable agreement for further details, at
-- https://fpgasoftware.intel.com/eula.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
library altera;
use altera.altera_syn_attributes.all;

entity pynq is
	port
	(
-- {ALTERA_IO_BEGIN} DO NOT REMOVE THIS LINE!

		CE : in std_logic;
		leds_4bits_tri_o : out std_logic_vector(3 downto 0);
		MISO : out std_logic;
		MOSI : in std_logic;
		record_data : out std_logic;
		SPI_clock : in std_logic;
		sys_clk : in std_logic;
		sys_rst : in std_logic
-- {ALTERA_IO_END} DO NOT REMOVE THIS LINE!

	);

-- {ALTERA_ATTRIBUTE_BEGIN} DO NOT REMOVE THIS LINE!
-- {ALTERA_ATTRIBUTE_END} DO NOT REMOVE THIS LINE!
end pynq;

architecture ppl_type of pynq is

-- {ALTERA_COMPONENTS_BEGIN} DO NOT REMOVE THIS LINE!
	component fpgadbg_spi
    generic (
      width       : integer;
      log2samples : integer);
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
-- {ALTERA_COMPONENTS_END} DO NOT REMOVE THIS LINE!
begin
-- {ALTERA_INSTANTIATION_BEGIN} DO NOT REMOVE THIS LINE!
start <='1';
  --stop <='0';
  -- Process for starting and stopping of the timer
  st1 : process (sys_rst,start)--start, stop,
  begin  -- process st1
    if sys_rst = '0' then
      count_a <= '0';
      leds_4bits_tri_o <= "0001";
   -- else
    elsif start = '1' then
      count_a <= '1';
      leds_4bits_tri_o <= "0011";
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
  
  fpgadbg_spi_1 : fpgadbg_spi
    generic map (
      width       => 33,
      log2samples => 10)
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
-- {ALTERA_INSTANTIATION_END} DO NOT REMOVE THIS LINE!

end;

