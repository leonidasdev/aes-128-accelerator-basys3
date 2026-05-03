#!/usr/bin/env python3
"""
aes_hil_test.py — Hardware-in-the-Loop Testing Framework
Validates FPGA AES implementation against a trusted reference implementation.

Usage:
    python aes_hil_test.py [--port COM3] [--baudrate 115200]

Requirements:
    pip install -r ../requirements.txt

Standards:
    - NIST FIPS 197 (AES Specification)
    - ECB Mode (Electronic Codebook) for block validation only
    - Reference: pycryptodome library
"""

import serial
import time
import sys
import argparse
from pathlib import Path
from typing import List, Tuple
from Crypto.Cipher import AES
import binascii


class AESHardwareTest:
    """Hardware-in-the-loop test controller for AES FPGA accelerator"""
    
    def __init__(self, port: str = 'COM3', baudrate: int = 115200, timeout: float = 1.0):
        try:
            self.port = serial.Serial(port, baudrate, timeout=timeout)
            self.baudrate = baudrate
            self.port_name = port
            print(f"Connected to {port} at {baudrate} bps")
        except serial.SerialException as e:
            print(f"ERROR: Failed to connect to {port}: {e}")
            sys.exit(1)
        
        self.pass_count = 0
        self.fail_count = 0
        self.operation_timeout = 0.02  # 20ms default (adjustable)
    
    def _send_command(self, cmd: str) -> str:
        """
        Send a command to the FPGA accelerator and retrieve response.
        
        Args:
            cmd: Command string to transmit (e.g., "KEY:00112233...").
        
        Returns:
            Response string from device, or "ERROR" on serial failure.
        
        Raises:
            None (errors logged and returned as "ERROR").
        """
        try:
            self.port.write((cmd + '\n').encode())
            response = self.port.readline().decode().strip()
            return response
        except serial.SerialException as e:
            print(f"ERROR: Serial communication failed: {e}")
            return "ERROR"
    
    def set_key(self, key_hex: str) -> bool:
        """
        Program the AES key into the FPGA.
        
        Args:
            key_hex: 128-bit key as 32-character hexadecimal string.
        
        Returns:
            True if key accepted, False otherwise.
        """
        response = self._send_command(f"KEY:{key_hex.upper()}")
        return response == "READY"
    
    def set_mode(self, mode: int) -> bool:
        """
        Set AES mode (encryption or decryption).
        
        Args:
            mode: 1 for encryption, 0 for decryption.
        
        Returns:
            True if mode accepted, False otherwise.
        """
        response = self._send_command(f"MODE:{mode}")
        return response == "READY"
    
    def set_data(self, data_hex: str) -> bool:
        """
        Load plaintext or ciphertext data into FPGA.
        
        Args:
            data_hex: 128-bit data block as 32-character hexadecimal string.
        
        Returns:
            True if data accepted, False otherwise.
        """
        response = self._send_command(f"DATA:{data_hex.upper()}")
        return response == "READY"
    
    def start_operation(self) -> str:
        """
        Trigger encryption/decryption operation and retrieve result.
        
        Returns:
            Result as 32-character hexadecimal string (ciphertext or plaintext).
            
        Note:
            Operation timeout is controlled by self.operation_timeout (default 20ms).
        """
        # Poll device status until it reports READY, then start
        poll_count = 0
        max_polls = int(self.baudrate / 10) if self.baudrate else 500
        while poll_count < max_polls:
            status = self._send_command("STATUS")
            if status == "READY":
                break
            # If device does not implement STATUS, proceed after a short wait
            if status == "ERROR" or status == "UNKNOWN" or status == "":
                # give device a short time and try once more
                time.sleep(0.01)
                poll_count += 1
                continue
            time.sleep(0.01)
            poll_count += 1

        # Trigger operation
        self._send_command("START")
        time.sleep(self.operation_timeout)
        result = self.port.readline().decode().strip()
        return result
    
    def verify_encryption(self, plaintext_hex: str, key_hex: str) -> bool:
        """
        Verify AES-128 encryption against FIPS-197 reference implementation.
        
        Executes encryption on both FPGA and reference (pycryptodome), compares results.
        Per NIST FIPS-197: Validates all 10 expansion rounds + final round.
        
        Args:
            plaintext_hex: 128-bit plaintext as 32-character hexadecimal string.
            key_hex: 128-bit AES key as 32-character hexadecimal string.
        
        Returns:
            True if FPGA result matches reference, False otherwise.
        
        Updates:
            Increments self.pass_count or self.fail_count.
            Prints detailed failure diagnostics on mismatch.
        """
        self.set_key(key_hex)
        self.set_mode(1)
        self.set_data(plaintext_hex)
        fpga_result = self.start_operation()
        try:
            plaintext = binascii.unhexlify(plaintext_hex)
            key = binascii.unhexlify(key_hex)
            cipher = AES.new(key, AES.MODE_ECB)
            reference = binascii.hexlify(cipher.encrypt(plaintext)).decode().upper()
        except Exception as e:
            print(f"ERROR: Reference computation failed: {e}")
            self.fail_count += 1
            return False
        match = fpga_result.upper() == reference
        if match:
            self.pass_count += 1
            print("  PASS: Encryption")
        else:
            self.fail_count += 1
            print("  FAIL: Encryption")
            print(f"    Plaintext:  {plaintext_hex.upper()}")
            print(f"    Key:        {key_hex.upper()}")
            print(f"    Expected:   {reference}")
            print(f"    Got:        {fpga_result.upper()}")
        return match
    
    def verify_decryption(self, ciphertext_hex: str, key_hex: str) -> bool:
        """
        Verify AES-128 decryption against FIPS-197 reference implementation.
        
        Executes decryption on both FPGA and reference (pycryptodome), compares results.
        Per NIST FIPS-197: Validates all 10 inverse expansion rounds + final round.
        
        Args:
            ciphertext_hex: 128-bit ciphertext as 32-character hexadecimal string.
            key_hex: 128-bit AES key as 32-character hexadecimal string.
        
        Returns:
            True if FPGA result matches reference, False otherwise.
        
        Updates:
            Increments self.pass_count or self.fail_count.
            Prints detailed failure diagnostics on mismatch.
        """
        self.set_key(key_hex)
        self.set_mode(0)
        self.set_data(ciphertext_hex)
        fpga_result = self.start_operation()
        try:
            ciphertext = binascii.unhexlify(ciphertext_hex)
            key = binascii.unhexlify(key_hex)
            cipher = AES.new(key, AES.MODE_ECB)
            reference = binascii.hexlify(cipher.decrypt(ciphertext)).decode().upper()
        except Exception as e:
            print(f"ERROR: Reference computation failed: {e}")
            self.fail_count += 1
            return False
        match = fpga_result.upper() == reference
        if match:
            self.pass_count += 1
            print("  PASS: Decryption")
        else:
            self.fail_count += 1
            print("  FAIL: Decryption")
            print(f"    Ciphertext: {ciphertext_hex.upper()}")
            print(f"    Key:        {key_hex.upper()}")
            print(f"    Expected:   {reference}")
            print(f"    Got:        {fpga_result.upper()}")
        return match
    
    def verify_roundtrip(self, plaintext_hex: str, key_hex: str) -> bool:
        """
        Verify encrypt-decrypt round-trip consistency.
        
        Encrypts plaintext, then decrypts result, verifying recovery of original.
        This validates state preservation and cipher symmetry properties.
        
        Args:
            plaintext_hex: 128-bit plaintext as 32-character hexadecimal string.
            key_hex: 128-bit AES key as 32-character hexadecimal string.
        
        Returns:
            True if recovered plaintext matches original, False otherwise.
        
        Updates:
            Increments self.pass_count or self.fail_count.
            Prints detailed failure diagnostics on mismatch.
        """
        self.set_key(key_hex)
        self.set_mode(1)
        self.set_data(plaintext_hex)
        encrypted = self.start_operation()
        self.set_mode(0)
        self.set_data(encrypted)
        decrypted = self.start_operation()
        match = decrypted.upper() == plaintext_hex.upper()
        if match:
            self.pass_count += 1
            print("  PASS: Round-trip")
        else:
            self.fail_count += 1
            print("  FAIL: Round-trip")
            print(f"    Original:   {plaintext_hex.upper()}")
            print(f"    Encrypted:  {encrypted.upper()}")
            print(f"    Decrypted:  {decrypted.upper()}")
        return match
    
    def run_suite(self, test_vectors: List[Tuple[str, str, str]]) -> bool:
        """
        Execute comprehensive test suite on all vectors.
        
        Runs three tests per vector: encryption, decryption, and round-trip verification.
        Generates formatted summary report with pass/fail counts and success rate.
        
        Args:
            test_vectors: List of tuples (plaintext_hex, key_hex, expected_ciphertext_hex).
                Each element is a 128-bit value as 32-character hexadecimal string.
        
        Returns:
            True if all tests pass, False if any test fails.
        
        Output:
            - Live test results printed to stdout
            - Final summary with pass/fail counts and success rate percentage
            - Detailed diagnostics on each failure
        
        Standards:
            Compliant with NIST FIPS-197 AES specification.
            Uses pycryptodome library as reference implementation.
        """
        print("=" * 70)
        print("Hardware-in-the-Loop Test Suite")
        print(f"Port: {self.port_name}, Baudrate: {self.baudrate} bps")
        print(f"Total test vectors: {len(test_vectors)}")
        print(f"Tests per vector: 3 (encryption, decryption, round-trip)")
        print(f"Total tests: {len(test_vectors) * 3}")
        print("=" * 70)
        print()
        for i, (plaintext, key, expected_cipher) in enumerate(test_vectors, 1):
            print(f"Test Vector {i}/{len(test_vectors)}")
            self.verify_encryption(plaintext, key)
            self.verify_decryption(expected_cipher, key)
            self.verify_roundtrip(plaintext, key)
            print()
        total_tests = self.pass_count + self.fail_count
        success_rate = 100 * self.pass_count / total_tests if total_tests > 0 else 0
        print("=" * 70)
        print("Test Summary:")
        print(f"  Total:       {total_tests}")
        print(f"  PASS:        {self.pass_count}")
        print(f"  FAIL:        {self.fail_count}")
        print(f"  Success Rate: {success_rate:.1f}%")
        print("=" * 70)
        return self.fail_count == 0
    
    def close(self):
        """
        Close serial connection to FPGA.
        
        Should be called when testing is complete to release the port.
        Safe to call multiple times (checks if port is open).
        """
        if self.port.is_open:
            self.port.close()
            print(f"Closed connection to {self.port_name}")

def load_test_vectors(vector_path: Path) -> List[Tuple[str, str, str]]:
    """
    Load test vectors from a text file.

    The expected format is one vector per line:
        plaintext ciphertext key

    Comment lines beginning with '#' or '--' are ignored.
    """
    vectors: List[Tuple[str, str, str]] = []

    with vector_path.open("r", encoding="utf-8") as vector_file:
        for line_number, raw_line in enumerate(vector_file, 1):
            line = raw_line.strip()
            if not line or line.startswith("#") or line.startswith("--"):
                continue

            parts = line.split()
            if len(parts) != 3:
                raise ValueError(
                    f"Invalid vector format at line {line_number} in {vector_path}: expected 3 hex values"
                )

            plaintext_hex, ciphertext_hex, key_hex = (part.upper() for part in parts)

            for value_name, value in (
                ("plaintext", plaintext_hex),
                ("ciphertext", ciphertext_hex),
                ("key", key_hex),
            ):
                if len(value) != 32:
                    raise ValueError(
                        f"Invalid {value_name} length at line {line_number} in {vector_path}: expected 32 hex characters"
                    )

            vectors.append((plaintext_hex, key_hex, ciphertext_hex))

    return vectors


def main():
    parser = argparse.ArgumentParser(description="Hardware-in-the-Loop Testing for AES-128 FPGA Accelerator")
    parser.add_argument('--port', default='COM3', help='Serial port (default: COM3)')
    parser.add_argument('--baudrate', type=int, default=115200, help='Baud rate (default: 115200)')
    parser.add_argument('--timeout', type=float, default=1.0, help='Serial timeout in seconds (default: 1.0)')
    default_vectors = Path(__file__).resolve().parent.parent / "vectors" / "test_vectors.txt"
    parser.add_argument('--vectors', default=str(default_vectors), help='Path to test vector file (default: hil/vectors/test_vectors.txt)')
    args = parser.parse_args()
    tester = AESHardwareTest(port=args.port, baudrate=args.baudrate, timeout=args.timeout)
    try:
        vector_path = Path(args.vectors).expanduser().resolve()
        vectors = load_test_vectors(vector_path)
        print(f"Loaded {len(vectors)} test vectors from {vector_path}")
        success = tester.run_suite(vectors)
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\nTest interrupted by user")
        sys.exit(1)
    except (OSError, ValueError) as e:
        print(f"ERROR: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: Unexpected exception: {e}")
        sys.exit(1)
    finally:
        tester.close()


if __name__ == "__main__":
    main()
