-------------------------------------------------------------------------------
-- Title      : testbench PYNQ-Z2 Board top module for communication with FPGADBG SPI CONVERTER
-- Project    : fpgadbg3
-------------------------------------------------------------------------------
-- File       : pynq.vhd
-- Author     : Pawel‚ A. Murdzek
-- University : Warsaw University of Technology, ISE
-- Created    : 2024-11-12
-- Last update: 2024-11-18
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: The code below is testbench for looking inside the code for 
-- PYNQ-Z2 board. Might be usefull for checking whether the signals inside 
-- the FPGAs are correct for developement in new boards
-- This code has been written from scratch. Inspired by MANY sources.
-- Consider it to be a PUBLIC DOMAIN code. No warranty of any kind!!!
-------------------------------------------------------------------------------
-- Copyright (c) 2023 Pawel‚ A. Murdzek (pawel.murdzek.stud@pw.edu.pl) 
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


-- Testbench for pynq.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity test_bit_transfer is
end test_bit_transfer;

architecture behavior of test_bit_transfer is

    -- Component declaration for the Unit Under Test (UUT)
    component fpgadbg_s3sb
        port(
            CE    : in  std_logic;
            SPI_clock : in  std_logic;
            MOSI  : in  std_logic;
            sys_rst : in  std_logic;
            --btns_4bits_tri_i : in  std_logic_vector(1 downto 0);
            sys_clk : in  std_logic
        );
    end component;

        -- Signals to connect to the UUT
    signal CE       : std_logic := '0'; -- CE is always 0 during transmission
    signal SPI_clock : std_logic := '0';
    signal MOSI     : std_logic := '0';
    signal sys_rst  : std_logic := '0';
    --signal btns_4bits_tri_i : std_logic_vector(1 downto 0) := "00";
    signal sys_clk : std_logic := '0';
    
    -- Clock period constant
    constant CLOCK_PERIOD : time := 20 ns; -- Adjust this value to set the SPI clock frequency
    constant CLOCK_PERIOD_SPI : time := 100 ns;

    signal c1         : std_logic_vector(7 downto 0) := "00000100";  -- binary of (900 & 63) = 4 = 00000100
    signal c2         : std_logic_vector(7 downto 0) := "01011100";  -- binary of (64 | ((900 >> 6) & 63)) = 68 = 01000100
    signal c3         : std_logic_vector(7 downto 0) := "10000000";  -- binary of (128 | ((900 >> 12) & 63)) = 129 = 10000001

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: fpgadbg_s3sb
        port map (
            CE        => CE,
            SPI_clock => SPI_clock,
            MOSI      => MOSI,
            sys_rst   => sys_rst,
            --btns_4bits_tri_i => btns_4bits_tri_i,
            sys_clk => sys_clk
        );

    -- Clock process for generating SPI clock
    clock_process : process
    begin
        while true loop
            SPI_clock <= '0';
            wait for CLOCK_PERIOD_SPI / 2;
            SPI_clock <= '1';
            wait for CLOCK_PERIOD_SPI / 2;
        end loop;
    end process clock_process;

    second_clock_process  : process
    begin
        while true loop
            sys_clk <= '0';
            wait for CLOCK_PERIOD / 2;
            sys_clk <= '1';
            wait for CLOCK_PERIOD / 2;
        end loop;
    end process second_clock_process ;


    -- Test process to send c1, c2, and c3 over MOSI
    stimulus_process: process
    begin
        -- Wait for a few clock cycles before starting the transmission
                -- Set sys_rst to 0 at the start
        sys_rst <= '0';
        wait for 5 * CLOCK_PERIOD;
        
        -- Set sys_rst to 1
        sys_rst <= '1';
        wait for 5 * CLOCK_PERIOD;
        
        -- Set btns_4bits_tri_i to 10
        --btns_4bits_tri_i <= "01";
        wait for 5 * CLOCK_PERIOD;
        
        -- Set btns_4bits_tri_i to 00
        --btns_4bits_tri_i <= "00";
        wait for 5 * CLOCK_PERIOD;
        
        CE<='0';
        -- Send c1 over MOSI
        for i in 7 downto 0 loop
            MOSI <= c1(i);
            wait for CLOCK_PERIOD_SPI;
        end loop;
        
        -- Send c2 over MOSI
        for i in 7 downto 0 loop
            MOSI <= c2(i);
            wait for CLOCK_PERIOD_SPI;
        end loop;
        
        -- Send c3 over MOSI
        for i in 7 downto 0 loop
            MOSI <= c3(i);
            wait for CLOCK_PERIOD_SPI;
        end loop;
        
        -- Wait for a few clock cycles and end simulation
        wait for 1000000 * CLOCK_PERIOD;
        
        -- End the simulation
        assert false report "Simulation ended" severity failure;
    end process stimulus_process;

end behavior;
