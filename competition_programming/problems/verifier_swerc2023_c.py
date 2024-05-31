#!/usr/bin/python3
import sys

with open(sys.argv[2]) as f:
    s = f.read()
    out = None if s.strip() == 'not possible' else float(s)
with open(sys.argv[3]) as f:
    s = f.read()
    ans = None if s.strip() == 'not possible' else float(s)

if out is None or ans is None:
    assert(out == ans)
else:
    assert(abs(ans - out) <= 1e-4)
