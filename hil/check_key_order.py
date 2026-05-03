from binascii import unhexlify, hexlify

def to_bytes(s):
    return list(unhexlify(s))

def to_hex(b):
    return hexlify(bytes(b)).decode().upper()

expected = 'A0FAFE1788542CB123A33939552244F6'.lower()
got      = '53B1DAF578CFCFE350611D45FB9608CD'.lower()

exp = to_bytes(expected)
gt  = to_bytes(got)

transforms = []
# identity
transforms.append(('identity', lambda b: b))
# reverse entire 16 bytes
transforms.append(('reverse16', lambda b: b[::-1]))
# reverse words order (4 words)
transforms.append(('reverse_words', lambda b: b[12:16]+b[8:12]+b[4:8]+b[0:4]))
# reverse bytes in each 4-byte word
transforms.append(('rev_each_word', lambda b: b[3:4]+b[2:3]+b[1:2]+b[0:1] + b[7:8]+b[6:7]+b[5:6]+b[4:5] + b[11:12]+b[10:11]+b[9:10]+b[8:9] + b[15:16]+b[14:15]+b[13:14]+b[12:13]))
# rotate each 4-byte word left by 1 byte
def rot_left_word(b):
    out=[]
    for i in range(0,16,4):
        w=b[i:i+4]
        out+=w[1:4]+w[0:1]
    return out
transforms.append(('rot_word_left1', rot_left_word))
# rotate each 4-byte word right by 1 byte
def rot_right_word(b):
    out=[]
    for i in range(0,16,4):
        w=b[i:i+4]
        out+=w[3:4]+w[0:3]
    return out
transforms.append(('rot_word_right1', rot_right_word))
# swap32 endian (treat word big->little)
import struct
def swap32_endian(b):
    out=[]
    for i in range(0,16,4):
        w=b[i:i+4]
        val=struct.unpack('>I', bytes(w))[0]
        out+=list(struct.pack('<I', val))
    return out
transforms.append(('swap32_lebe', swap32_endian))

print('Expected:', expected.upper())
print('Got:     ', got.upper())
print('\nTesting transforms applied to Expected => Got:')
found=False
for name,fn in transforms:
    t = fn(exp)
    h = to_hex(t)
    match = 'MATCH' if h.upper() == got.upper() else ''
    if match:
        found=True
    print(f'{name:20s}: {h} {match}')

print('\nTesting transforms applied to Got => Expected:')
for name,fn in transforms:
    t = fn(gt)
    h = to_hex(t)
    match = 'MATCH' if h.upper() == expected.upper() else ''
    print(f'got->{name:14s}: {h} {match}')

if not found:
    print('\nNo simple transform matched. Will try byte-per-word reorderings...')
    # try swapping whole words and bytes combos
    words = [exp[0:4], exp[4:8], exp[8:12], exp[12:16]]
    from itertools import permutations
    for perm in permutations(range(4)):
        cand = []
        for idx in perm:
            cand += words[idx]
        h = to_hex(cand)
        if h.upper() == got.upper():
            print('Permutation match words order:', perm)
            found=True
            break
    if not found:
        print('No word-permutation match found.')

print('\nDone.')
