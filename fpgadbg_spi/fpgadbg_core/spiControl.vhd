-------------------------------------------------------------------------------
-- Title      : spiControl - low level SPI interface
-- Project    : fpgadbg3
-------------------------------------------------------------------------------
-- File       : spiControl.vhd
-- Author     : Pawel A. Murdzek
-- University : Warsaw University of Technology, ISE
-- Created    : 2023-12-31
-- Last update: 2024-12-19
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: The code below is a very simple implementation of the SPI 
-- interface on low level. The SPI has been written specifically to work 
-- with the fpgadbg core therefore it does not use buffering. 
-- This code has been written from scratch, however it was
-- inspired by many different existing SPI implementations.
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

entity spiControl is
    Port(   clock                        : in std_logic; --On-board ZYBO clock (125MHz)
            reset                        : in std_logic;
            data_in                      : in std_logic;   --read line
            done_config                  : in std_logic; --Signal indicates data has been sent over SPI interface
			byte_out                     : out std_logic_vector(7 downto 0); -- configuration bytes
			CE                           : in std_logic;
			SPI_clock                    : in std_logic;
			ready_to_receive             : in std_logic;
			config_bytes_received        : out std_logic;
			ready_to_send_to_master      : in std_logic;
			
			data_MISO                    : in std_logic_vector(7 downto 0);
			bit_MISO                     : out std_logic;
			done_send                    : out std_logic;
			data_send_finished           : in std_logic;
			finished_data_transfer       : in std_logic;
			start_MISO_transfer          : in std_logic;
			clock_sampled_out            : out std_logic;
			--dbg                          : out std_logic_vector(10 downto 0);
			enable_read_spi              : out std_logic
        );
end spiControl;

architecture Behavioral of spiControl is

	component sampler is
		Port(   clock                    : in std_logic; --On-board ZYBO clock (125MHz)
				reset                    : in std_logic;
				sampling_enable          : in std_logic; 
				samples_in               : in std_logic;   --read line
				samples_out              : out std_logic --return sampled
				);
	end component;

type states is (IDLE,
                SENDING_TO_CONFIG,
                WAITING_FOR_READY,
                DONE_CONFIGURING,
				WAIT_FOR_FPGADBG,
				LOAD_DATA_TO_SEND,
				SEND_TO_MASTER,
				DONE
                );
				
signal rcv_cntr : integer := 0;
signal current_state : states := IDLE;
signal shift_reg : std_logic_vector(7 downto 0) := (others => '0');
signal rx_reg : std_logic_vector(23 downto 0) := (others => '0');
signal spi_data_tmp : std_logic;
signal data_count : std_logic_vector(3 downto 0) := (others => '0');
signal conf_ctrl: integer := 3;

----samplers
signal data_sampled: std_logic;
signal clock_sampled: std_logic;
signal data_sampler_enable: std_logic := '0';
signal clock_sampler_enable: std_logic := '0';
----

begin
    
    sampler_mosi: sampler
	port map (
		clock                  => clock,
		reset                  => reset,
		sampling_enable        => data_sampler_enable,
		samples_in             => data_in,
		samples_out            => data_sampled
		);
		
	sampler_clock: sampler
	port map (
		clock                  => clock,
		reset                  => reset,
		sampling_enable        =>  clock_sampler_enable,
		samples_in             => SPI_clock,
		samples_out            => clock_sampled
		);

	--asynchronous proces of turning on samplers
	ENABLE_SAMPLING_PROCESS: process (CE)
	begin
		if (CE = '0') then
			clock_sampler_enable <= '1';
			data_sampler_enable <= '1';
		else
			clock_sampler_enable <= '0';
			data_sampler_enable <= '0';
		end if;
	end process;
	
    --
	RECEIVE_STATE_MACHINE : process (clock_sampled,reset, CE)
	begin
        clock_sampled_out<=clock_sampled;
        if(reset = '0') then
                data_count <= (others => '0');
                current_state <= IDLE;
				conf_ctrl <= 3;
				config_bytes_received <= '0';
				rcv_cntr <= 0;
				rx_reg<= (others => '0');
				enable_read_spi <='0';
        else
            if (CE = '0') then 
                if(falling_edge(clock_sampled)) then
                    case(current_state) is
                    
                        when IDLE =>
                            if(ready_to_receive = '1') then
                                
                                if (rcv_cntr /= 24) then
                                    rx_reg(23-rcv_cntr) <= data_sampled;
                                    rcv_cntr <= rcv_cntr + 1;
                                else
                                    current_state <= SENDING_TO_CONFIG;
                                end if;
                            end if;
                            
                        when SENDING_TO_CONFIG =>                           
                            --byte_out <= rx_reg(conf_ctrl*8-1 downto (conf_ctrl-1)*8);
									 case conf_ctrl is
										 when 1 =>
											  byte_out <= rx_reg(7 downto 0);
										 when 2 =>
											  byte_out <= rx_reg(15 downto 8);
										 when 3 =>
											  byte_out <= rx_reg(23 downto 16);
										 when others =>
											  byte_out <= (others => '0');  -- Default value
									 end case;

                            config_bytes_received <= '1';
                            conf_ctrl <= conf_ctrl - 1;
                            if (conf_ctrl /= 1) then
                                current_state <= WAITING_FOR_READY;
                            else
                                current_state <= DONE_CONFIGURING;
                            end if;
                            
                        when WAITING_FOR_READY =>
                            if(ready_to_receive = '1') then
                                current_state <= SENDING_TO_CONFIG;
                            else
                                current_state <= WAITING_FOR_READY;
                            end if;
                            
                        when DONE_CONFIGURING =>
                            conf_ctrl <= 3;
                            config_bytes_received <= '0';
                            if (done_config = '1') then
                                current_state <= WAIT_FOR_FPGADBG;
                            end if;
                        
                        when WAIT_FOR_FPGADBG =>
                            if(ready_to_send_to_master = '1') then
                                done_send <='1';
                                current_state <= LOAD_DATA_TO_SEND;
                            end if;
                            
                        when LOAD_DATA_TO_SEND =>
                            if(finished_data_transfer = '1') then
                                current_state <= DONE;
                            else
                                done_send <='0';
                                if(start_MISO_transfer = '1') then
                                    if(ready_to_receive = '1') then
                                        shift_reg <= data_MISO;
                                        data_count <= (others => '0');
                                        current_state <= SEND_TO_MASTER;
                                    end if;
                                end if;
                            end if;     
                                                   
                        when SEND_TO_MASTER =>
                            if(finished_data_transfer = '1') then
                                current_state <= DONE;
                            else
                                enable_read_spi <='1';
                                spi_data_tmp <= shift_reg(7);
                                bit_MISO <= spi_data_tmp;
                                shift_reg <= shift_reg(6 downto 0) & '0';
                                if(data_count /= 8) then --one clock tick delay between bit_MISO and spi_data_tmp
                                    data_count <= data_count + 1;
                                else
                                    enable_read_spi <='0';
                                    current_state <= LOAD_DATA_TO_SEND;
                                    done_send <= '1';
                                end if;
                            end if;
                            
                        when DONE =>
                            enable_read_spi <='0';    
                                                                        
                        when others =>
                            current_state <= IDLE;
                            
                    end case;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
