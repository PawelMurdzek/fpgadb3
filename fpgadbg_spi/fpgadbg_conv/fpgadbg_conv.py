#!/usr/bin/python
# Copyright (C) 08.12.2024r. Pawel M. Murdzek (01158851@pw.edu.pl)
#
###############################################################################
# Title      : data converter
# Project    : fpgadbg3
###############################################################################
# File       : fpgadbg_conv.py
# Author     : Pawel A. Murdzek
# University : Warsaw University of Technology, ISE
# Created    : 2024-12-08
# Last update: 2025-01-08
# Standard   : Python 3.11
###############################################################################
# Description: The code below is a data converter. It will take 
# the input data and transform it to LXT file for GTKviewer accorodingly.
# This code has been written from scratch. Please consider this code to be PUBLIC DOMAIN
# No warranty of any kind!!!
###############################################################################
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
###############################################################################
#
import lxt
import math

class fpgadbg_conv:
    def __init__(self, assignments, nbits=16, timestep=100, timescale=-10, filename="out.lxt"):
        # Set some parameters
        self.nbits = nbits
        self.timestep = timestep
        self.filename = filename
        # Open the output file and setup the timing parameters
        self.fout = lxt.lt_init(filename)
        lxt.lt_set_timescale(self.fout, timescale)
        # Setup the conversion table
        conv_table = []
        # Flatten the array of tuples into a list and filter only integers
        combined_assigments = [num for tup in assignments for num in tup if isinstance(num, int)]
        self.total_lenght_of_declared_signals = 1 + max(combined_assigments) - min(combined_assigments)
        self.number_of_declared_signals = len(assignments)
        for sigdef in assignments:
            if len(sigdef) != 3 and len(sigdef) != 5:
                raise ValueError("Wrong length of signal assignment definition")
            msb = sigdef[0]
            lsb = sigdef[1]
            name = sigdef[2]
            if len(sigdef) == 5:
                omsb = sigdef[3]
                olsb = sigdef[4]
            else:
                olsb = 0
                omsb = msb - lsb
            # Create the signal definition in the LXT file
            s = lxt.lt_symbol_add(self.fout, name, 0, omsb, olsb, lxt.LT_SYM_F_BITS)
            # Add the description to our internal conversion table
            conv_table.append((msb, lsb, s, name))
        # Convert the conversion table from list into tuple (to optimize accesses)
        self.conv_table = tuple(conv_table)
    def split_and_reverse_fixed(self, input_string):
    # Split the input into 8-character chunks
        chunks = [input_string[i:i+8] for i in range(0, len(input_string), 8)]
        
        # Reverse the order of the chunks
        reversed_chunks = ''.join(chunks[::-1])
        
        # Regroup the reversed string into 8-character blocks
        grouped_result = [reversed_chunks[i:i+8] for i in range(0, len(reversed_chunks), 8)]
        
        # Join the grouped chunks into the final result
        result = ''.join(grouped_result)
        
        return result
    
    def convert_data(self, bit_string, start_index):
    # Extract the slice of bit string corresponding to the sample

        #sample_bits = bit_string[start_index:start_index + self.nbits]
        sample_bits = bit_string[start_index:start_index + self.words_per_sample * self.nbits]
        
        #sometimes the number of bytes at the end is not equal to words_per_sample * data_width and the gtkwave gets obstructed   
        if(len(sample_bits)<self.data_width):
            return
        
        bits_joined = ''.join(sample_bits)
        slice_bits = self.split_and_reverse_fixed(bits_joined)[-self.data_width:]
        
        for j in range(len(self.conv_table)):
            ct = self.conv_table[j]
            #Ordering the samples based on assignement
            lxt.lt_emit_value_bit_string(self.fout, ct[2], 0, slice_bits[self.data_width-1-ct[0]:self.data_width-1-ct[1]])
        
        lxt.lt_set_time(self.fout, self.t)

    def conv(self, bit_string):
    # Constant length of the data word
        word_len = self.nbits

        # Extract log2samples (first 8 bits) and convert to integer
        log2samples = int(bit_string[0:8], 2)

        log2samples = int(bit_string[4:8], 2)
        if(str(bit_string[0:3]) == "100"):
            filled = 1
        else:
            filled = 0
        num_of_samples = 1 << log2samples
        
        # Extract data_width (next 8 bits) and convert to integer
        self.data_width = int(bit_string[8:16], 2)
        if(self.number_of_declared_signals != int(bit_string[16:24], 2)):
            raise ValueError(f"Mismatch between data_width read by SPI and declaration. Check signal declaration in main_fpgadbg_SPI.py and your VHDL implementation")
        # Calculate the number of data words per sample
        self.words_per_sample = (self.data_width + word_len - 1) // word_len
        # Extract trigger and stop positions based on data_width
        
        
        
        if(self.data_width != self.total_lenght_of_declared_signals):
            raise ValueError(f"Mismatch between number_of_signals read by SPI and declaration. Check signal declaration in main_fpgadbg_SPI.py and your VHDL implementation")
        
        if word_len >= 16:
            trig_pos = int(bit_string[24:40], 2)
            stop_pos = int(bit_string[40:56], 2)
            first_data = 48  # Start index of actual data in the bit string
        else:
            trig_pos = int(bit_string[24:32], 2) + 256 * int(bit_string[32:40], 2)
            stop_pos = int(bit_string[40:48], 2) + 256 * int(bit_string[48:56], 2)
            first_data = 48

        # Set the initial time to zero
        self.t = 0
        lxt.lt_set_time(self.fout, self.t)

        # Determine past_pos (start of valid data if buffer was filled)
        n_exact = (stop_pos - 8) / 40
    
        # Round n to the nearest upper integer
        n_rounded = math.ceil(n_exact)
        
        past_pos = 8 + 40 * n_rounded 
        
        #process data:

        # Always process data from first_data to past_pos
        for i in range(first_data, past_pos, self.words_per_sample * word_len):
            self.t += self.timestep
            self.convert_data(bit_string, i)
        
        # If the buffer was filled, start from past_pos to after_last_data
        after_last_data = len(bit_string)
        if filled:
            for i in range(past_pos, after_last_data, self.words_per_sample * word_len):
                self.t += self.timestep
                self.convert_data(bit_string, i)

        # Finally, close the file
        lxt.lt_close(self.fout)

