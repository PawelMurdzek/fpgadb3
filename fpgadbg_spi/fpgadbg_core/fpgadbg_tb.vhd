-------------------------------------------------------------------------------
-- Title      : Testbench for design "fpgadbg"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : fpgadbg_tb.vhd
-- Author     : 
-- Company    : 
-- Created    : 2024-07-08
-- Last update: 2024-07-08
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2006 Paweł A. Murdzek
-- This code is "public domain" work
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2006-07-08  1.0      wzab      Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use std.textio.all;

-------------------------------------------------------------------------------

entity fpgadbg_tb is

end fpgadbg_tb;

-------------------------------------------------------------------------------

architecture test of fpgadbg_tb is
  
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

  -- component generics
  constant outwidth    : integer := 16;
  constant width       : integer := 21;
  constant log2samples : integer := 9;

  -- component ports
  -- signal clk             : std_logic;
  signal trigger         : std_logic                := '0';
  signal rst             : std_logic                := '0';
  signal wr_init         : std_logic                := '0';
  signal data_in         : std_logic_vector((width-1) downto 0);
  signal post_tr_samples : integer range 0 to 65535 := 300;
  signal triggered       : std_logic                := '0';
  signal completed       : std_logic                := '0';
  signal rd_init         : std_logic                := '0';
  signal rd_finished     : std_logic                := '0';
  signal rd_clk          : std_logic                := '0';
  signal out_data        : std_logic_vector((outwidth-1) downto 0);
  signal out_val         : integer;

  signal run : std_logic := '1';

  -- Signals emulating the debugged system
  signal counter_nb : unsigned(9 downto 0) := (others => '0');
  signal lsr        : unsigned(9 downto 0) := (others => '0');
  -- clock
  signal Clk        : std_logic            := '1';
  signal dbg_clk    : std_logic            := '1';

  
begin  -- test

  -- component instantiation
  DUT : fpgadbg
    generic map (
      outwidth    => outwidth,
      width       => width,
      log2samples => log2samples)
    port map (
      wr_clk          => dbg_clk,
      trigger         => trigger,
      wr_init         => rst,
      data_in         => data_in,
      post_tr_samples => post_tr_samples,
      triggered       => triggered,
      completed       => completed,
      rd_init         => rd_init,
      rd_finished     => rd_finished,
      rd_clk          => rd_clk,
      out_data        => out_data);

  -- Definition of the input record (it should match the signal
  -- assignments description used when creating the fpgadbg_conv
  -- object in the Python code)
  data_in(20 downto 11) <= std_logic_vector(counter_nb);
  data_in(10)           <= Clk;
  data_in(9 downto 0)   <= std_logic_vector(lsr);


  -- clock generation
  Clk <= not Clk after 10 ns when run = '1' else '0';

  dbg_clk <= not dbg_clk after 5 ns when run = '1' else '0';

  -- The counter process
  process (clk, rst)
  begin  -- process
    if rst = '0' then                   -- asynchronous reset (active low)
      counter_nb <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
      counter_nb <= counter_nb + 1;
    end if;
  end process;

  -- Linear shift register
  process (clk, rst)
  begin  -- process
    if rst = '0' then                   -- asynchronous reset (active low)
      lsr <= (1 => '1', others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
      lsr <= lsr(8 downto 0) & (lsr(9) xor lsr(3));
    end if;
  end process;

  trigger <= '1' when counter_nb(9 downto 7) = "111" else '0';

  -- waveform generation
  WaveGen_Proc : process
    file dbg_file     : text;
    variable dbg_line : line;

  begin
------------------ 
  --  wait until Clk = '1';
    -- insert signal assignments here
    -- initialize the system
   -- rst     <= '0';
   -- wr_init <= '0';
   -- rd_init <= '0';
   -- wait for 5 ns;
   -- rst     <= '1';
   -- wait for 100 ns;
    -- start the acquisition of the data
   -- wr_init <= '1';

    -- wait until the acquisition completes
   -- wait until completed = '1';
    -- read the recorded data, writing results to the text file
    -- which will be used then by the conversion utility
    -- First open the file
  
   -- file_open(dbg_file, "dbg.out", write_mode);
   -- rd_init <= '1';
   -- while rd_finished = '0' loop
   --   write(dbg_line, conv_integer(out_data));
   --   writeline(dbg_file, dbg_line);
   --   rd_clk <= '1';
   --   wait for 5 ns;
   --   rd_clk <= '0';
   --   wait for 5 ns;
   -- end loop;
   -- file_close(dbg_file);
   -- run <= '0';
  end process WaveGen_Proc;

end test;

-------------------------------------------------------------------------------

configuration fpgadbg_tb_test_cfg of fpgadbg_tb is
  for test
  end for;
end fpgadbg_tb_test_cfg;

-------------------------------------------------------------------------------
