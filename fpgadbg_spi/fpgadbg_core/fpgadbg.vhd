-------------------------------------------------------------------------------
-- Title      : fpgadbg - core for debugging of FPGA implemented cores
-- Project    : 
-------------------------------------------------------------------------------
-- File       : fpgadbg_tb.vhd
-- Author     : Wojciech M. Zabolotny, Pawel A. Murdzek
-- Company    : 
-- Created    : 2006-07-08
-- Last update: 2024-01-24
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2006 Wojciech M. Zabolotny (wzab@ise.pw.edu.pl) 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2006-07-08  1.0      wzab      Created
-- 2024-01-24  1.1      wzab      Updated to give out more information
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;

entity fpgadbg is
  generic (
    outwidth    : integer := 8;
    width       : integer := 35;
    log2samples : integer := 10;
    num_of_signals: integer := 1
    );
  port (wr_clk          : in  std_logic;
        trigger         : in  std_logic;
        wr_init         : in  std_logic;
        data_in         : in  std_logic_vector((width-1) downto 0);
        post_tr_samples : in  integer range 0 to 65535;
        triggered       : out std_logic;
        completed       : out std_logic;
        rd_init         : in  std_logic;
        rd_finished     : out std_logic;
        rd_clk          : in  std_logic;
        out_data        : out std_logic_vector((outwidth-1) downto 0)
        );
end fpgadbg;

architecture syn of fpgadbg is

  component fpgadbg_mem
    generic (
      width    : integer;
      addrbits : integer);
    port (
      clk1  : in  std_logic;
      addr1 : in  std_logic_vector((addrbits-1) downto 0);
      we1   : in  std_logic;
      din1  : in  std_logic_vector((width-1) downto 0);
      dout1 : out std_logic_vector((width-1) downto 0);
      clk2  : in  std_logic;
      addr2 : in  std_logic_vector((addrbits-1) downto 0);
      dout2 : out std_logic_vector((width-1) downto 0));
  end component;

  type T_RD_STATE is (ST_RD_START, ST_RD_TRIG_POS, ST_RD_TRIG_POS_LSB,
                      ST_RD_STOP_POS, ST_RD_STOP_POS_LSB,
                      ST_RD_DATA, ST_RD_FINISHED, ST_RD_WIDTH, ST_NUM_OF_SIGNALS);
  signal rd_state, rd_state_nxt : T_RD_STATE;

  signal cnt_in                     : integer range 0 to ((2**log2samples)-1);  -- counter of input samples;
  signal trig_pos                   : integer range 0 to ((2**log2samples)-1);  -- trigger position;
  signal stop_pos                   : integer range 0 to ((2**log2samples)-1);
  signal post_cnt                   : integer range 0 to 65535;
  signal rd_smp_cnt, rd_smp_cnt_nxt : integer range 0 to ((2**log2samples)-1);
  signal dbg_dout                   : std_logic_vector((width-1) downto 0);

  signal s_filled, s_triggered, s_completed, dbg_we : std_logic;

  signal wr_addr : std_logic_vector((log2samples-1) downto 0);
  signal rd_addr : std_logic_vector((log2samples-1) downto 0);

  signal trig_pos_vec : std_logic_vector(15 downto 0);
  signal stop_pos_vec : std_logic_vector(15 downto 0);

  
  constant words_per_sample : integer := (width+(outwidth-1))/outwidth;
  constant num_of_samples   : integer := 2**log2samples;

  signal rd_wrd_mux_sel, rd_wrd_mux_sel_nxt : integer range 0 to (words_per_sample-1);

  -----------------------------------------------------------------------------
  -- Alternative implementation of mux - sometimes better suited for synthesis
  -----------------------------------------------------------------------------
  function out_mux2 (
    constant in_width       : in integer;  -- input data width
    constant out_width      : in integer;  -- output data width
    constant data           :    std_logic_vector;
    constant num_off_nibble : in integer)
    return std_logic_vector is

    variable result    : std_logic_vector((out_width-1) downto 0);
    variable bit_shift : integer;

  begin
    result    := (others => '0');
    bit_shift := num_off_nibble*out_width;
    for i in 0 to out_width-1 loop
      if i+bit_shift >= 0 and i+bit_shift <= in_width-1 then
        result(i) := data(i+bit_shift);
      end if;
    end loop;  -- i
    return result;
  end out_mux2;

begin
  
  fpgadbg_mem_1 : fpgadbg_mem
    generic map (
      width    => width,
      addrbits => log2samples)
    port map (
      clk1  => wr_clk,
      addr1 => wr_addr,
      we1   => dbg_we,
      din1  => data_in,
      dout1 => open,
      clk2  => rd_clk,
      addr2 => rd_addr,
      dout2 => dbg_dout);
  wr_addr   <= std_logic_vector(to_unsigned(cnt_in, log2samples));
  -- At the READ we address the memory with the NEXT address to compensate
  -- delay associated with the registred output
  rd_addr   <= std_logic_vector(to_unsigned(rd_smp_cnt_nxt, log2samples));
  triggered <= s_triggered;
  completed <= s_completed;

  -- Convert the trigger and stop positions into the bit vectors, to facilitate
  -- sending of these values over the narrow interfaces (like SPI)
  trig_pos_vec <= std_logic_vector(to_unsigned(trig_pos, 16));
  stop_pos_vec <= std_logic_vector(to_unsigned(stop_pos, 16));
  -- Process collecting the data
  mp1 : process (wr_clk, wr_init)
  begin  -- process mp1
    if wr_init = '0' then               -- asynchronous reset (active low)
      cnt_in      <= 0;
      trig_pos    <= 0;
      s_triggered <= '0';
      s_filled    <= '0';
      s_completed <= '0';
      dbg_we      <= '1';
    elsif wr_clk'event and wr_clk = '1' then  -- rising clock edge
      if s_triggered = '0' then
        -- Not triggered yet
        if trigger = '1' then
          s_triggered <= '1';
          trig_pos    <= cnt_in;
          post_cnt    <= post_tr_samples;
        end if;
      else
        -- We have been triggered
        if post_cnt = 0 then
          if s_completed = '0' then
            dbg_we      <= '0';
            stop_pos    <= cnt_in;
            s_completed <= '1';
          end if;
        else
          post_cnt <= post_cnt -1;
        end if;
      end if;
      if cnt_in <= num_of_samples-2 then
        cnt_in <= cnt_in + 1;
      else
        s_filled <= '1';
        cnt_in   <= 0;
      end if;
    end if;
  end process mp1;


  -- Two process implementation of reading of the data
  -- The sequential process
  rds1 : process (rd_clk, rd_init)
  begin  -- process rds1
    if rd_init = '0' then               -- asynchronous reset (active low)
      rd_smp_cnt     <= 0;
      rd_wrd_mux_sel <= 0;
      rd_state       <= ST_RD_START;
    elsif rd_clk'event and rd_clk = '1' then  -- rising clock edge
      rd_smp_cnt     <= rd_smp_cnt_nxt;
      rd_wrd_mux_sel <= rd_wrd_mux_sel_nxt;
      rd_state       <= rd_state_nxt;
    end if;
  end process rds1;

  rd1 : process (dbg_dout, rd_smp_cnt, rd_state, rd_wrd_mux_sel, s_filled,
                 stop_pos_vec, trig_pos_vec)
  begin  -- process rd1
    -- Defaults first, to avoid latches
    rd_smp_cnt_nxt     <= rd_smp_cnt;
    rd_wrd_mux_sel_nxt <= rd_wrd_mux_sel;
    rd_state_nxt       <= rd_state;
    rd_finished        <= '0';
    out_data           <= (others => '0');
    case rd_state is
      when ST_RD_START =>
        out_data     <= s_filled & std_logic_vector(to_unsigned(log2samples, outwidth-1));
        rd_state_nxt <= ST_RD_WIDTH;
      when ST_RD_WIDTH =>
        out_data     <= std_logic_vector(to_unsigned(width, outwidth));
        rd_state_nxt <= ST_NUM_OF_SIGNALS;
      when ST_NUM_OF_SIGNALS =>
      out_data     <= std_logic_vector(to_unsigned(num_of_signals, 8));
      rd_state_nxt <= ST_RD_TRIG_POS;
      when ST_RD_TRIG_POS =>
        out_data <= out_mux2(16, outwidth, trig_pos_vec, 0);
        if outwidth >= 16 then
          rd_state_nxt <= ST_RD_STOP_POS;
        else
          rd_state_nxt <= ST_RD_TRIG_POS_LSB;
        end if;
      when ST_RD_TRIG_POS_LSB =>
        out_data     <= out_mux2(16, outwidth, trig_pos_vec, 1);
        rd_state_nxt <= ST_RD_STOP_POS;
      when ST_RD_STOP_POS =>
        out_data <= out_mux2(16, outwidth, stop_pos_vec, 0);
        if outwidth >= 16 then
          rd_smp_cnt_nxt     <= 0;
          rd_wrd_mux_sel_nxt <= 0;
          rd_state_nxt       <= ST_RD_DATA;
        else
          rd_state_nxt <= ST_RD_STOP_POS_LSB;
        end if;
      when ST_RD_STOP_POS_LSB =>
        out_data           <= out_mux2(16, outwidth, stop_pos_vec, 1);
        rd_smp_cnt_nxt     <= 0;
        rd_wrd_mux_sel_nxt <= 0;
        rd_state_nxt       <= ST_RD_DATA;
      when ST_RD_DATA =>
        out_data <= out_mux2(width, outwidth, dbg_dout, rd_wrd_mux_sel);
        if(rd_wrd_mux_sel < (words_per_sample-1)) then
          rd_wrd_mux_sel_nxt <= rd_wrd_mux_sel + 1;
        else
          if rd_smp_cnt < num_of_samples-1 then
            rd_smp_cnt_nxt     <= rd_smp_cnt + 1;
            rd_wrd_mux_sel_nxt <= 0;
          else
            -- All data have been read
            rd_state_nxt <= ST_RD_FINISHED;
          end if;
        end if;
      when ST_RD_FINISHED =>
        rd_finished <= '1';
        -- Just do nothing
        null;
      when others => null;
    end case;
  end process rd1;
end syn;
