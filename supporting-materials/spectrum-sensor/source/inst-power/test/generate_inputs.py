#######################################################################
# Author:        Anthony A. Stock, intern, NASA GRC/LCI
# Creation date: 5 October 2020
# Module Name:   generate_inputs.py
# Description:   This file generates a user-defined number of test
#                vectors for the Instantaneous Power Module, in
#                addition to a set of edge cases. Produces two files:
#                input vectors for the testbench, and theoretical
#                outputs.
#######################################################################

import numpy as np
import csv
import random

######################## USER-DEFINED PARAMETERS ######################
LEN_A = 16
LEN_B = 16
BITS_TRUNC = 0
BITS_ROUND = 0
NUM_RAND_VECTORS = 0 # number of randomized test vectors to generate
#######################################################################

#EDGE_CASES_A = [0, 1, -1, 2**(LEN_A-1)-1, -2**(LEN_A-1)] # edge cases for A.
#EDGE_CASES_B = [0, 1, -1, 2**(LEN_B-1)-1, -2**(LEN_B-1)] # edge cases for B. Assumed to be same length as EDGE_CASES_A
EDGE_CASES_A = [2**(LEN_A-1)-1] # edge cases for A.
EDGE_CASES_B = [2**(LEN_B-1)-1] # edge cases for B. Assumed to be same length as EDGE_CASES_A
LEN_C = max(LEN_A,LEN_B)*2                               # length of C before rounding/truncation

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

    #######################################################################
    # The following commented-out lines are a legacy feature that creates ALL possible permutations
    # of inputs between A and B. File sizes blow up for longer vector widths. Useful for testing/debugging.
    #
    # generate test vectors and fill with every number for that length
    #A_in = np.arange(-2**(LEN_A-1), 2**(LEN_A-1))
    #B_in = np.arange(-2**(LEN_B-1), 2**(LEN_B-1))
    # extend each list such that each pair of A_in[i], B_in[i] represents all possible combinations
    #A_in = list(np.repeat(A_in, 2**LEN_B))
    #B_in = list(B_in) * (2**LEN_A)
    #######################################################################

    # use long ints to prevent overflow  ---> this overflows anyways for LEN_A=LEN_B=32. future work.
    # you can still generate 32b test vectors, but you'll need to comment out calculation of C_out.
    #[np.int64(item) for item in A_in]
    #[np.int64(item) for item in B_in]

    # square all numbers (first step of computing instantaneous power)
    A_in_sq = [i**2 for i in A_in]
    B_in_sq = [i**2 for i in B_in]

    print(type(A_in_sq[0]))

    # Add A**2 and B**2 to calculate instantaneous power
    C_out = [A_in_sq[i] + B_in_sq[i] for i in range(len(A_in_sq))]

    # conversion to base 2 string, rounding and truncation
    C_out = [C_out[i] + 2**BITS_ROUND-1 if C_out[i] + 2**BITS_ROUND-1 < 2**(LEN_C-1) else 2**(LEN_C-1)-1 for i in range(len(C_out))]
    C_out = [twosComp(C_out[i], LEN_C) for i in range(len(C_out))]
    C_out = [C_out[i][BITS_TRUNC:LEN_C-BITS_ROUND] for i in range(len(C_out))]

    # convert input vectors to signed binary to be written to file
    A_bin = [twosComp(A_in[i],LEN_A) for i in range(len(A_in))]
    B_bin = [twosComp(B_in[i],LEN_B) for i in range(len(B_in))]
    rows = [A_bin, B_bin]

    # write out test input vectors
    with open("inputs.csv", 'w') as csvfile:
        csvwriter = csv.writer(csvfile)
        csvwriter.writerows(zip(*rows))

    # write out theoretical output vectors
    with open("out_theo.csv", 'w') as csvfile:
        csvwriter = csv.writer(csvfile)
        csvwriter.writerows(zip(*[C_out]))

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
