#!/usr/bin/env python3
"""
ldr_monitor.py — LDR Sensor Monitoring and Decryption Tool
Logs autonomous LDR samples from aes_ldr_top + XADC, decrypts results, saves to CSV.

Hardware Platform:
    - Basys3 FPGA with aes_ldr_top design
    - XADC channel 5 (Pmod JA Pin 1) samples LDR every 5 seconds
    - AES-128 encrypts each sample autonomously
    - Results transmitted via UART at 115,200 bps

Protocol:
    The aes_ldr_top firmware autonomously:
    1. Every 5 seconds, reads the LDR via XADC
    2. Pads the 12-bit ADC value to 128-bit plaintext: [000...000|12-bit ADC]
    3. Encrypts the padded value using pre-loaded AES key
    4. Transmits encrypted result via UART (32 hex characters + newline)

Python Tool:
    - Connects to FPGA UART and listens for encrypted samples
    - Logs raw ADC values (decoded from encrypted results via decryption)
    - Records timestamps and sample count
    - Saves data to CSV for analysis

Usage:
    # Initial setup: load AES key into FPGA once
    python ldr_monitor.py --port COM6 --baudrate 115200 --init-key 000102030405060708090a0b0c0d0e0f

    # Monitor for 5 minutes (default), save to results_20260515_150000.csv
    python ldr_monitor.py --port COM6 --duration 300

    # Monitor indefinitely (Ctrl+C to stop)
    python ldr_monitor.py --port COM6 --duration 0

    # Manual key per run (non-interactive)
    python ldr_monitor.py --port COM6 --key 000102030405060708090a0b0c0d0e0f --duration 300

Requirements:
    pip install pycryptodome pyserial
"""

import serial
import time
import sys
import argparse
import csv
from pathlib import Path
from typing import Optional, Tuple
from datetime import datetime
from Crypto.Cipher import AES
import binascii


class LDRMonitor:
    """Monitor LDR samples and decrypt results from FPGA"""

    def __init__(self, port: str = 'COM6', baudrate: int = 115200, timeout: float = 1.0, verbose: bool = False):
        """
        Initialize UART connection to FPGA.

        Args:
            port: Serial port (e.g., 'COM6' on Windows, '/dev/ttyUSB0' on Linux)
            baudrate: UART baud rate (default: 115200 bps)
            timeout: UART read timeout in seconds
            verbose: Enable detailed logging
        """
        try:
            self.port = serial.Serial(port, baudrate, timeout=timeout)
            self.port_name = port
            self.verbose = verbose
            self.response_timeout = 0.1  # 100 ms for 32-hex + newline
            
            if self.verbose:
                print(f"[INIT] Connected to {port} at {baudrate} bps")
        except serial.SerialException as e:
            print(f"ERROR: Failed to connect to {port}: {e}")
            sys.exit(1)

        self.sample_count = 0
        self.start_time = datetime.now()

    def send_command(self, cmd: str) -> Optional[str]:
        """
        Send command to FPGA and wait for response (if expected).

        Args:
            cmd: Command string (e.g., 'K:' for key load, 'M:' for mode)

        Returns:
            Response string (32-hex) or None if no response expected
        """
        try:
            self.port.write(cmd.encode() + b'\n')
            time.sleep(0.01)

            if cmd.startswith('S'):  # Start/execute command expects response
                response = self.port.read(33)  # 32 hex chars + newline
                if len(response) >= 32:
                    return response[:32].decode('ascii', errors='replace')
            return None
        except Exception as e:
            if self.verbose:
                print(f"[ERROR] Serial communication failed: {e}")
            return None

    def load_key(self, key_hex: str) -> bool:
        """
        Load AES key into FPGA.

        Args:
            key_hex: 32-character hexadecimal string (128-bit key)

        Returns:
            True if successful, False otherwise
        """
        if len(key_hex) != 32:
            print(f"ERROR: Key must be 32 hex characters, got {len(key_hex)}")
            return False

        try:
            binascii.unhexlify(key_hex)
        except ValueError:
            print(f"ERROR: Invalid hexadecimal key: {key_hex}")
            return False

        cmd = f"K:{key_hex}"
        try:
            self.port.write(cmd.encode() + b'\n')
            time.sleep(0.1)
            if self.verbose:
                print(f"[KEY] Loaded key: {key_hex}")
            return True
        except Exception as e:
            print(f"ERROR: Failed to load key: {e}")
            return False

    def decrypt_adc_from_ciphertext(self, ciphertext_hex: str, key_hex: str) -> Optional[int]:
        """
        Decrypt the ciphertext to recover the original ADC value.

        The FPGA encrypts: [000...000|12-bit ADC] (plaintext is 128 bits)
        We decrypt to get the original plaintext and extract the ADC value.

        Args:
            ciphertext_hex: 32-character hex string (encrypted 128-bit block)
            key_hex: 32-character hex string (128-bit AES key)

        Returns:
            12-bit ADC value as integer, or None if decryption fails
        """
        try:
            key_bytes = binascii.unhexlify(key_hex)
            ciphertext_bytes = binascii.unhexlify(ciphertext_hex)

            cipher = AES.new(key_bytes, AES.MODE_ECB)
            plaintext_bytes = cipher.decrypt(ciphertext_bytes)

            # Plaintext format: [000...000|12-bit ADC]
            # Last 2 bytes contain the ADC value (lower 12 bits)
            adc_value = int.from_bytes(plaintext_bytes[-2:], byteorder='big') & 0xFFF

            return adc_value
        except Exception as e:
            if self.verbose:
                print(f"[ERROR] Decryption failed: {e}")
            return None

    def monitor(self, duration: int = 300, key_hex: Optional[str] = None, csv_file: Optional[str] = None):
        """
        Monitor FPGA UART for encrypted LDR samples, decrypt, and log to CSV.

        Args:
            duration: Monitoring duration in seconds (0 = indefinite)
            key_hex: 32-character hex AES key (if None, user is prompted)
            csv_file: Output CSV filename (auto-generated if None)
        """
        # Get key
        if key_hex is None:
            key_hex = input("Enter 128-bit AES key (32 hex chars): ").strip()
        
        if not self.load_key(key_hex):
            return

        # Set up CSV file
        if csv_file is None:
            timestamp_str = self.start_time.strftime("%Y%m%d_%H%M%S")
            csv_file = f"ldr_samples_{timestamp_str}.csv"

        results_dir = Path("results")
        results_dir.mkdir(exist_ok=True)
        csv_path = results_dir / csv_file

        # Write CSV header
        try:
            with open(csv_path, 'w', newline='') as f:
                writer = csv.writer(f)
                writer.writerow(['Timestamp', 'Sample #', 'Ciphertext (hex)', 'ADC Value (raw)', 'ADC Voltage (V)'])
                if self.verbose:
                    print(f"[CSV] Created {csv_path}")
        except Exception as e:
            print(f"ERROR: Failed to create CSV file: {e}")
            return

        # Monitoring loop
        print(f"\n[MONITOR] Starting to listen for LDR samples (duration: {duration}s, 0=indefinite)")
        print(f"[MONITOR] Key: {key_hex}")
        print(f"[MONITOR] CSV: {csv_path}")
        print(f"[MONITOR] Press Ctrl+C to stop\n")

        end_time = time.time() + duration if duration > 0 else None
        samples_logged = 0

        try:
            while True:
                if end_time is not None and time.time() > end_time:
                    print(f"\n[MONITOR] Duration limit reached ({duration}s)")
                    break

                # Read from UART (wait for encrypted sample)
                try:
                    line = self.port.readline().decode('ascii', errors='replace').strip()

                    if len(line) == 32 and all(c in '0123456789abcdefABCDEF' for c in line):
                        # Valid encrypted sample received
                        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
                        self.sample_count += 1

                        # Decrypt to get ADC value
                        adc_value = self.decrypt_adc_from_ciphertext(line, key_hex)

                        if adc_value is not None:
                            # Convert ADC to voltage (0-4095 maps to 0-1V for XADC)
                            # Pmod JA uses voltage divider, so voltage range depends on LDR circuit
                            adc_voltage = (adc_value / 4095.0) * 1.0  # 1V full scale for XADC
                            
                            # Log to CSV
                            try:
                                with open(csv_path, 'a', newline='') as f:
                                    writer = csv.writer(f)
                                    writer.writerow([timestamp, self.sample_count, line, adc_value, f"{adc_voltage:.3f}"])
                                samples_logged += 1

                                if self.verbose or samples_logged % 5 == 0:
                                    print(f"[{timestamp}] Sample {self.sample_count}: ADC={adc_value:4d} "
                                          f"({adc_voltage:.3f}V) {line}")
                            except Exception as e:
                                print(f"[ERROR] Failed to write to CSV: {e}")
                        else:
                            if self.verbose:
                                print(f"[{timestamp}] Sample {self.sample_count}: Decryption failed (ciphertext: {line})")

                except UnicodeDecodeError:
                    pass  # Skip non-UTF8 noise
                except KeyboardInterrupt:
                    print("\n\n[MONITOR] Stopped by user (Ctrl+C)")
                    break

        except KeyboardInterrupt:
            print("\n[MONITOR] Stopped by user (Ctrl+C)")

        # Summary
        elapsed = (datetime.now() - self.start_time).total_seconds()
        print(f"\n[SUMMARY] Monitoring complete:")
        print(f"  Duration: {elapsed:.1f}s")
        print(f"  Samples logged: {samples_logged}")
        print(f"  CSV file: {csv_path}")
        if samples_logged > 0:
            print(f"  Sample rate: {samples_logged / elapsed:.2f} Hz")


def main():
    parser = argparse.ArgumentParser(
        description="Monitor LDR samples from FPGA, decrypt results, and save to CSV"
    )
    parser.add_argument('--port', default='COM6', help='Serial port (default: COM6)')
    parser.add_argument('--baudrate', type=int, default=115200, help='Baud rate (default: 115200)')
    parser.add_argument('--duration', type=int, default=300, help='Monitor duration in seconds (default: 300, 0=indefinite)')
    parser.add_argument('--key', help='128-bit AES key (32 hex chars, will prompt if not provided)')
    parser.add_argument('--init-key', help='Load key but do not monitor (for initialization)')
    parser.add_argument('--csv', help='Output CSV filename (auto-generated if not provided)')
    parser.add_argument('--verbose', '-v', action='store_true', help='Enable verbose output')

    args = parser.parse_args()

    monitor = LDRMonitor(port=args.port, baudrate=args.baudrate, verbose=args.verbose)

    if args.init_key:
        # Just load key and exit
        if monitor.load_key(args.init_key):
            print(f"[SUCCESS] Key loaded successfully. FPGA is ready to sample.")
        else:
            print(f"[FAILED] Could not load key.")
        sys.exit(0)

    # Start monitoring
    monitor.monitor(duration=args.duration, key_hex=args.key, csv_file=args.csv)


if __name__ == '__main__':
    main()
