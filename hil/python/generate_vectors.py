#!/usr/bin/env python3
"""
Generate AES-128 test vectors for simulation and verification.

The default output is a comprehensive, deterministic regression suite:
- canonical FIPS-197 examples
- edge cases such as all-zero and all-one patterns
- walking-one plaintext vectors with a zero key
- walking-one key vectors with a zero plaintext

Optional additional random vectors can be appended for stress testing.

Requirements:
    pip install pycryptodome

Usage:
    python3 generate_vectors.py [extra_random_vectors] [output_file]

    extra_random_vectors: optional number of random vectors to append (default: 0)
    output_file: path to output file (default: test_vectors.txt)
"""

import sys
from pathlib import Path
from typing import List, Tuple
from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes


Vector = Tuple[str, str, str]


def _encrypt_vector(plaintext_hex: str, key_hex: str) -> str:
    plaintext = bytes.fromhex(plaintext_hex)
    key = bytes.fromhex(key_hex)
    cipher = AES.new(key, AES.MODE_ECB)
    return cipher.encrypt(plaintext).hex().upper()


def _append_vector(vectors: List[Vector], plaintext_hex: str, key_hex: str):
    ciphertext_hex = _encrypt_vector(plaintext_hex, key_hex)
    vectors.append((plaintext_hex.upper(), ciphertext_hex.upper(), key_hex.upper()))


def _build_comprehensive_vectors() -> List[Vector]:
    vectors: List[Vector] = []

    canonical_vectors = [
        ("00112233445566778899AABBCCDDEEFF", "000102030405060708090A0B0C0D0E0F"),
        ("6BC1BEE22E409F96E93D7E117393172A", "2B7E151628AED2A6ABF7158809CF4F3C"),
        ("AE2D8A571E03AC9C9EB76FAC45AF8E51", "2B7E151628AED2A6ABF7158809CF4F3C"),
        ("30C81C46A35CE411E5FBC1191A0A52EF", "2B7E151628AED2A6ABF7158809CF4F3C"),
    ]

    edge_vectors = [
        ("00000000000000000000000000000000", "00000000000000000000000000000000"),
        ("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF", "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
        ("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", "55555555555555555555555555555555"),
        ("55555555555555555555555555555555", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
    ]

    zero_key = "00000000000000000000000000000000"
    zero_plaintext = "00000000000000000000000000000000"

    for plaintext_hex, key_hex in canonical_vectors + edge_vectors:
        _append_vector(vectors, plaintext_hex, key_hex)

    for bit_index in range(128):
        plaintext_hex = (1 << bit_index).to_bytes(16, byteorder="big").hex().upper()
        _append_vector(vectors, plaintext_hex, zero_key)

    for bit_index in range(128):
        key_hex = (1 << bit_index).to_bytes(16, byteorder="big").hex().upper()
        _append_vector(vectors, zero_plaintext, key_hex)

    return vectors


def _append_random_vectors(vectors: List[Vector], count: int):
    for _ in range(count):
        key = get_random_bytes(16)
        plaintext = get_random_bytes(16)
        cipher = AES.new(key, AES.MODE_ECB)
        ciphertext = cipher.encrypt(plaintext)
        vectors.append((plaintext.hex().upper(), ciphertext.hex().upper(), key.hex().upper()))


def generate_vectors(extra_random_vectors=0, output_file="test_vectors.txt"):
    """
    Generate a comprehensive AES-128 regression vector file.

    The generated file uses the canonical format:
        plaintext ciphertext key

    The first vectors are deterministic and cover the standard and edge-case
    space used for hardware validation. Optional random vectors can be added
    for additional stress coverage.
    
    Args:
        extra_random_vectors: Number of random vectors to append.
        output_file: Output file path relative to current directory.
    
    Returns:
        True if generation successful, False on error (dependency missing, I/O error, etc).
    """
    
    try:
        vectors = _build_comprehensive_vectors()
        _append_random_vectors(vectors, extra_random_vectors)

        output_path = Path(output_file)
        if not output_path.is_absolute():
            output_path = Path.cwd() / output_path

        with output_path.open('w', encoding='utf-8') as f:
            f.write("# AES-128 Test Vectors\n")
            f.write("# Format: plaintext ciphertext key (hexadecimal)\n")
            f.write("# Coverage: canonical FIPS-197 vectors, edge cases, and walking-one vectors\n")
            if extra_random_vectors > 0:
                f.write(f"# Additional random vectors appended: {extra_random_vectors}\n")
            f.write("\n")
            for plaintext_hex, ciphertext_hex, key_hex in vectors:
                f.write(f"{plaintext_hex} {ciphertext_hex} {key_hex}\n")

        print(f"Generated {len(vectors)} test vectors")
        print(f"Saved to: {output_path}")
        
        return True
    
    except ImportError:
        print("ERROR: pycryptodome not installed")
        print("Install with: pip install pycryptodome")
        return False
    except Exception as e:
        print(f"ERROR: {e}")
        return False


if __name__ == "__main__":
    extra_random_vectors = 0
    output_file = "test_vectors.txt"
    
    if len(sys.argv) > 1:
        try:
            extra_random_vectors = int(sys.argv[1])
        except ValueError:
            print(f"ERROR: First argument must be an integer, got '{sys.argv[1]}'")
            sys.exit(1)
    
    if len(sys.argv) > 2:
        output_file = sys.argv[2]
    
    success = generate_vectors(extra_random_vectors, output_file)
    sys.exit(0 if success else 1)
