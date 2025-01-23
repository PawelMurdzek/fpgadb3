#!/usr/bin/python
# Copyright (C) 08.12.2024r. Pawel M. Murdzek (01158851@pw.edu.pl)
#
###############################################################################
# Title      : main fife for fpgadbg SPI converter 
# Project    : fpgadbg3
###############################################################################
# File       : main_fpgadbg_SPI.py
# Author     : Pawel A. Murdzek
# University : Warsaw University of Technology, ISE
# Created    : 2024-12-08
# Last update: 2025-01-08
# Standard   : Python 3.11
###############################################################################
# Description: The code below is a main file for fpgadbg converter. 
# It reads data, prepares it for conversion, ooed it to converter itself 
# and then displays it in GTKviewer.
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

import os
import spidev
import sys
import time
import fpgadbg_conv
from gpiozero import Button, LED

# Write data to SPI
def write_spi(data):
    integers = [int(h, 16) for h in data]
    for value in integers: 
        spi.xfer2([value])

# Read data from SPI
def read_spi(num_bytes):
    return spi.readbytes(num_bytes)

def cut_zeros(lst):
    for i, num in enumerate(lst):
        if num != 0:
            return lst[i:]
    return []  # Return an empty list if all elements are zero.

def convert_to_hex(int_list):
    return [hex(num) for num in int_list]

def convert_to_bytes(int_list):
    return bytes(int_list)

def hex_to_binary(hex_list):
    binary_string = ''.join(bin(int(hex_value, 16))[2:].zfill(8) for hex_value in hex_list)
    trimmed_binary_string = binary_string.lstrip('0')
    return trimmed_binary_string

def remove_9th_and_10th_from_binary(binary_string):
    result = []
    for i in range(0, len(binary_string), 10):
        block = binary_string[i:i+10]
        if len(block) == 10:  # Only process full blocks
            result.append(block[:8])  # Keep only the first 8 characters
        else:
            result.append(block)  # Append the remaining characters as is
    return ''.join(result)

def binary_to_hex_tuple(binary_string):
    hex_values = []
    for i in range(0, len(binary_string), 8):
        byte = binary_string[i:i+8]
        if len(byte) == 8:  # Ensure it's a full byte
            hex_values.append(hex(int(byte, 2)))
    return tuple(hex_values)

def filter_received_data(data):
    
    #cut first zeros, empty data before the actual SPI data
    data_filtered = cut_zeros(data)
    
    #convert from integer tuple to binary string
    hex_data = convert_to_hex(data_filtered)
    binary_string = hex_to_binary(hex_data)
    
    #by nature of my SPI control, two extra bits of data is being sent every 8 bits, so you have to cut those two bits
    modified_binary_string = remove_9th_and_10th_from_binary(binary_string)
    
    return modified_binary_string

#In case you need outside reset for FPGA, I prepared the signal on GPIO3 of RaspberryPI
rst = LED(3)
print("Reset the Spartan 3 Starter Board, then press enter")
rst.off()

tmp=sys.stdin.readline()
rst.on()

spi = spidev.SpiDev()
spi.open(0, 0)  # Open bus 0, chip select 0

spi.mode = 0b00  # Set SPI mode (0 to 3)
spi.max_speed_hz = 5400000#25000  # Set SPI speed
#spi.max_speed_hz:
#PYNQ-Z2 = 10000000
#tang20k-nano = 5400000

# Initialize the conversion
posttrig=900
c1=hex(posttrig & 63)
c2=hex(64 | ((posttrig >> 6) & 63))
c3=hex(128 | ((posttrig >> 12) & 63))
#print ("Press the button2 to start the timer")
write_spi([c1,c2,c3])

# Now receive the data

#Initialize struct
data = []

#Wait for the signal that the data is being send out
recording_signal = Button(4)
print("waiting for signal to start recording")

recording_signal.wait_for_press()
print("started receiving data")

#Record all data
while(recording_signal.is_pressed):
    data=data + read_spi(1024) #The number of bytes you want to read
print("received data:")
print(data)

print("data after filtering")

signal_filtered = filter_received_data(data)
print(signal_filtered)
# Convert character data into integers

assign=((32,21,"frqdiv2"),
       (20,0,"frqdiv"))
       
# Create the data converter, and create the LXT file
cnv=fpgadbg_conv.fpgadbg_conv(assign,8,125,-10,"test.lxt")
cnv.conv(signal_filtered)
# Display the waveforms if gtkwave is available
os.system("gtkwave test.lxt test.sav")
