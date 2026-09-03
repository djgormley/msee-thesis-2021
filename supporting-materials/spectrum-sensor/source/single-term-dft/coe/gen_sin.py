################################################################################
# Author:          Anthony Stock, intern, NASA GRC-LCI
# Create date:     November 2020
# Title:           gen_sin.py
#
# Description:     Generates coefficients for 1/4 sine lookup table. Ouput in
#                  hex format to file "quarter_sine.coe". Values between
#                  0000 and 7FFF, inclusively, for 16-bit values. Note that
#                  RAM_width is one less than data width because sign bit is
#                  always zero for this LUT; storing these known values is
#                  wasteful. Sign bit is prepended in GenericMixer.vhd.
#
#                  Update Feb 2021: changed to generate 1/4 cos LUT
#                  
################################################################################

import numpy as np
#from matplotlib import pyplot as plt # In case you want to graph the coeffs.

N = 2**14      # number of coefficients
RAM_width = 15 # width of elements in sine lookup table.
               # normalizes output s.t. the max value has 0 in MSB and the rest 1's.

# generate sine wave, between 0 and pi/2 radians, scale to unity, then convert to hex
t = np.arange(N)*(np.pi/2)/(N)
cos = np.cos(t)

# dividing by 2**(RW-1) then multiplying again looks redundant but is necessary for scaling
cos = cos*(2**RAM_width-1)/(2**RAM_width)
cos = [hex(int(round(item*(2**RAM_width)))) for item in cos]

# remove "0x" from each hex number, prepend zeros if necessary so that all entries are the same number of chars
# (easier to handle here than in VHDL)
for i in range(len(cos)):
    cos[i] = cos[i][2:]
    lenDiff = int(np.ceil(RAM_width/4) - len(cos[i]))
    cos[i] = lenDiff*'0' + cos[i]

# write to file
with open('quarter_cos.coe', 'w') as lutFile:
    for i in range(len(cos)):
        lutFile.write(str(cos[i]) + "\n")


