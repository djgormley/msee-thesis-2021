#######################################################################
# Author:        Anthony A. Stock, intern, NASA GRC/LCI
# Creation date: 20 October 2020
# Module Name:   fir_out.py
# Description:   This script graphs the results of the ComplexFir
#######################################################################

import numpy as np
import matplotlib.pyplot as plt

Fs          = 100e6 # clock rate
sampleFrac  = 31    # number of fraction bits in output

# read files produced by testbench
yi = open("i_out.txt").read().splitlines()
yq = open("q_out.txt").read().splitlines()

# scale down fixed-point numbers
yi = [int(num) / 2**sampleFrac for num in yi]
yq = [int(num) / 2**sampleFrac for num in yq]

# time axis
t = np.arange(len(yi)) / Fs

# plot filtered signal
plt.plot(t*1e6, yi, 'b-', label='real')
plt.plot(t*1e6, yq, 'r-', label='imaginary')
plt.ylim([0, 1])
plt.xlabel('time (us)')
plt.ylabel('magnitude')
plt.title('I and Q Components of Filtered Signal')
plt.legend()
plt.show()
