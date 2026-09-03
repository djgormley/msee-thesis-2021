#######################################################################
# Author:        Anthony A. Stock, intern, NASA GRC/LCI
# Creation date: 15 October 2020
# Module Name:   fir_in.py
# Description:   This script generates a file that contains a sequence
#                of test inputs for the ComplexFir or GenericFir
#                modules. The filtered and unfiltered signals are
#                plotted, along with the frequency response of the
#                filter with the given taps.
#######################################################################

import math
import numpy as np
from scipy.signal import lfilter, unit_impulse, firwin, kaiserord, freqz
import matplotlib.pyplot as plt

####################### USER-DEFINED PARAMETERS #######################
Nsamples   = 2**7   # number of input samples to generate
Ntaps      = 17     # number of taps
sampleFrac = 31     # number of fraction bits in fixed-point samples
coeffFrac  = 31     # number of fraction bits in fixed-point coefficients
Fs         = 100e6  # clock rate (Hz)
Fcutoff    = 5e6    # cutoff frequency for filter (Hz)
Fn         = Fs/2   # Nyquist frequency

# generate function to be put through filter. Several examples provided.
#x = np.sin(t*Fs/4)
x = unit_impulse(Nsamples, 'mid')
#x = np.ones(Nsamples) * -1
#x = np.ones(Nsamples)

#######################################################################

# time axis
t = np.arange(Nsamples) / Fs

# scale x to unity
x = ((2**sampleFrac - 1)/(2**sampleFrac))*x

# set up filter parameters
taps = firwin(Ntaps, Fcutoff*2/Fs)

# filter signal
y = lfilter(taps, 1.0, x)

# plot filtered and original signals
plt.figure(1)
plt.plot(t*1e6, y, 'b-', label='filtered signal y(t)')
plt.plot(t*1e6, x, 'r-', label='unfiltered signal x(t)')
plt.xlabel('time (us)')
plt.ylabel('magnitude')
plt.title('Unfiltered Signal and Theoretical Filtered Signal')
plt.legend()

# plot frequency response of filter
plt.figure(2)
w, h = freqz(taps, worN=8000)
plt.plot(w/np.pi*Fn, np.absolute(h))
plt.title('Frequency Response of Software Filter')
plt.xlabel('frequency (Hz)')
plt.ylabel('magnitude')
plt.show()

# multiply by 2^(fraction bits) for signed fixed-point format
taps = [int(round(tap*2**coeffFrac)) for tap in taps]
x = [int(round(sample*2**sampleFrac)) for sample in x]

# write taps and inputs to file. For testing purposes i_in and q_in are the same.
with open('h_in.txt', 'w') as tapFile:
    for i in range(len(taps)):
        tapFile.write(str(taps[i]) + "\n")

with open('i_in.txt', 'w') as inputFile:
    for i in range(len(x)):
        inputFile.write(str(x[i]) + "\n")

with open('q_in.txt', 'w') as inputFile:
    for i in range(len(x)):
        inputFile.write(str(x[i]) + "\n")
