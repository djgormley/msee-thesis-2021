#######################################################################
# Author:        Anthony A. Stock, NASA GRC/LCI [SIP]
# Creation date: 02 August 2021
# Module Name:   GenerateIQ.py
# Description:   --
#######################################################################

import numpy as np

from matplotlib        import pyplot as plt
from commpy.channels   import awgn
from commpy.filters    import rrcosfilter
from commpy.modulation import QAMModem
from commpy.utilities  import dec2bitarray
from scipy.signal      import welch, upfirdn
from scipy.fftpack     import fft, fftshift

###### GLOBAL CONSTANTS##############################################
Fs         = 12.50e6
fracBits   = 15
Span       = 11
NIQSamples = 2**16
#####################################################################
def main():

    #
    # Simulate Transmitters
    #

    NWaveforms = 1;

    # Waveform Index ##            0       1
    Rs              = np.array([3.125,  0.2])*1e6
    fc              = np.array([-3.125,  0.2])*1e6
    Rolloff         = np.array([0.35, 0.35])
    EbN0            = np.array([14.0, 14.0]) # dB
    ModulationOrder = np.array([4,       4])

    BitsPerSym = np.log2(max(ModulationOrder))
    NMessages  = int(NIQSamples*BitsPerSym)

    # create a buffer of maximum possible size
    x = np.zeros(NMessages)
    for i in range(NWaveforms):
        wf              = transmitter(ModulationOrder[i], Rs[i], fc[i], Rolloff[i], NMessages)
        ch              = channel(wf, ModulationOrder[i], Rs[i], EbN0[i]);
        x               = x[:NIQSamples] + ch[:NIQSamples];

    #
    # Simulate ADC
    #

    # simulates agc
    x = x/max(abs(x))
    print("|agc|:",max(x*np.conj(x)))

    # visualize received signal
    '''
    f, Pxx = welch(x,Fs,return_onesided=False,noverlap=len(x)/4, nperseg=len(x)/2, nfft=len(x)/2, scaling='spectrum')
    plt.semilogy(f/1e6, Pxx*1e6)
    plt.xlabel("f (MHz)")
    plt.ylabel("Pxx(f)")
    plt.title('M-QAM-SRRC')
    plt.show()
    '''

    # simulate quantization by using fixed-point
    x_Fx_Real = np.round(x.real*(2**fracBits)).astype(int)
    x_Fx_Imag = np.round(x.imag*(2**fracBits)).astype(int)

    # simulate sampling by
    # writing IQ samples to file
    with open("i_in_py.txt", 'w') as realFile:
        for i in range(len(x_Fx_Real)):
            realFile.write(str(x_Fx_Real[i]) + "\n")

    with open("q_in_py.txt", 'w') as imagFile:
        for i in range(len(x_Fx_Imag)):
            imagFile.write(str(x_Fx_Imag[i]) + "\n")

    print(max(abs(x_Fx_Real)))
    print(max(abs(x_Fx_Imag)))

#########################################################################
def transmitter(ModulationOrder, Rs, fc, Rolloff, NMessages):
    # generate modem
    Modulator = QAMModem(ModulationOrder)

    # generate messages
    RandomInts = np.random.randint(0,ModulationOrder,NMessages)
    '''
    plt.plot(np.arange(0,10),RandomInts[0:10])
    plt.show()
    '''

    # convert messages to bits
    RandomBits = dec2bitarray(RandomInts,Modulator.num_bits_symbol)
    '''
    plt.plot(np.arange(0,10),RandomBits[0:10])
    plt.show()
    '''

    # differential encode
    '''
    Mod = 2
    EncodedBits = np.zeros(len(RandomBits),dtype=np.int8)
    for i in range(len(RandomBits)):
        if i == 0:
            EncodedBits[i] = 0
        else:
            EncodedBits[i] = np.int8((RandomBits[i-1]+EncodedBits[i-1])%Mod)

    plt.plot(EncodedBits[0:10])
    plt.show()
    '''

    # convert bits to symbols
    #RandomSymbols = Modulator.modulate(EncodedBits)
    RandomSymbols = Modulator.modulate(RandomBits)
    RandomSymbols = RandomSymbols/max(abs(RandomSymbols))
    print("|RandomSymbols|:",max(abs(RandomSymbols*np.conj(RandomSymbols))))
    '''
    plt.plot(np.arange(0,10),RandomSymbols.real[0:10],RandomSymbols.imag[0:10])
    plt.show()
    '''

    # generate pulse shape filter
    SamplesPerSymbol = Fs/Rs
    NTapsRrc         = Span*SamplesPerSymbol + 1
    Psf_idxs, Psf    = rrc(int(NTapsRrc), Rolloff, 1/Rs, Fs)
    Psf              = Psf+0j
    Psf              = Psf/max(abs(Psf))
    print("|Psf|:",max(abs(Psf*np.conj(Psf))))
    '''
    plt.plot(Psf_idxs, Psf.real)
    plt.show()
    '''

    # resample & pulse shape symbols to create baseband signal
    # output length = (Fs/Rs)*(Nmessages+Span)
    rat = SamplesPerSymbol.as_integer_ratio()
    Up  = upfirdn(Psf, RandomSymbols, rat[0], rat[1])
    Up  = Up/max(abs(Up))
    print("|Up|:",max(abs(Up*np.conj(Up))))
    '''
    plt.plot(np.arange(0,100),Up.real[0:100],Up.imag[0:100])
    plt.show()
    '''

    # upconvert from baseband to passband
    # fc -> positive: rhs of spectrum, negative: lhs of spectrum
    LocalOsc = np.exp(1j*2*np.pi*fc/Fs * np.arange(len(Up)))
    LocalOsc = LocalOsc/max(abs(LocalOsc))
    print("|osc|:",max(abs(LocalOsc*np.conj(LocalOsc))))
    '''
    plt.plot(np.arange(0,100),LocalOsc.real[0:100],LocalOsc.imag[0:100])
    plt.show()
    '''

    x = Up * LocalOsc
    print("|x|:",max(abs(x*np.conj(x))))
    '''
    plt.plot(np.arange(0,100),x.real[0:100],x.imag[0:100])
    plt.show()
    '''

    '''
    f, Pxx = welch(x,Fs,return_onesided=False,noverlap=len(x)/4, nperseg=len(x)/2, nfft=len(x)/2, scaling='density')
    plt.semilogy(f/1e6, Pxx*1e6)
    plt.xlabel("f (MHz)")
    plt.ylabel("Pxx(f)")
    plt.title('M-QAM-SRRC')
    plt.show()
    '''

    return x

#########################################################################
def channel(x, ModulationOrder, Rs, EbN0):
    EsN0 = EbN0 + 10*np.log10(np.log2(ModulationOrder))
    CNR  = EsN0 - 10*np.log10(Fs/Rs)
    print("CNR:", CNR)

    # add noise to signal
    y = awgn(x, CNR)
    #y = x
    print("|y|:",max(abs(y*np.conj(y))))

    '''
    f, Pyy = welch(y,Fs,return_onesided=False)
    plt.semilogy(f/1e6, Pyy*1e6)
    plt.xlabel("f (MHz)")
    plt.ylabel("Pyy(f)")
    plt.title('M-QAM-SRRC')
    plt.show()
    '''

    return y

#######################################################################
def rrc(N, alpha, Ts, Fs):
    T_delta    = 1/float(Fs)
    time_idx   = ((np.arange(N)-N/2))*T_delta
    sample_num = np.arange(N)
    h_rrc      = np.zeros(N, dtype=float)

    for x in sample_num:
        t = (x-N/2)*T_delta
        t = round(t,30)
        if t == 0.0:
            h_rrc[x] = (1.0 - alpha + (4*alpha/np.pi))
        elif (alpha != 0 and t == Ts/(4*alpha)) or (alpha != 0 and t == -Ts/(4*alpha)):
            h_rrc[x] = (alpha/np.sqrt(2)) * (((1+2/np.pi)*(np.sin(np.pi/(4*alpha))))+((1-2/np.pi)*(np.cos(np.pi/(4*alpha)))))
        else:
            h_rrc[x] = (np.sin(np.pi*t*(1-alpha)/Ts) + 4*alpha*(t/Ts)*np.cos(np.pi*t*(1+alpha)/Ts)) / (np.pi*t*(1-(4*alpha*t/Ts)*(4*alpha*t/Ts))/Ts)
    return time_idx, h_rrc


##########################################################################
if __name__ == "__main__":
    main()
