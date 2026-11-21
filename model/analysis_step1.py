import random, itertools, os

H=W=5; K=3; O=3
def wrap(x,b):
    m=1<<b; x&=m-1
    return x-m if x>>(b-1) else x

def conv_raw(img,ker):
    """raw[o], o=r*3+c, k=kr*3+kc; img[row][col], ker[k]"""
    out=[]
    for o in range(9):
        r,c=divmod(o,3)
        out.append(sum(ker[k]*img[r+k//3][c+k%3] for k in range(9)))
    return out

def relu_trunc(x):          # matches rtl: neg->0 else low 8 bits (no saturation)
    return 0 if x<0 else x&0xFF

def expected_checksum(img,ker):
    # independent of conv outputs: only image + kernel
    tot=0
    for k in range(9):
        kr,kc=divmod(k,3)
        ws=sum(img[kr+i][kc+j] for i in range(3) for j in range(3))
        tot+=ker[k]*ws
    return tot

def systolic_chain(img,ker,fault=None):
    """functional model of the PE chain. fault=(site,pe,window,bit), site 'prod' or 'psum'.
    psum_k = wrap20(psum_{k-1} + prod_k); returns p8 per window."""
    out=[]
    for o in range(9):
        r,c=divmod(o,3); ps=0
        for k in range(9):
            x=img[r+k//3][c+k%3]
            p=ker[k]*x
            if fault and fault[0]=='prod' and fault[1]==k and fault[2]==o:
                p=wrap(p^(1<<fault[3]) if True else p,16) if False else wrap((p&0xFFFF)^(1<<fault[3]),16)
            ps=wrap(ps+p,20)
            if fault and fault[0]=='psum' and fault[1]==k and fault[2]==o:
                ps=wrap((ps&0xFFFFF)^(1<<fault[3]),20)
        out.append(ps)
    return out

# ---- 1. check against the testbench's hard-coded expected values
t1=[5,2,1,6,9, 13,0,0,0,10, 4,0,0,0,7, 14,0,0,0,12, 11,8,6,15,3]
t1=[t1[i*5:(i+1)*5] for i in range(5)]
k1=[1,2,1,2,4,2,1,2,1]
r=conv_raw(t1,k1); print("T1 raw",r,"relu",[relu_trunc(x) for x in r],"(tb exp 40 10 49 35 0 36 65 35 70)")
print("T1 checksum computed",sum(r),"expected",expected_checksum(t1,k1))
t2v=[10,10,10,1,1,10,10,10,1,1,10,10,10,1,1,1,1,1,10,10,1,1,1,10,10]
t2=[t2v[i*5:(i+1)*5] for i in range(5)]
k2=[1,1,1,1,-5,1,1,1,1]
r=conv_raw(t2,k2); print("T2 raw",r,"relu",[relu_trunc(x) for x in r],"(tb exp 30 3 30 3 0 39 30 39 0)")
print("T2 checksum computed",sum(r),"expected",expected_checksum(t2,k2))

# ---- 2. identity on random + extreme vectors, and bounds
random.seed(1)
vecs=[]
for _ in range(20000):
    vecs.append(([[random.randint(0,255) for _ in range(5)] for _ in range(5)],[random.randint(-128,127) for _ in range(9)]))
vecs.append(([[255]*5]*5,[-128]*9)); vecs.append(([[255]*5]*5,[127]*9)); vecs.append(([[0]*5]*5,[-128]*9))
mn=mx=0; mnr=mxr=0; bad=0; chain_bad=0
for img,ker in vecs:
    raw=conv_raw(img,ker); cs=sum(raw)
    if cs!=expected_checksum(img,ker): bad+=1
    if systolic_chain(img,ker)!=raw: chain_bad+=1
    mn=min(mn,cs);mx=max(mx,cs);mnr=min(mnr,min(raw));mxr=max(mxr,max(raw))
print("identity failures:",bad,"/",len(vecs)," chain-model!=conv:",chain_bad)
print("observed raw range",mnr,mxr,"| checksum range",mn,mx)
print("theory: raw min",9*255*-128,"max",9*255*127,"| checksum min",81*255*-128,"max",81*255*127)
print("signed bits needed: raw",(9*255*-128).bit_length()+1,"checksum",(81*255*-128).bit_length()+1)

# ---- 3. software single-bit-flip campaign (exact 23-bit vs mod-2^20 checksum)
def campaign(img,ker):
    gold=conv_raw(img,ker); gexp=expected_checksum(img,ker)
    res={'det_exact':0,'det_mod20':0,'miss_exact':0,'miss_mod20':0,'det_but_masked':0,'det_visible':0,'total':0}
    for site,nb in (('prod',16),('psum',20)):
        for pe in range(9):
            for o in range(9):
                for b in range(nb):
                    f=systolic_chain(img,ker,(site,pe,o,b)); res['total']+=1
                    de = sum(f)!=gexp
                    dm = wrap(sum(f),20)!=wrap(gexp,20)
                    res['det_exact']+=de; res['miss_exact']+=(not de)
                    res['det_mod20']+=dm; res['miss_mod20']+=(not dm)
                    vis=[relu_trunc(x) for x in f]!=[relu_trunc(x) for x in gold]
                    if de and vis: res['det_visible']+=1
                    if de and not vis: res['det_but_masked']+=1
    return res
for name,(img,ker) in (("T1",(t1,k1)),("T2",(t2,k2))):
    print(name,campaign(img,ker))
img,ker=vecs[0]; print("random",campaign(img,ker))

# ---- 4. a double-fault alias example (two flips that cancel)
img,ker=t1,k1
g=conv_raw(img,ker); 
f1=systolic_chain(img,ker,('psum',8,0,3)); f2=systolic_chain(img,ker,('psum',8,1,3))
d=[a-b for a,b in zip(f1,g)]; d2=[a-b for a,b in zip(f2,g)]
print("single-flip deltas on window0 / window1:",d[0],d2[1],"-> if signs opposite, two simultaneous flips can cancel in the sum")

# ---- 5. emit vectors for the testbench
def emit(name,img,ker):
    raw=conv_raw(img,ker)
    with open(name,'w') as f:
        f.write(' '.join(f"{p:02x}" for row in img for p in row)+'\n')
        f.write(' '.join(f"{w&0xFF:02x}" for w in ker)+'\n')
        f.write(' '.join(f"{x&0xFFFFF:05x}" for x in raw)+'\n')
        f.write(f"{wrap(sum(raw),23)&0x7FFFFF:06x}\n")
random.seed(7); n=0
sets=[(t1,k1),(t2,k2),([[255]*5]*5,[-128]*9),([[255]*5]*5,[127]*9),([[0]*5]*5,[-128]*9)]
# asymmetric kernel (catches transposed/flipped taps)
sets.append(([[random.randint(0,255) for _ in range(5)] for _ in range(5)],[1,2,3,4,5,6,7,8,9]))
for _ in range(50): sets.append(([[random.randint(0,255) for _ in range(5)] for _ in range(5)],[random.randint(-128,127) for _ in range(9)]))
with open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','vectors','vectors_combined.txt'),'w') as f:
    for img,ker in sets:
        raw=conv_raw(img,ker)
        f.write(' '.join(f"{p:02x}" for row in img for p in row)+' | ')
        f.write(' '.join(f"{w&0xFF:02x}" for w in ker)+' | ')
        f.write(' '.join(f"{x&0xFFFFF:05x}" for x in raw)+' | ')
        f.write(f"{wrap(sum(raw),23)&0x7FFFFF:06x}\n")
print("wrote",len(sets),"vectors")
