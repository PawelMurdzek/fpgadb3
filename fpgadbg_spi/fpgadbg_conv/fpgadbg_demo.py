#!/usr/bin/python
# Copyright (C) 10.07.2006 Wojciech M. Zabolotny (wzab@ise.pw.edu.pl)
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

import fpgadbg_conv
import os
file=open("dbg.out","r")
data=[]
# Read the data from the file. In normal environment
# the data should be read e.g via VME interface
while True:
    line=file.readline()
    if line=="":
        break
    val=int(line)
    data.append(val)
# Create the signal assignments description
# (must match your VHDL code!)
assgn=((20,11,"counter_nb"),
       (10,10,"Clk"),
       (9,0,"lsr"))
# Create the data converter, and create the LXT file
cnv=fpgadbg_conv.fpgadbg_conv(assgn,16,125,-10,"test.lxt")
cnv.conv(data)
# Display the waveforms if gtkwave is available
os.system("gtkwave test.lxt test.sav")
