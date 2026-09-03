#######################################################################
# Author:        Anthony A. Stock, intern, NASA GRC/LCI
# Creation date: 17 February 2021
# Module Name:   SingleTermSRE_in.py
# Description:   This script generates a QAM signal using the commpy
#                toolkit, writes it to a file for use in VHDL TB, and
#                models the SRE to provide a reference to compare the
#                VHDL TB results to.
#######################################################################

import numpy as np
from matplotlib import pyplot as plt
from commpy.modulation import QAMModem
from commpy.utilities import dec2bitarray, upsample
from commpy.filters import rrcosfilter
from commpy.sequences import pnsequence
from scipy.signal import welch

######### USER_DEFINED PARAMS #########
Fs = 100e6
ModulationOrder = 4 # doesn't seem to work with odd powers of 2.
SamplesPerSymbol = 4
NSymbols = int(2**16)

# filter parameters
Rolloff = 1.0
Span = 6
NTaps = SamplesPerSymbol * Span

# number of fraction bits in fixed-point format
fracBits = 15
#######################################


#
# Simulate Transmitter
#
# generate modem
Modulator = QAMModem(ModulationOrder)

# generate data
RandomInts = np.random.randint(0,ModulationOrder,NSymbols)
RandomBits = dec2bitarray(RandomInts,Modulator.num_bits_symbol)

# modulate data
RandomSymbols = Modulator.modulate(RandomBits)

# upsample
UpsampledSymbols = upsample(RandomSymbols, SamplesPerSymbol)

# generate pulse shape filter
Rs = Fs / SamplesPerSymbol
PsfIdxs = np.array(NTaps)
Psf = np.array(NTaps)
PsfIdxs, Psf = rrcosfilter(NTaps, Rolloff, 1/Rs, Fs)

# apply psf to modulated data and normalize to one
x = np.convolve(Psf, UpsampledSymbols)
x = x[ int(NTaps/2)-1  :  len(x)-int(NTaps/2) ]

x = x / max(abs(x))

'''
# constellation
plt.figure(1)
plt.scatter(x.real, x.imag)
plt.show()


# psd
f, X = welch(x,Fs)

plt.figure(2)
plt.semilogy(f/1e6,X)
plt.show()
'''


#
# Simulate ADC
#
# scale down to value that will become 2**(BIT_WIDTH-1)-1    (otherwise we'll end up with 2**(BW-1) as max. value)
# x = x*(2**fracBits-1)/(2**fracBits)

x_Real = np.round(x.real*(2**fracBits))
x_Imag = np.round(x.imag*(2**fracBits))

x_Fx_Real = [int(sample) for sample in x_Real]
x_Fx_Imag = [int(sample) for sample in x_Imag]


# write to files
with open("i_in.txt", 'w') as realFile:
    for i in range(len(x_Fx_Real)):

        realFile.write(str(x_Fx_Real[i]) + "\n")
with open("q_in.txt", 'w') as imagFile:
    for i in range(len(x_Fx_Imag)):
        imagFile.write(str(x_Fx_Imag[i]) + "\n")


#
# Python model of SRE - generates theoretical results.
#

# inst pwr
y = abs(x)**2
#y = y/2

# we can multiply by 2 because (1/sqrt(2))**2 = 1/2
y = y*2

# dft
# internal oscillator
osc_t = np.arange(len(y))
alpha = 0#Rs
osc   = np.exp(-1j*2*np.pi*alpha/Fs*osc_t)

# integrate
z_real = np.zeros(len(y)+1)
z_imag = np.zeros(len(y)+1)
for n in range(len(y)):
    prod = y[n]*osc[n]

    z_real[n+1] = z_real[n] + prod.real
    z_imag[n+1] = z_imag[n] + prod.imag

'''
plt.plot(z_real)
plt.show()
exit()
'''

# remove extraneous zero at beginning; scale by Nsamples
z_real = z_real[1:] / len(z_real)
z_imag = z_imag[1:] / len(z_imag)
z = z_real+1j*z_imag

# inst pwr
z_magsq = abs(z)**2
#z_magsq = z_magsq / 2

# shift left by 2 bits to undo div. by 4 (artifact of inst. power VHDL implementation)
#z_magsq = z_magsq * 4

# plot
plt.plot(z_magsq)
plt.title('SRE Model Results')
plt.xlabel('discrete time samples')
plt.ylabel('SRE magnitude squared')
plt.text(NSymbols*SamplesPerSymbol/8, max(z_magsq)*4/5, 'last val = ' + str(round(z_magsq[-1], 6)))
plt.show()

