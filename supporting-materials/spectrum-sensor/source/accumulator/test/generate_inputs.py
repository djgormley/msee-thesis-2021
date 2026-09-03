# Anthony Stock (GRC-LCI/NIP)

import numpy as np
import matplotlib.pyplot as plt

# parameters
Nsamples      = 2**8
Fs            = 100e6
Fc            = 5e6

# input signal
t = np.arange(Nsamples)/Fs
x = np.exp(1j*2*np.pi*Fc*t)


Sum = np.zeros(1)

for i in range(Nsamples):
    Sum = np.append(Sum, Sum[-1] + x[i])

Sum = np.delete(Sum, 0)

plt.plot(t*1e6, x.real)
plt.plot(t*1e6, Sum.real)
plt.xlabel('us')
plt.show()
