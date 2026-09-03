#######################################################################
# Author:        Anthony A. Stock, NASA GRC/LCI [SIP]
# Creation date: 26 February 2021
# Module Name:   SingleTermCFE_in.py
# Description:   asdf
#######################################################################

import numpy as np

from matplotlib        import pyplot as plt
from commpy.channels   import awgn
from commpy.filters    import rrcosfilter
from commpy.modulation import QAMModem
from commpy.utilities  import dec2bitarray
from scipy.signal      import welch, upfirdn
from scipy.fftpack     import fft, fftshift

###### GLOBAL CONSTANTS### ###########################################
Fs       = 1.00e6
fracBits = 15
Span     = 6

# generate a huge amount of messages, but only transmit a portion
NMessages = 2**17

# simulation tracking
simNum  = 30
#simStr  = "Real_World"
#dirName = "Experiment_" + str(simNum) + "--" + simStr

#####################################################################
def main():

    #
    # Simulate Transmitters
    #

    NWaveforms = 1;

    # Waveform Index ##            0       1 
    Rs              = np.array([0.10,   0.25])*1e6      #non-over: 0.10,0.25;    over: 0.10, 0.25
    fc              = np.array([-0.05,   0.20])*1e6      #non-over: -0.2, 0.2:    over: 0.05, 0.10
    Rolloff         = np.array([0.35,   0.35])
    EbN0            = np.array([14.0,   14.0]) # dB
    ModulationOrder = np.array([4, 4])
    NIQSamples      = 2**16
    
    # create a buffer of maximum possible size
    x = np.zeros(NMessages)
    for i in range(NWaveforms):
        wf              = transmitter(ModulationOrder[i], Rs[i], fc[i], Rolloff[i], 1)
        ch              = channel(wf, ModulationOrder[i], Rs[i], EbN0[i]);
        x               = x[:NIQSamples] + ch[:NIQSamples];

        
    #
    # Simulate ADC
    #
    

    # normalize again
    x = x / max(max(abs(x.real)),max(abs(x.imag)))

    #print("after second norm: ",max(x*np.conj(x)))
    
    
    f, Pxx = welch(x,Fs,return_onesided=False, noverlap=len(x)/4, nperseg=len(x)/2, nfft=len(x)/2, scaling='spectrum')
    plt.semilogy(f/1e6, Pxx*1e6)
    plt.xlabel("f (MHz)")
    plt.ylabel("Pxx(f)")
    plt.title('M-QAM-SRRC')
    plt.show()
    
    
    # debugging waveforms
    #x_t = np.arange(Nsamples)
    #x = np.exp((1j*2*pi*fc[0]/Fs*osc_t)# * np.exp(-1j*theta)
    #x = np.ones(NIQSamples) * np.sqrt(2)/2 + 1j * np.ones(NIQSamples) * np.sqrt(2)/2
    #x = np.ones(NIQSamples) + 1j * np.ones(NIQSamples)
    
    # simulate gain control by
    # normalizing I and Q components
    #x = x / max(x) # this one ends up being greater than 1.0 for some reason
    
    x = x * (2**(fracBits)-1)/(2**fracBits)
    print("N: 2**" + str(int(np.log2(len(x)))))
    print("Max value I/Q: ", max(abs(x.real)), max(abs(x.imag)))

    # detection threshold
    beta = 1e-4
    threshold = beta * (sum(abs(x)**2)/len(x))**2
    print("Threshold:", str(threshold))
    
    # simulate quantization by
    # using fixed-point rounding
    x_Fx_Real = np.round(x.real*(2**fracBits)).astype(int)
    x_Fx_Imag = np.round(x.imag*(2**fracBits)).astype(int)

    
    # simulate sampling by
    # writing IQ samples to file
    
    with open("re_runs/i_in_exp5.txt", 'w') as realFile:
        for i in range(len(x_Fx_Real)):
            realFile.write(str(x_Fx_Real[i]) + "\n")

    with open("re_runs/q_in_exp5.txt", 'w') as imagFile:
        for i in range(len(x_Fx_Imag)):
            imagFile.write(str(x_Fx_Imag[i]) + "\n")
    
    
#########################################################################            
def transmitter(ModulationOrder, Rs, fc, Rolloff, d):
    # generate modem
    Modulator = QAMModem(ModulationOrder)

    # generate messages
    RandomInts = np.random.randint(0,ModulationOrder,NMessages)

    # convert messages to bits
    RandomBits = dec2bitarray(RandomInts,Modulator.num_bits_symbol)

    # convert bits to symbols
    RandomSymbols = Modulator.modulate(RandomBits)
    
    # generate pulse shape filter
    SamplesPerSymbol = Fs/Rs
    NTapsRrc         = Span*SamplesPerSymbol + 1
    Psf_idxs, Psf        = rrc(int(NTapsRrc), Rolloff, 1/Rs, Fs)
    
    # normalize total energy of psf to 1
    Psf = Psf / np.sqrt(sum(Psf))
    '''
    plt.plot(Psf_idxs, Psf)
    plt.show()
    exit()
    '''
    # resample & pulse shape symbols to create baseband signal
    # output length = (Fs/Rs)*(Nmessages+Span)
    rat = SamplesPerSymbol.as_integer_ratio()
    x   = upfirdn(Psf, RandomSymbols, rat[0], rat[1])    
    
    # upconvert from baseband to passband
    # d -> positive: rhs of spectrum, negative: lhs of spectrum
    LocalOsc = np.exp(d*1j*2*np.pi*fc/Fs * np.arange(len(x)))
    x        = x * LocalOsc

    #print("before norm: ",max(x*np.conj(x)))
    
    # normalize to magnitude of 1
    normFactor = 1 / max(max(abs(x.real)),max(abs(x.imag)))
    x = x*normFactor
        
    return x

#########################################################################
def channel(x, ModulationOrder, Rs, EbN0):
    EsN0 = EbN0 + 10*np.log10(np.log2(ModulationOrder))
    CNR  = EsN0 - 10*np.log10(Fs/Rs)

    # add noise to signal
    y = awgn(x, CNR)
    #y = x
    
    print("CNR:", CNR)
    #print("before noise: ",max(x*np.conj(x)))
    #print("after  noise: ",max(y*np.conj(y)))

    return y

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

