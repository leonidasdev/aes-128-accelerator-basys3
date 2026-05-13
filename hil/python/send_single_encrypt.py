#!/usr/bin/env python3
"""
send_single_encrypt.py — Quick encryption test with FIPS-197 Vector 1

Usage:
    python send_single_encrypt.py [--port COM6] [--key KEY_HEX] [--plaintext DATA_HEX]

Example:
    python send_single_encrypt.py --port COM6
    python send_single_encrypt.py --port COM6 --plaintext 6bc1bee22e409f96e93d7e117393172a
"""

import argparse
import sys
import time
import serial


def open_serial(port, baudrate, timeout):
    try:
        return serial.Serial(port, baudrate, timeout=timeout)
    except Exception as e:
        print('ERROR: open serial', e)
        return None


def write_command(serial_port, cmd):
    try:
        print('SEND:', repr(cmd))
        serial_port.write(cmd.encode('ascii'))
        return True
    except Exception as e:
        print('ERROR during write:', e)
        return False


def read_result_line(serial_port, wait_limit_s):
    try:
        deadline = time.monotonic() + wait_limit_s
        response = b''
        while time.monotonic() < deadline:
            chunk = serial_port.read(1)
            if chunk:
                response += chunk
                if chunk == b'\n':
                    break
        print('RECV:', response)
        return response
    except Exception as e:
        print('ERROR during read:', e)
        return b''


def main():
    parser = argparse.ArgumentParser(
        description='Send single ENCRYPTION test to FPGA',
        epilog='Example: python send_single_encrypt.py --port COM6'
    )
    parser.add_argument('--port', default='COM6', help='Serial port (default: COM6)')
    parser.add_argument('--baudrate', type=int, default=115200, help='UART baud rate')
    parser.add_argument('--key', default='000102030405060708090A0B0C0D0E0F',
                        help='128-bit key (32 hex chars, default: FIPS-197 Vector 1 key)')
    parser.add_argument('--plaintext', default='00112233445566778899AABBCCDDEEFF',
                        help='128-bit plaintext (32 hex chars, default: FIPS-197 Vector 1 plaintext)')
    parser.add_argument('--expected', default='69C4E0D86A7B0430D8CDB78070B4C55A',
                        help='Expected ciphertext for verification')
    
    args = parser.parse_args()
    
    print("="*70)
    print("AES-128 ENCRYPTION TEST (Single Vector)")
    print("="*70)
    print(f"Key:       {args.key}")
    print(f"Plaintext: {args.plaintext}")
    print(f"Expected:  {args.expected}")
    print("="*70 + "\n")
    
    serial_port = open_serial(args.port, args.baudrate, timeout=0.5)
    if serial_port is None:
        sys.exit(1)
    
    try:
        time.sleep(0.7)  # Wait for board to stabilize
        serial_port.reset_input_buffer()
        serial_port.reset_output_buffer()
        
        # Send key
        write_command(serial_port, f'K:{args.key}\n')
        time.sleep(0.1)
        
        # Set mode to encrypt (1)
        write_command(serial_port, 'M:1\n')
        time.sleep(0.1)
        
        # Send plaintext
        write_command(serial_port, f'D:{args.plaintext}\n')
        time.sleep(0.1)
        
        # Execute
        write_command(serial_port, 'S\n')
        time.sleep(1.0)
        
        result = read_result_line(serial_port, 3.0).decode('ascii', errors='ignore').strip()
        
        print("\n" + "="*70)
        if result.upper() == args.expected.upper():
            print("✓ PASS: Ciphertext matches expected value")
        else:
            print("✗ FAIL: Ciphertext mismatch")
            print(f"  Expected: {args.expected}")
            print(f"  Got:      {result}")
        print("="*70)
        
    finally:
        serial_port.close()


if __name__ == '__main__':
    main()
