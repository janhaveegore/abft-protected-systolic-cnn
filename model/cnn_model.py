"""Software reference model: convolution, ABFT checksum, PE-chain model, fault model."""
def wrap(x, b):
    m = 1 << b; x &= m - 1
    return x - m if x >> (b - 1) else x

def conv_raw(img, ker):
    """raw[o], o=r*3+c ; tap k=kr*3+kc ; img[row][col] (5x5), ker[k] (9)"""
    return [sum(ker[k] * img[o // 3 + k // 3][o % 3 + k % 3] for k in range(9)) for o in range(9)]

def relu_trunc(x):
    """RTL behaviour: negative -> 0, else low 8 bits (wraps, no saturation)."""
    return 0 if x < 0 else x & 0xFF

def expected_checksum(img, ker):
    """Independent of the conv outputs: only image + kernel."""
    tot = 0
    for k in range(9):
        kr, kc = divmod(k, 3)
        tot += ker[k] * sum(img[kr + i][kc + j] for i in range(3) for j in range(3))
    return tot

def systolic_chain(img, ker, fault=None):
    """Functional PE-chain model. fault=(site,pe,window,bit), site 'prod' or 'psum'."""
    out = []
    for o in range(9):
        r, c = divmod(o, 3); ps = 0
        for k in range(9):
            p = ker[k] * img[r + k // 3][c + k % 3]
            if fault and fault[0] == 'prod' and fault[1:3] == (k, o):
                p = wrap((p & 0xFFFF) ^ (1 << fault[3]), 16)
            ps = wrap(ps + p, 20)
            if fault and fault[0] == 'psum' and fault[1:3] == (k, o):
                ps = wrap((ps & 0xFFFFF) ^ (1 << fault[3]), 20)
        out.append(ps)
    return out
