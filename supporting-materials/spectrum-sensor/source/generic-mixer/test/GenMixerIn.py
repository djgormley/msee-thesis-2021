#######################################################################
# Author: Anthony Stock, intern, NASA GRC/LCI
# Creation date: 9 November 2020
# Module Name: GenMixerIn.py
# Description: This program generates test vectors for the Generic-
#              Mixer module, into seperate files for I/Q componenets.
#######################################################################

import numpy as np
from scipy.signal import freqz, welch, get_window
import matplotlib.pyplot as plt

##################### USER-DEFINED PARAMETERS #########################
fracBits = 15 # fraction bits in fixed-point samples
fc = 1e6      # carrier tone
Fs = 1e6      # sample rate
N  = 2**16    # number of samples in signal x
fosc = 2e6    # local oscillator frequency in mixer
#######################################################################

# x[n]
xn = np.arange(N)/Fs
x = np.exp(1j*2*np.pi*fc*xn)
#x = np.ones(N) # for testing (this should cause overflow)

# normalize to max value, e.g. 7FFFFFFF
x = x*(2**fracBits-1)/(2**fracBits)

# theoretical output of mixer, after being multiplied by local oscillator
lon = np.arange(N)/Fs
lo_pos = np.exp(1j*2*np.pi*fosc*lon)
lo_neg = np.exp(1j*2*np.pi*-fosc*lon)
# scale to unity
lo_pos = lo_pos*(2**fracBits-1)/(2**fracBits)
lo_neg = lo_neg*(2**fracBits-1)/(2**fracBits)
# mixing
y_pos = x*lo_pos
y_neg = x*lo_neg

# scale by 2**(fractional bits) for fixed point notation
xfx = np.round(x*(2**fracBits))
xReal = [int(sample) for sample in xfx.real]
xImag = [int(sample) for sample in xfx.imag]

# write out to files
with open('i_in.txt', 'w') as realFile:
    for i in range(len(x)):
        realFile.write(str(xReal[i]) + "\n")

with open('q_in.txt', 'w') as imagFile:
    for i in range(len(x)):
        imagFile.write(str(xImag[i]) + "\n")


# plot unmixed and mixed signals (ideal output)
fx, Pxx = welch(x, nperseg=N, fs=Fs, return_onesided=False, scaling='spectrum')
fy_pos, Pyy_pos = welch(y_pos, nperseg=N, fs=Fs, return_onesided=False, scaling='spectrum')
fy_neg, Pyy_neg = welch(y_neg, nperseg=N, fs=Fs, return_onesided=False, scaling='spectrum')

plt.xlim(-2*abs(fosc+fc)/(1e6), 2*abs(fosc+fc)/(1e6))
plt.plot(fx/1e6, Pxx, label="Pxx")
plt.plot(fy_pos/1e6, Pyy_pos, label="Pyy (positive heterodyne)")
plt.plot(fy_neg/1e6, Pyy_neg, label="Pyy (negative heterodyne)")
plt.title('Unmixed and Ideal Mixed Signals')
plt.xlabel("MHz")
plt.ylabel("Pyy")
plt.legend()
plt.show()
