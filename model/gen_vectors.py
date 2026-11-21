"""Writes vectors/{img,ker,fm,raw,cs}.hex. Run:  python3 model/gen_vectors.py"""
import os, random
from cnn_model import *
random.seed(7)
g = lambda v: [v[i*5:(i+1)*5] for i in range(5)]
t1 = [5,2,1,6,9,13,0,0,0,10,4,0,0,0,7,14,0,0,0,12,11,8,6,15,3]
t2 = [10,10,10,1,1,10,10,10,1,1,10,10,10,1,1,1,1,1,10,10,1,1,1,10,10]
sets = [(g(t1),[1,2,1,2,4,2,1,2,1]), (g(t2),[1,1,1,1,-5,1,1,1,1]),     # your two original tests
        ([[255]*5]*5,[-128]*9), ([[255]*5]*5,[127]*9), ([[0]*5]*5,[-128]*9),   # extremes
        (g([random.randint(0,255) for _ in range(25)]),[1,2,3,4,5,6,7,8,9]),   # asymmetric kernels
        (g([random.randint(0,255) for _ in range(25)]),[9,8,7,6,5,4,3,2,1])]
for _ in range(50):
    sets.append((g([random.randint(0,255) for _ in range(25)]), [random.randint(-128,127) for _ in range(9)]))

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'vectors')
os.makedirs(out, exist_ok=True)
f = {n: open(os.path.join(out, n + '.hex'), 'w') for n in ('img','ker','fm','raw','cs')}
for img, ker in sets:
    raw = conv_raw(img, ker)
    assert sum(raw) == expected_checksum(img, ker)          # identity self-check
    assert systolic_chain(img, ker) == raw                   # chain model self-check
    for r in img:
        for p in r: f['img'].write(f"{p:02x}\n")
    for w in ker: f['ker'].write(f"{w & 0xFF:02x}\n")
    for x in raw:
        f['raw'].write(f"{x & 0xFFFFF:05x}\n"); f['fm'].write(f"{relu_trunc(x):02x}\n")
    f['cs'].write(f"{wrap(sum(raw), 23) & 0x7FFFFF:06x}\n")
for h in f.values(): h.close()
print(f"wrote {len(sets)} vectors to {os.path.abspath(out)}")
