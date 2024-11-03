#!/bin/sh

mkdir -p doc
mkdir -p src

curl -o COPYING                http://mrob.com/pub/ries/COPYING.txt
curl -o FDL-1.3                http://mrob.com/pub/ries/FDL-1.3.txt
curl -o doc/ries-manual.txt    http://mrob.com/pub/ries/doc/ries-manual.txt
curl -o doc/ries.1             http://mrob.com/pub/ries/doc/ries.1.txt
curl -o src/latin.ries         http://mrob.com/pub/ries/src/latin.ries.txt
curl -o src/Mathematica.ries   http://mrob.com/pub/ries/src/Mathematica.ries.txt
curl -o src/msal_math64.c      http://mrob.com/pub/ries/src/msal_math64.c.txt
curl -o src/pf2if.pl           http://mrob.com/pub/ries/src/pf2if.pl.txt
curl -o src/ries.c             http://mrob.com/pub/ries/src/ries.c.txt
curl -o src/ries-for-windows.c http://mrob.com/pub/ries/src/ries-for-windows.c.txt
curl -o src/zeta.cpp           http://mrob.com/pub/ries/src/zeta.cpp.txt