library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
library work;

-- Dual port memory for fpgadbg
-- VHDL description should allow automatic dual port RAM inference
-- This code is very common so probably you can consider it to be "public domain"

entity fpgadbg_mem is
  generic (
    width    : integer := 32;
    addrbits : integer := 10);
  port (
    clk1  : in  std_logic;
    addr1 : in  std_logic_vector((addrbits-1) downto 0);
    we1   : in  std_logic;
    din1  : in  std_logic_vector((width-1) downto 0);
    dout1 : out std_logic_vector((width-1) downto 0);
    clk2  : in  std_logic;
    addr2 : in  std_logic_vector((addrbits-1) downto 0);
    dout2 : out std_logic_vector((width-1) downto 0));
end fpgadbg_mem;

architecture syn of fpgadbg_mem is
  type   T_MEM is array (((2**addrbits)-1) downto 0) of std_logic_vector ((width-1) downto 0);
  signal mem : T_MEM;
begin
  process (clk1)
  begin
    if (clk1'event and clk1 = '1') then
      if (we1 = '1') then
        mem(conv_integer(addr1)) <= din1;
      end if;
      dout1 <= mem(conv_integer(addr1));
    end if;
  end process;

  process (clk2)
  begin
    if (clk2'event and clk2 = '1') then
      dout2 <= mem(conv_integer(addr2));
    end if;
  end process;
end syn;
