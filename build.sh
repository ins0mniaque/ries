#!/bin/sh

gcc src/ries.c -lm -o ries
gcc -lstdc++ src/zeta.cpp -lm -o zeta