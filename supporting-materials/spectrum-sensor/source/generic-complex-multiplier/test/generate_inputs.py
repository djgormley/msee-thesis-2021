#######################################################################
# Author:        Anthony A. Stock, intern, NASA GRC/LCI
# Creation date: 23 September 2020
# Module Name:   generate_inputs.py
# Description:   This program generates a user-defined number of test
#                vectors for the Generic Complex Multiplier testbench,
#                in addition to a sequence of edge cases. A
#                corresponding set of theoretical output test vectors
#                is generated to be compared with the testbench output.
#######################################################################

import numpy as np
import csv
import random

######################## USER-DEFINED PARAMETERS ######################
LEN_A = 4
LEN_B = 4
BITS_TRUNC = 0
BITS_ROUND = 0
NUM_RAND_VECTORS = 1# number of randomized test vectors to generate
#######################################################################

EDGE_CASES_A = [0, 1, -1, 2**(LEN_A-1)-1, -2**(LEN_A-1)] # edge cases for A.
EDGE_CASES_B = [0, 1, -1, 2**(LEN_B-1)-1, -2**(LEN_B-1)] # edge cases for B. Assumed to be same length as EDGE_CASES_A

def main():

    productLen   = LEN_A+LEN_B
    productLenTR = LEN_A+LEN_B-BITS_TRUNC-BITS_ROUND
    numVecs = len(EDGE_CASES_A)**4 + NUM_RAND_VECTORS

    # These arrays represent all possible permutations of edge cases between the 4 inputs
    EdgeCasesA1 = list(EDGE_CASES_A) * (len(EDGE_CASES_A)**3)
    EdgeCasesA2 = list(np.repeat(EdgeCasesA1, len(EDGE_CASES_A)))[:len(EDGE_CASES_A)**4]
    EdgeCasesB1 = list(np.repeat(EDGE_CASES_B, len(EDGE_CASES_A)**2)) * len(EDGE_CASES_A)
    EdgeCasesB2 = list(np.repeat(EDGE_CASES_B, len(EDGE_CASES_A)**3))

    # generate randomized test vectors
    RealA = [random.randint(-2**(LEN_A-1), 2**(LEN_A-1)-1) for i in range(NUM_RAND_VECTORS)]
    ImagA = [random.randint(-2**(LEN_A-1), 2**(LEN_A-1)-1) for i in range(NUM_RAND_VECTORS)]
    RealB = [random.randint(-2**(LEN_B-1), 2**(LEN_B-1)-1) for i in range(NUM_RAND_VECTORS)]
    ImagB = [random.randint(-2**(LEN_B-1), 2**(LEN_B-1)-1) for i in range(NUM_RAND_VECTORS)]

    # append arrays of all possible permutations of edge cases onto the randomized test vector arrays
    RealA = np.append(RealA, EdgeCasesA1)
    ImagA = np.append(ImagA, EdgeCasesA2)
    RealB = np.append(RealB, EdgeCasesB1)
    ImagB = np.append(ImagB, EdgeCasesB2)

    # convert everything to signed binary for input vectors. No more computation is performed with these.
    RA_bin = [twosComp(RealA[i],LEN_A) for i in range(numVecs)]
    IA_bin = [twosComp(ImagA[i],LEN_A) for i in range(numVecs)]
    RB_bin = [twosComp(RealB[i],LEN_B) for i in range(numVecs)]
    IB_bin = [twosComp(ImagB[i],LEN_B) for i in range(numVecs)]

    # compute terms AC, BD, AD, and BC from foil method: (A+Bi)(C+Di)
    AC = [RealA[i]*RealB[i] for i in range(numVecs)]
    BD = [ImagA[i]*ImagB[i] for i in range(numVecs)]
    AD = [RealA[i]*ImagB[i] for i in range(numVecs)]
    BC = [ImagA[i]*RealB[i] for i in range(numVecs)]

    # perform rounding, truncation, and conversion to base-two string. Emulates rounding/truncation in vhdl src file.
    AC_bin = roundAndTrunc(AC, productLen, BITS_TRUNC, BITS_ROUND)
    BD_bin = roundAndTrunc(BD, productLen, BITS_TRUNC, BITS_ROUND)
    AD_bin = roundAndTrunc(AD, productLen, BITS_TRUNC, BITS_ROUND)
    BC_bin = roundAndTrunc(BC, productLen, BITS_TRUNC, BITS_ROUND)

    # Find integer value after being rounded/truncated, so we can calculate sum / difference in next step
    ACR = [int("0b"+AC_bin[i],2)-(2**productLenTR) if AC_bin[i][0]=='1' else int("0b"+AC_bin[i],2) for i in range(numVecs)]
    BDR = [int("0b"+BD_bin[i],2)-(2**productLenTR) if BD_bin[i][0]=='1' else int("0b"+BD_bin[i],2) for i in range(numVecs)]
    ADR = [int("0b"+AD_bin[i],2)-(2**productLenTR) if AD_bin[i][0]=='1' else int("0b"+AD_bin[i],2) for i in range(numVecs)]
    BCR = [int("0b"+BC_bin[i],2)-(2**productLenTR) if BC_bin[i][0]=='1' else int("0b"+BC_bin[i],2) for i in range(numVecs)]

    # Compute (AC-BD) and (AD+BC), the real and imaginary products, then convert back to two's compliment binary string
    ACBD = [ twosComp(ACR[i] - BDR[i], productLenTR+1) for i in range(numVecs) ]
    ADBC = [ twosComp(ADR[i] + BCR[i], productLenTR+1) for i in range(numVecs) ]

    # to be written to csv file
    inputRows = [RA_bin, IA_bin, RB_bin, IB_bin] # input vectors
    outputRows = [ACBD, ADBC]                    # theoretical outputs (AC-BD) and (AD+BC)

    # write test vectors and theoretical results to csv files
    with open("inputs.csv", 'w') as csvfile:
        csvwriter = csv.writer(csvfile)
        csvwriter.writerows(zip(*inputRows))

    with open("out_theoretical.csv", 'w') as csvfile:
        csvwriter = csv.writer(csvfile)
        csvwriter.writerows(zip(*outputRows))

    return

### END OF MAIN ###

# This function converts integers into a string of 0's and 1's representing the binary equivalent.
def twosComp(n, bits):
    # print error message if the given number of bits is too small to represent this number
    if n > (2**(bits-1))-1 or n < -2**(bits-1):
        print("Number " + str(n) + " out of range for given length " + str(bits))

    # convert to binary format. Cast n to int in case it's np.int64
    s = bin(int(n) & int("1"*bits, 2))[2:]

    return ("{0:0>%s}" % (bits)).format(s)

# This function performs rounding and truncation
def roundAndTrunc(listIn, length, bitsT, bitsR):
    # perform rounding and convert to two's compliment form
    if bitsR > 0:
        listBin = list()
        for i in range(len(listIn)):
            listIn[i] += 2**bitsR-1
            listBin.append(twosComp(listIn[i],length))
    else:
        listBin = [twosComp(listIn[i],length) for i in range(len(listIn))]

    # perform truncation
    for i in range(len(listBin)):
        if bitsT>0 and listBin[i][0] == '0' and listBin[i][1:bitsT+1] != '0'*(bitsT):
            listBin[i] = '0' + '1'*(length-bitsR-bitsT-1)
        elif bitsT>0 and listBin[i][0] == '1' and listBin[i][1:bitsT+1] != '1'*(bitsT):
            listBin[i] = '1' + '0'*(length-bitsR-bitsT-1)
        else:
            listBin[i] = listBin[i][bitsT:length-bitsR]

    return listBin


if __name__ == '__main__':
    main()
