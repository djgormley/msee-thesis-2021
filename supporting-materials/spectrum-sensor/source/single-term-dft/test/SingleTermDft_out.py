from matplotlib import pyplot as plt
import numpy as np

fracBits = 31
Fs = 100e6

iOut = open("i_out.txt").read().splitlines()
qOut = open("q_out.txt").read().splitlines()

i = np.array([int(num) / 2**fracBits for num in iOut])
q = np.array([int(num) / 2**fracBits for num in qOut])

t = np.arange(len(i)) / Fs
Y = i + 1j*q


plt.figure(1)
plt.plot(t, i)
plt.plot(t, q)

plt.figure(2)
plt.plot(t, abs(Y)**2)

plt.show()
