-------------------------------------------------------------------------------
-- Title      : fpgadbg_spi - interface between the fpgadbg and SPI
-- Project    : fpgadbg3
-------------------------------------------------------------------------------
-- File       : fpgadbg_spi.vhd
-- Author     : Pawel A. Murdzek
-- University : Warsaw University of Technology, ISE
-- Created    : 2023-12-18
-- Last update: 2025-01-08
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Functional wrapper for communication with fpgadbg memory and  
-- outside interface by an SPI protocol
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
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
library work;

entity fpgadbg_spi is
  generic (
    width       : integer := 35;
    log2samples : integer := 10);
  port (
    trigger         : in  std_logic;
    data_in         : in  std_logic_vector((width-1) downto 0);
    mosi            : in  std_logic;
    miso            : out std_logic;
    --dbg     : out std_logic_vector(10 downto 0);
    xconf           : out std_logic_vector(2 downto 0);
    sys_clk         : in  std_logic;            -- system clock
    nrst            : in  std_logic;             -- reset (active low)
	fpga_spi_clock  : in std_logic;  
	record_data     : out std_logic; --sygnal sygnalizujacy poczatek i koniec wysylania danych do mastera
	CE 		        : in std_logic
    );
end fpgadbg_spi;

architecture syn of fpgadbg_spi is

  component fpgadbg
    generic (
      outwidth    : integer;
      width       : integer;
      log2samples : integer);
    port (
      wr_clk          : in  std_logic;
      trigger         : in  std_logic;
      wr_init         : in  std_logic;
      data_in         : in  std_logic_vector((width-1) downto 0);
      post_tr_samples : in  integer range 0 to 65535;
      triggered       : out std_logic;
      completed       : out std_logic;
      rd_init         : in  std_logic;
      rd_finished     : out std_logic;
      rd_clk          : in  std_logic;
      out_data        : out std_logic_vector((outwidth-1) downto 0));
  end component;

  component spiControl
    port (
			clock                       : in std_logic; --On-board ZYBO clock (125MHz)
            reset                       : in std_logic;
            data_in                     : in std_logic;   --read line
            done_config                 : in std_logic; --Signal indicates data has been sent over SPI interface
			byte_out                    : out std_logic_vector(7 downto 0); -- odebrany bajt konfiguracyjny
			CE                          : in std_logic;
			SPI_clock                   : in std_logic;
			ready_to_receive            : in std_logic;
			config_bytes_received       : out std_logic;
			ready_to_send_to_master     : in std_logic;
			data_MISO                   : in std_logic_vector(7 downto 0);
			bit_MISO                    : out std_logic;
			done_send                   : out std_logic;
			data_send_finished          : in std_logic;
			finished_data_transfer      : in std_logic;
			start_MISO_transfer         : in std_logic;
			clock_sampled_out           : out std_logic;
			--dbg     : out std_logic_vector(10 downto 0)
			enable_read_spi             : out std_logic
        );
  end component;

  signal wr_init, rd_init, rd_clk, rd_finished, triggered, completed : std_logic;
  signal miso_ready, rs_wr, rs_rd, rs_dav                            : std_logic;
  signal post_tr_samples                                             : integer;
  signal post_tr_vec                                                 : std_logic_vector(15 downto 0);
  signal rs_din, rs_dout, out_data                                   : std_logic_vector(7 downto 0); --out data wychodzi z fpgadbg i potem jest wpisywane do rs_din
  signal transmit_MISO												 : std_logic;
  signal config_ctrl : integer := 0;
  signal finished_data_transfer: std_logic;

  type   T_CTRL_STATE is (
  ST_IDLE, 
  ST_WAIT_ACQ,
  ST_SEND_DATA,
  ST_SEND_DATA_C0
  );
  signal ctrl_state : T_CTRL_STATE := ST_IDLE;
  --signal state_debug: std_logic_vector(1 downto 0):= (others => '0');
  signal done_config_tmp_spi : std_logic;
  signal clock_sampled_spi: std_logic;
  
begin

  fpgadbg_1 : fpgadbg
    generic map (
      outwidth    => 8,
      width       => width,
      log2samples => log2samples)
    port map (
      wr_clk          => sys_clk,
      trigger         => trigger,
      wr_init         => wr_init,
      data_in         => data_in,
      post_tr_samples => post_tr_samples,
      triggered       => triggered,
      completed       => completed,
      rd_init         => rd_init,
      rd_finished     => rd_finished,
      rd_clk          => rd_clk,
      out_data        => out_data);

  spi_1 : spiControl
    port map (
	  clock                   => sys_clk,
	  reset                   => nrst,
	  data_in                 => mosi,
	  done_config             => done_config_tmp_spi,
	  data_MISO               => rs_dout,
	  spi_clock               => fpga_spi_clock,
	  byte_out                => rs_din,
	  CE		              => CE,
	  config_bytes_received   => rs_dav,
	  ready_to_receive        => rs_rd,
	  ready_to_send_to_master => transmit_MISO,
	  bit_MISO                => miso,
	  done_send               => miso_ready,
	  data_send_finished      => rd_finished,
	  finished_data_transfer  => finished_data_transfer,
	  start_MISO_transfer     => rs_wr,
	  enable_read_spi         => record_data,
	  --dbg     =>dbg,
	  clock_sampled_out       => clock_sampled_spi
	  );

  post_tr_samples <= conv_integer(post_tr_vec);
  -- The line below was used to debug the fpgadbg_spi itself...
  --dbg             <= (0 => rd_init, 1 => wr_init, 2 => triggered, 3 => completed, 4 => rd_finished, others => '0');
  -----------------------------------------------------------------------------
  -- Main process
  -----------------------------------------------------------------------------
  pmain : process (nrst, clock_sampled_spi)--sys_clk
  begin  -- process pmain
    if nrst = '0' then                  -- asynchronous reset (active low)
      rd_clk     <= '0';
      rd_init    <= '0';
      wr_init    <= '0';
      rs_rd      <= '0';
      transmit_MISO <= '0';
      config_ctrl <= 0;
      done_config_tmp_spi <= '0';
      finished_data_transfer <= '0';
      ctrl_state <= ST_IDLE;
    elsif clock_sampled_spi'event and clock_sampled_spi = '1' then  -- rising clock edge
      rd_clk <= '0';
      case ctrl_state is
        when ST_IDLE =>
		  transmit_MISO <= '0';
		  rs_rd  <= '1';
		  --record_data <= '0';
          if rs_dav = '1' then
            config_ctrl <= config_ctrl + 1;
            -- The SPI has received a character
            if rs_din(7 downto 6) = "00" then
              -- reset the fpgadbg core, and store the lower bits
              -- of post_tr_samples
              post_tr_vec(5 downto 0) <= rs_din(5 downto 0);
              wr_init                 <= '0';
              rd_init                 <= '0';
              rs_rd                   <= '1';
            elsif rs_din(7 downto 6) = "01" then
              -- write the higher bits of post_tr_samples
              post_tr_vec(11 downto 6) <= rs_din(5 downto 0);
              rs_rd                    <= '1';
            else
              -- store the most significant bits of post_tr_samples
              post_tr_vec(15 downto 12) <= rs_din(3 downto 0);
              -- next three bits may be used to switch the active configuration
              xconf                     <= rs_din(6 downto 4);
              -- start the data acquisition
--------------------------------------------------------------------------
			  done_config_tmp_spi 		<= '1';
			  rd_init                   <= '0';
			  wr_init                   <= '1';
			  rs_rd                     <= '1';
			  finished_data_transfer <= '0';
			  ctrl_state                <= ST_WAIT_ACQ;
            end if;
          end if;
		 
		when ST_WAIT_ACQ =>
          -- we are waiting until the acquisition finishes
          if completed = '1' then
            -- all data are recorded, we can transmit them
			transmit_MISO <= '1';
            rd_init    <= '1';
            ctrl_state <= ST_SEND_DATA;
          end if;
		  
		  
        when ST_SEND_DATA =>
          if rd_finished = '1' then
            -- all data have been transfered, go to the IDLE STATE
            ctrl_state <= ST_IDLE;
            finished_data_transfer <= '1';
          elsif miso_ready = '1' then
            -- if transmitter is ready, send the next byte
            rs_wr      <= '1';
            rd_clk     <= '1';
            rs_dout    <= out_data;
            ctrl_state <= ST_SEND_DATA_C0;
          end if;
		  
        when ST_SEND_DATA_C0 =>
            rd_clk     <= '0';
            rs_dout    <= out_data;
            ctrl_state <= ST_SEND_DATA;
            
		when others => null;
		
      end case;
    end if;
    --dbg(4 downto 3) <= state_debug; 
  end process pmain;

end syn;
