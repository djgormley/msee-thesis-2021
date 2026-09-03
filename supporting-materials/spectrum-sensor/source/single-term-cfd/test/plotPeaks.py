import matplotlib.pyplot as plt
import numpy as np

f = open("peak.txt","r")
peaks = f.read()
peaks = peaks[:-1]
peaks = peaks.split('\n')

peaks = np.int64(peaks)

plt.plot(np.arange(100), peaks)
plt.show()
