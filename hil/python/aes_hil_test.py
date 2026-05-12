#!/usr/bin/env python3
"""
aes_hil_test.py — Hardware-in-the-Loop Testing Framework
Validates FPGA AES implementation against NIST FIPS-197 reference implementation.

Protocol:
    Commands (host → FPGA):
        K:<32-hex-chars>\n    Load 128-bit key
        M:<0|1>\n              Set mode (1=encrypt, 0=decrypt)
        D:<32-hex-chars>\n     Load 128-bit plaintext/ciphertext
        S\n                    Execute and return 32-hex-char result

    Responses (FPGA → host):
        <32-hex-chars>\n       For K, D commands: echoes input
                               For M command: echoes mode (0 or 1)
                               For S command: returns result

Byte Order:
    Big-endian (network byte order); MSB transmitted first
    Example: "000102030405060708090A0B0C0D0E0F"
             → byte[15]=0x00, byte[14]=0x01, ..., byte[0]=0x0F

Reference:
    NIST FIPS-197 AES specification validated via pycryptodome

Usage:
    python aes_hil_test.py --port COM3 --baudrate 115200 [--timeout 1.0] [--verbose]

Requirements:
    pip install pycryptodome pyserial
"""

import serial
import time
import sys
import argparse
from pathlib import Path
from typing import List, Tuple, Optional
from Crypto.Cipher import AES
import binascii


class AESHardwareTest:
    """Hardware-in-the-loop test controller for AES FPGA accelerator"""
    
    def __init__(self, port: str = 'COM3', baudrate: int = 115200, timeout: float = 1.0, verbose: bool = False):
        """
        Initialize UART connection to FPGA.
        
        Args:
            port: Serial port (e.g., 'COM3' on Windows, '/dev/ttyUSB0' on Linux)
            baudrate: UART baud rate (default: 115200 bps)
            timeout: UART read timeout in seconds (default: 1.0)
            verbose: Enable detailed logging (default: False)
        
        Raises:
            SystemExit: If connection fails
        """
        try:
            self.port = serial.Serial(port, baudrate, timeout=timeout)
            self.baudrate = baudrate
            self.port_name = port
            self.verbose = verbose
            
            # Timing: at 115,200 bps, ~87 µs per 10-bit frame
            # For 33 frames (32 hex chars + newline): ~2.9 ms
            # Add margin for processing: 100 ms recommended timeout
            self.response_timeout = 0.1  # 100 ms
            
            if self.verbose:
                print(f"[INIT] Connected to {port} at {baudrate} bps")
                print(f"[INIT] Response timeout: {self.response_timeout*1000:.1f} ms")
        except serial.SerialException as e:
            print(f"ERROR: Failed to connect to {port}: {e}")
            sys.exit(1)
        
        self.pass_count = 0
        self.fail_count = 0
    
    def _send_command(self, cmd: str) -> Optional[str]:
        """
        Send a command to FPGA and retrieve response.
        
        Args:
            cmd: Command string (e.g., "K:000102030405060708090A0B0C0D0E0F")
                 Without newline; newline added automatically
        
        Returns:
            Response string (stripped of whitespace), or None on error/timeout
        """
        try:
            # Clear any stale data in RX buffer
            self.port.reset_input_buffer()
            
            # Send command with newline terminator
            if self.verbose:
                print(f"  [TX] {cmd}")
            self.port.write((cmd + '\n').encode('ascii'))
            
            # Wait for response with timeout
            start_time = time.time()
            response_bytes = b''
            
            while (time.time() - start_time) < self.response_timeout:
                if self.port.in_waiting > 0:
                    byte = self.port.read(1)
                    if byte == b'\n':
                        response_str = response_bytes.decode('ascii').strip()
                        if self.verbose:
                            print(f"  [RX] {response_str}")
                        return response_str
                    response_bytes += byte
            
            # Timeout
            print(f"  [ERROR] Timeout waiting for response to: {cmd}")
            return None
        
        except serial.SerialException as e:
            print(f"  [ERROR] Serial communication failed: {e}")
            return None
        except Exception as e:
            print(f"  [ERROR] Unexpected error: {e}")
            return None
    
    def _validate_hex_response(self, response: str, expected_length: int = 32) -> bool:
        """
        Validate that response is valid 128-bit hex string.
        
        Args:
            response: Response string to validate
            expected_length: Expected hex character count (default: 32 for 128-bit)
        
        Returns:
            True if valid hex string of correct length, False otherwise
        """
        if not response:
            return False
        if len(response) != expected_length:
            print(f"    Invalid response length: expected {expected_length}, got {len(response)}")
            return False
        try:
            int(response, 16)  # Verify all characters are valid hex
            return True
        except ValueError:
            print(f"    Invalid hex characters in response: {response}")
            return False
    
    def set_key(self, key_hex: str) -> bool:
        """
        Load 128-bit AES key into FPGA.
        
        Args:
            key_hex: 128-bit key as 32-character hexadecimal string (big-endian)
        
        Returns:
            True if key accepted and echoed correctly, False on error
        """
        if not self._validate_hex_response(key_hex, 32):
            print(f"  [ERROR] Invalid key format: {key_hex}")
            return False
        
        key_hex = key_hex.upper()
        response = self._send_command(f"K:{key_hex}")
        
        if response is None:
            return False
        
        if response == key_hex:
            if self.verbose:
                print(f"  [KEY] Loaded: {key_hex}")
            return True
        else:
            print(f"  [ERROR] Key echo mismatch")
            print(f"    Sent:     {key_hex}")
            print(f"    Received: {response}")
            return False
    
    def set_mode(self, mode: int) -> bool:
        """
        Set encryption or decryption mode.
        
        Args:
            mode: 1 for encryption (forward), 0 for decryption (inverse)
        
        Returns:
            True if mode accepted and echoed correctly, False on error
        """
        if mode not in (0, 1):
            print(f"  [ERROR] Invalid mode: {mode} (must be 0 or 1)")
            return False
        
        mode_str = str(mode)
        response = self._send_command(f"M:{mode_str}")
        
        if response is None:
            return False
        
        if response == mode_str:
            mode_name = "Encryption" if mode == 1 else "Decryption"
            if self.verbose:
                print(f"  [MODE] Set to: {mode_name} (mode={mode})")
            return True
        else:
            print(f"  [ERROR] Mode echo mismatch")
            print(f"    Sent:     {mode_str}")
            print(f"    Received: {response}")
            return False
    
    def set_data(self, data_hex: str) -> bool:
        """
        Load 128-bit plaintext/ciphertext data into FPGA.
        
        Args:
            data_hex: 128-bit data block as 32-character hexadecimal string (big-endian)
        
        Returns:
            True if data accepted and echoed correctly, False on error
        """
        if not self._validate_hex_response(data_hex, 32):
            print(f"  [ERROR] Invalid data format: {data_hex}")
            return False
        
        data_hex = data_hex.upper()
        response = self._send_command(f"D:{data_hex}")
        
        if response is None:
            return False
        
        if response == data_hex:
            if self.verbose:
                print(f"  [DATA] Loaded: {data_hex}")
            return True
        else:
            print(f"  [ERROR] Data echo mismatch")
            print(f"    Sent:     {data_hex}")
            print(f"    Received: {response}")
            return False
    
    def execute(self) -> Optional[str]:
        """
        Trigger AES operation and retrieve result.
        
        Preconditions:
            - Key must have been loaded via set_key()
            - Mode must have been set via set_mode()
            - Data must have been loaded via set_data()
        
        Returns:
            32-character hexadecimal result string (uppercase), or None on error
        
        Notes:
            Computation latency: ~15 FPGA clock cycles + UART overhead (~2.9 ms total)
        """
        response = self._send_command("S")
        
        if response is None:
            print(f"  [ERROR] No response to START command")
            return None
        
        if self._validate_hex_response(response, 32):
            if self.verbose:
                print(f"  [RESULT] {response}")
            return response.upper()
        else:
            print(f"  [ERROR] Invalid result format: {response}")
            return None
    
    def verify_encryption(self, plaintext_hex: str, key_hex: str, description: str = "") -> bool:
        """
        Verify AES-128 encryption against FIPS-197 reference.
        
        Performs encryption on both FPGA and reference implementation (pycryptodome),
        compares results byte-by-byte.
        
        Args:
            plaintext_hex: 128-bit plaintext as 32-character hex string (big-endian)
            key_hex: 128-bit key as 32-character hex string (big-endian)
            description: Optional test description for logging
        
        Returns:
            True if FPGA result matches reference, False on mismatch or error
        
        Side Effects:
            Increments self.pass_count or self.fail_count
            Prints detailed mismatch diagnostics on failure
        """
        if not self.set_key(key_hex):
            self.fail_count += 1
            return False
        
        if not self.set_mode(1):  # 1 = encryption
            self.fail_count += 1
            return False
        
        if not self.set_data(plaintext_hex):
            self.fail_count += 1
            return False
        
        fpga_result = self.execute()
        if fpga_result is None:
            self.fail_count += 1
            return False
        
        # Compute reference using pycryptodome
        try:
            plaintext = binascii.unhexlify(plaintext_hex)
            key = binascii.unhexlify(key_hex)
            cipher = AES.new(key, AES.MODE_ECB)
            reference = binascii.hexlify(cipher.encrypt(plaintext)).decode().upper()
        except Exception as e:
            print(f"  [ERROR] Reference computation failed: {e}")
            self.fail_count += 1
            return False
        
        # Compare results
        match = (fpga_result == reference)
        if match:
            self.pass_count += 1
            status = "✓ PASS"
        else:
            self.fail_count += 1
            status = "✗ FAIL"
        
        print(f"    {status} Encryption{' (' + description + ')' if description else ''}")
        
        if not match:
            print(f"      Plaintext: {plaintext_hex.upper()}")
            print(f"      Key:       {key_hex.upper()}")
            print(f"      Expected:  {reference}")
            print(f"      Got:       {fpga_result}")
        
        return match
    
    def verify_decryption(self, ciphertext_hex: str, key_hex: str, description: str = "") -> bool:
        """
        Verify AES-128 decryption against FIPS-197 reference.
        
        Performs decryption on both FPGA and reference implementation (pycryptodome),
        compares results byte-by-byte.
        
        Args:
            ciphertext_hex: 128-bit ciphertext as 32-character hex string (big-endian)
            key_hex: 128-bit key as 32-character hex string (big-endian)
            description: Optional test description for logging
        
        Returns:
            True if FPGA result matches reference, False on mismatch or error
        
        Side Effects:
            Increments self.pass_count or self.fail_count
            Prints detailed mismatch diagnostics on failure
        """
        if not self.set_key(key_hex):
            self.fail_count += 1
            return False
        
        if not self.set_mode(0):  # 0 = decryption
            self.fail_count += 1
            return False
        
        if not self.set_data(ciphertext_hex):
            self.fail_count += 1
            return False
        
        fpga_result = self.execute()
        if fpga_result is None:
            self.fail_count += 1
            return False
        
        # Compute reference using pycryptodome
        try:
            ciphertext = binascii.unhexlify(ciphertext_hex)
            key = binascii.unhexlify(key_hex)
            cipher = AES.new(key, AES.MODE_ECB)
            reference = binascii.hexlify(cipher.decrypt(ciphertext)).decode().upper()
        except Exception as e:
            print(f"  [ERROR] Reference computation failed: {e}")
            self.fail_count += 1
            return False
        
        # Compare results
        match = (fpga_result == reference)
        if match:
            self.pass_count += 1
            status = "✓ PASS"
        else:
            self.fail_count += 1
            status = "✗ FAIL"
        
        print(f"    {status} Decryption{' (' + description + ')' if description else ''}")
        
        if not match:
            print(f"      Ciphertext: {ciphertext_hex.upper()}")
            print(f"      Key:        {key_hex.upper()}")
            print(f"      Expected:   {reference}")
            print(f"      Got:        {fpga_result}")
        
        return match
    
    def verify_round_trip(self, plaintext_hex: str, key_hex: str, description: str = "") -> bool:
        """
        Verify encrypt-then-decrypt round-trip recovery.
        
        Encrypts plaintext and then decrypts result; verifies recovery of original plaintext.
        
        Args:
            plaintext_hex: 128-bit plaintext as 32-character hex string (big-endian)
            key_hex: 128-bit key as 32-character hex string (big-endian)
            description: Optional test description for logging
        
        Returns:
            True if decrypted result matches original plaintext, False on mismatch or error
        
        Side Effects:
            Increments self.pass_count or self.fail_count
            Prints detailed mismatch diagnostics on failure
        """
        # Encrypt
        if not self.set_key(key_hex):
            self.fail_count += 1
            return False
        
        if not self.set_mode(1):  # 1 = encryption
            self.fail_count += 1
            return False
        
        if not self.set_data(plaintext_hex):
            self.fail_count += 1
            return False
        
        ciphertext = self.execute()
        if ciphertext is None:
            self.fail_count += 1
            return False
        
        # Decrypt
        if not self.set_mode(0):  # 0 = decryption
            self.fail_count += 1
            return False
        
        if not self.set_data(ciphertext):
            self.fail_count += 1
            return False
        
        recovered = self.execute()
        if recovered is None:
            self.fail_count += 1
            return False
        
        # Compare
        match = (recovered == plaintext_hex.upper())
        if match:
            self.pass_count += 1
            status = "✓ PASS"
        else:
            self.fail_count += 1
            status = "✗ FAIL"
        
        print(f"    {status} Round-trip{' (' + description + ')' if description else ''}")
        
        if not match:
            print(f"      Original:  {plaintext_hex.upper()}")
            print(f"      Key:       {key_hex.upper()}")
            print(f"      Recovered: {recovered}")
        
        return match
    
    def print_summary(self):
        """Print test summary and exit with appropriate code."""
        total = self.pass_count + self.fail_count
        success_rate = (self.pass_count / total * 100) if total > 0 else 0
        
        print("\n" + "="*70)
        print("Test Summary")
        print("="*70)
        print(f"  Total:  {total}")
        print(f"  Pass:   {self.pass_count}")
        print(f"  Fail:   {self.fail_count}")
        print(f"  Success Rate: {success_rate:.1f}%")
        print("="*70 + "\n")
        
        if self.fail_count == 0:
            print("✓ All tests passed!")
            return 0
        else:
            print(f"✗ {self.fail_count} test(s) failed")
            return 1


def load_test_vectors(filepath: Path) -> List[Tuple[str, str, str]]:
    """
    Load test vectors from file.
    
    Format (one per line):
        plaintext ciphertext key
        (each as 32-character hexadecimal)
    
    Args:
        filepath: Path to test vector file
    
    Returns:
        List of (plaintext, ciphertext, key) tuples
    """
    vectors = []
    try:
        with open(filepath, 'r') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                
                # Skip empty lines and comments
                if not line or line.startswith('#'):
                    continue
                
                parts = line.split()
                if len(parts) != 3:
                    print(f"Warning: Line {line_num} has {len(parts)} fields, expected 3")
                    continue
                
                plaintext, ciphertext, key = parts
                
                # Validate format
                if not all(len(v) == 32 for v in [plaintext, ciphertext, key]):
                    print(f"Warning: Line {line_num} has invalid field length")
                    continue
                
                try:
                    int(plaintext, 16)
                    int(ciphertext, 16)
                    int(key, 16)
                except ValueError:
                    print(f"Warning: Line {line_num} has non-hex characters")
                    continue
                
                vectors.append((plaintext.upper(), ciphertext.upper(), key.upper()))
        
        return vectors
    except FileNotFoundError:
        print(f"ERROR: Test vector file not found: {filepath}")
        return []
    except Exception as e:
        print(f"ERROR: Failed to load test vectors: {e}")
        return []


def main():
    """Main test harness."""
    parser = argparse.ArgumentParser(
        description="AES-128 FPGA Hardware-in-the-Loop Test",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python aes_hil_test.py --port COM3
  python aes_hil_test.py --port COM3 --baudrate 115200 --verbose
  python aes_hil_test.py --port COM3 --vector-file test_vectors.txt
        """
    )
    
    parser.add_argument('--port', default='COM3', help='Serial port (default: COM3)')
    parser.add_argument('--baudrate', type=int, default=115200, help='Baud rate (default: 115200)')
    parser.add_argument('--timeout', type=float, default=1.0, help='Serial read timeout in seconds (default: 1.0)')
    parser.add_argument('--vector-file', default=None, help='Path to test vector file (default: hil/vectors/test_vectors.txt)')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose logging')
    
    args = parser.parse_args()
    
    print("="*70)
    print("AES-128 FPGA Hardware-in-the-Loop Test Suite")
    print("="*70)
    print(f"Port: {args.port}, Baudrate: {args.baudrate} bps, Timeout: {args.timeout} s")
    print("="*70 + "\n")
    
    # Initialize hardware interface
    tester = AESHardwareTest(args.port, args.baudrate, timeout=args.timeout, verbose=args.verbose)
    
    # Determine vector file path
    if args.vector_file:
        vector_file = Path(args.vector_file)
    else:
        # Default to hil/vectors/test_vectors.txt relative to script location
        # Script is in hil/python/, so go up one level to hil/, then to vectors/
        script_dir = Path(__file__).parent
        vector_file = script_dir.parent / "vectors" / "test_vectors.txt"
    
    # Load test vectors
    vectors = load_test_vectors(vector_file)
    if not vectors:
        print(f"ERROR: No test vectors loaded from {vector_file}")
        return 1
    
    print(f"Loaded {len(vectors)} test vectors from {vector_file}\n")
    
    # Run tests
    for idx, (plaintext, ciphertext, key) in enumerate(vectors, 1):
        print(f"Test Vector {idx}/{len(vectors)}")
        
        # Three tests per vector: encryption, decryption, round-trip
        tester.verify_encryption(plaintext, key, f"vector {idx}")
        tester.verify_decryption(ciphertext, key, f"vector {idx}")
        tester.verify_round_trip(plaintext, key, f"vector {idx}")
        
        print()
    
    # Print summary and exit
    exit_code = tester.print_summary()
    
    try:
        tester.port.close()
    except:
        pass
    
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
