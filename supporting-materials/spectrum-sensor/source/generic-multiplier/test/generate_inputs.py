#######################################################################
# Author:        Anthony A. Stock, intern, NASA GRC/LCI
# Creation date: 9 September 2020
# Module Name:   generate_inputs.py
# Description:   This program generates a user-defined number of test
#                vectors for the Generic Signed Multiplier module, in
#                addition to a set of edge cases. Produces two files:
#                input vectors for the testbench, and theoretical
#                outputs.
#######################################################################

import numpy as np
import csv
import random

######################## USER-DEFINED PARAMETERS ######################
LEN_A = 4
LEN_B = 4
BITS_TRUNC = 0
BITS_ROUND = 0
NUM_RAND_VECTORS = 10000 # number of randomized test vectors to generate
#######################################################################

EDGE_CASES_A = [0, 1, -1, 2**(LEN_A-1)-1, -2**(LEN_A-1)] # edge cases for A.
EDGE_CASES_B = [0, 1, -1, 2**(LEN_B-1)-1, -2**(LEN_B-1)] # edge cases for B. Assumed to be same length as EDGE_CASES_A

def main():
    # create randomized test vectors
    A_in = [random.randint(-2**(LEN_A-1), 2**(LEN_A-1)-1) for i in range(NUM_RAND_VECTORS)]
    B_in = [random.randint(-2**(LEN_B-1), 2**(LEN_B-1)-1) for i in range(NUM_RAND_VECTORS)]

    # Create all permutations of edge cases between A and B
    Edges_A = list(np.repeat(EDGE_CASES_A, len(EDGE_CASES_B)))
    Edges_B = list(EDGE_CASES_B) * len(EDGE_CASES_A)

    # append edge cases to randomized vectors
    A_in = np.append(A_in, Edges_A)
    B_in = np.append(B_in, Edges_B)

    # The following commented-out lines are a legacy feature that creates ALL possible permutations
    # of inputs between A and B. File sizes blow up for longer vector widths.

    # generate test vectors and fill with every number for that length
    #A_in = np.arange(-2**(LEN_A-1),2**(LEN_A-1))
    #B_in = np.arange(-2**(LEN_B-1),2**(LEN_B-1))
    # extend each list such that each pair of A_in[i], B_in[i] represents all possible combinations
    #A_in = list(np.repeat(A_in, 2**LEN_B))
    #B_in = list(B_in) * (2**LEN_A)

    # convert everything to signed binary format for test vectors
    A_bin = [twosComp(A_in[i],LEN_A) for i in range(len(A_in))]
    B_bin = [twosComp(B_in[i],LEN_B) for i in range(len(B_in))]

    # perform rounding
    if BITS_ROUND > 0:
        C_bin = list()
        for i in range(len(A_in)):
            C_tmp = A_in[i]*B_in[i]
            C_tmp += 2**BITS_ROUND-1
            C_bin.append(twosComp(C_tmp,LEN_A+LEN_B))
    else:
        C_bin = [twosComp(A_in[i]*B_in[i],LEN_A+LEN_B) for i in range(len(A_in))]

    # perform truncation
    for i in range(len(C_bin)):
        if BITS_TRUNC>0 and C_bin[i][0] == '0' and C_bin[i][1:BITS_TRUNC+1] != '0'*(BITS_TRUNC):
            C_bin[i] = '0' + '1'*(LEN_A+LEN_B-BITS_ROUND-BITS_TRUNC-1)
        elif BITS_TRUNC>0 and C_bin[i][0] == '1' and C_bin[i][1:BITS_TRUNC+1] != '1'*(BITS_TRUNC):
            C_bin[i] = '1' + '0'*(LEN_A+LEN_B-BITS_ROUND-BITS_TRUNC-1)
        else:
            C_bin[i] = C_bin[i][BITS_TRUNC:LEN_A+LEN_B-BITS_ROUND]

    # to be written to csv file
    rows = [A_bin, B_bin]

    # write test vectors and theoretical results to csv files
    with open("inputs.csv", 'w') as csvfile:
        csvwriter = csv.writer(csvfile)
        csvwriter.writerows(zip(*rows))

    with open("out_theoretical.csv", 'w') as csvfile:
        csvwriter = csv.writer(csvfile)
        csvwriter.writerows(zip(*[C_bin]))

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


if __name__ == '__main__':
    main()
