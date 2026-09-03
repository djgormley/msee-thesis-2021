#######################################################################
# Author: Anthony Stock, intern, NASA GRC/LCI
# Creation date: 9 November 2020
# Module Name: ReadMixerOut.py
# Description: This program reads the output of the Generic Mixer
#              testbench, found in i_out_pos.txt, q_out_pos.txt,
#              i_out_neg.txt, and q_out_neg.txt The output is plotted
#              in the frequency domain.
#######################################################################

import numpy as np
from scipy.signal import welch, get_window
import matplotlib.pyplot as plt

####################### USER-DEFINED PARAMETERS #######################
Fs = 100e6       # clock rate
fracBits = 31    # fraction bits in fixed-point output
N = 2**16        # number of samples
#######################################################################

i = np.array(0)
q = np.array(0)

# open output files from TB and read contents
with open('i_out_pos.txt') as f:
    ipos = [int(line.rstrip())/(2**fracBits) for line in f]
    
with open('q_out_pos.txt') as f:
    qpos = [int(line.rstrip())/(2**fracBits) for line in f]
    
with open('i_out_neg.txt') as f:
    ineg = [int(line.rstrip())/(2**fracBits) for line in f]
    
with open('q_out_neg.txt') as f:
    qneg = [int(line.rstrip())/(2**fracBits) for line in f]

# create complex signal out from I/Q components and find frequency spectrum via welch()
y_pos = [ipos[n] + 1j*qpos[n] for n in range(len(ipos))]
f_pos, Pyy_pos = welch(y_pos, window=get_window('hann', N, fftbins=True), nperseg=N,
               noverlap=N/2, nfft=N, fs=Fs, return_onesided=False, scaling='spectrum')

# create complex signal out from I/Q components and find frequency spectrum via welch()
y_neg = [ineg[n] + 1j*qneg[n] for n in range(len(ineg))]
f_neg, Pyy_neg = welch(y_neg, window=get_window('hann', N, fftbins=True), nperseg=N,
               noverlap=N/2, nfft=N, fs=Fs, return_onesided=False, scaling='spectrum')

# plot results
plt.figure(1)
plt.plot(f_pos/1e6, Pyy_pos, label="positive FCW")
plt.plot(f_neg/1e6, Pyy_neg, label="negative FCW")
plt.xlabel("MHz")
plt.ylabel("Amplitude")
plt.title("Heterodyne Mixer Output (Frequency Domain)")
plt.legend()
plt.show()
