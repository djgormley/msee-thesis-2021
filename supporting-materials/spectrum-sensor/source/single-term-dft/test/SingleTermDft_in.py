###### HEADER #######

import numpy as np
from matplotlib import pyplot as plt

######
fracBits = 31
bitWidth = 32
Nsamples = 2**12
Fs       = 100e6  # sample rate
fc       = 50e3   # input signal tone
alpha    = 50e3   # osc tone
######

pi    = np.pi
tau   = 0         # phase shift for x[n]
theta = 0         # phase shift for oscillator

# generate input signal x[n] and scale to unity
x_t = np.arange(Nsamples)
x = np.exp( 1j * 2 * pi * fc / Fs * x_t) * np.exp(-1j * tau)
x = x*(2**fracBits-1)/(2**fracBits)
#x = x/max(abs(x))

# internal oscillator
osc_t = np.arange(Nsamples)
osc = np.exp(-1j*2*pi*alpha/Fs*osc_t) * np.exp(-1j*theta)

# integrate
z_real = np.zeros(Nsamples+1)
z_imag = np.zeros(Nsamples+1)
for n in range(Nsamples):
    prod = x[n]*osc[n]
    z_real[n+1] = z_real[n] + prod.real
    z_imag[n+1] = z_imag[n] + prod.imag

# remove extraneous zero at beginning
z_real = z_real[1:]
z_imag = z_imag[1:]

# scale by Nsamples
z_real = z_real / Nsamples
z_imag = z_imag / Nsamples

plt.plot(x_t/Fs*1000, z_real, label="real="+str(round(max(abs(z_real)), 3)))
plt.plot(x_t/Fs*1000, z_imag, label="imag="+str(round(max(abs(z_imag)), 3)))
plt.xlabel('time (ms)')
plt.ylabel('rolling sum of fourier coefficient')
plt.legend()
plt.show()

# multiply by number of fractional bits for fx-pt notation
xFxReal = np.round(x.real*(2**fracBits))
xFxImag = np.round(x.imag*(2**fracBits))

# convert from float to int
xFxReal = [int(sample) for sample in xFxReal]
xFxImag = [int(sample) for sample in xFxImag]

# write to files
with open("i_in.txt", 'w') as realFile:
    for i in range(len(xFxReal)):
        realFile.write(str(xFxReal[i]) + "\n")

with open("q_in.txt", 'w') as imagFile:
    for i in range(len(xFxImag)):
        imagFile.write(str(xFxImag[i]) + "\n")
