"""
Mock FPGA Controller for AES Hardware-in-the-Loop Testing

Simulates the Basys 3 AES FPGA without requiring actual hardware.
Implements the same serial protocol as the real FPGA for unit testing.

This module allows testing the Python HIL framework independently:
- Command parsing and validation
- Response handling and error recovery
- Timeout behavior
- End-to-end test workflows

Usage:
    from mock_fpga_controller import MockFPGAController
    
    # Create mock FPGA instance
    mock = MockFPGAController(verbose=True)
    
    # Use as a drop-in replacement for serial port
    mock.write(b'K:000102030405060708090A0B0C0D0E0F\n')
    response = mock.read(100)  # Returns b'000102030405060708090A0B0C0D0E0F'
    
    # Inject faults for error testing
    mock.inject_timeout()       # Next read() will timeout
    mock.inject_malformed()     # Next read() returns garbage
    mock.inject_disconnect()    # Next read() simulates port close

"""

import binascii
from typing import Optional
from Crypto.Cipher import AES as CryptoAES
import time


class MockFPGAController:
    """
    Mock FPGA controller that simulates the Basys 3 AES accelerator.
    
    Implements the same ASCII command-response protocol as the real FPGA:
    - K: <32-hex> → Load key (echo response)
    - M: <0 or 1> → Set mode (echo response)
    - D: <32-hex> → Load data (echo response)
    - S → Execute AES (returns 32-hex result)
    
    Attributes:
        verbose: Print debug messages for each command/response
        key: Current 128-bit master key
        mode: Current mode (1=encrypt, 0=decrypt)
        data: Current plaintext/ciphertext
        timeout_enabled: If True, next read() will timeout
        malformed_enabled: If True, next read() returns garbage
        disconnect_enabled: If True, next read() simulates port close
    """
    
    def __init__(self, verbose: bool = False, latency_ms: float = 0.0):
        """
        Initialize mock FPGA controller.
        
        Args:
            verbose: Print debug messages
            latency_ms: Simulate UART latency (default 0, no latency)
        """
        self.verbose = verbose
        self.latency_ms = latency_ms
        
        # FPGA state
        self.key: Optional[bytes] = None  # 16 bytes
        self.mode: Optional[int] = None  # 1 (encrypt) or 0 (decrypt)
        self.data: Optional[bytes] = None  # 16 bytes
        
        # Fault injection
        self._timeout_next = False
        self._malformed_next = False
        self._disconnect_next = False
        
        # Command buffer
        self._buffer = b''
        
        # Statistics
        self.commands_received = 0
        self.responses_sent = 0
        
        if self.verbose:
            print("[MockFPGA] Initialized")
    
    def write(self, data: bytes) -> int:
        """
        Write command to mock FPGA (simulates serial port write).
        
        Args:
            data: Command bytes (e.g., b'K:DEADBEEF...\n')
        
        Returns:
            Number of bytes written (always len(data) for mock)
        """
        self._buffer += data
        
        if self.verbose:
            print(f"[MockFPGA] write: {data[:50]}")
        
        return len(data)
    
    def read(self, size: int) -> bytes:
        """
        Read response from mock FPGA (simulates serial port read).
        
        Parses buffered command and returns appropriate response.
        
        Args:
            size: Max bytes to read (ignored, returns full response)
        
        Returns:
            Response bytes (hex string + newline) or empty if no complete command
        
        Raises:
            TimeoutError: If timeout fault is injected
            IOError: If disconnect fault is injected
        """
        # Apply latency
        if self.latency_ms > 0:
            time.sleep(self.latency_ms / 1000.0)
        
        # Check for disconnect fault
        if self._disconnect_next:
            self._disconnect_next = False
            raise IOError("Port is closed or disconnected")
        
        # Check for timeout fault
        if self._timeout_next:
            self._timeout_next = False
            return b''  # Simulate timeout (no response)
        
        # Check for malformed fault
        if self._malformed_next:
            self._malformed_next = False
            if self.verbose:
                print("[MockFPGA] Injecting malformed response")
            return b'\x00\x01\x02\x03\n'  # Garbage
        
        # Look for newline in buffer
        if b'\n' not in self._buffer:
            return b''  # No complete command yet
        
        # Extract command line
        cmd_line, self._buffer = self._buffer.split(b'\n', 1)
        self.commands_received += 1
        
        # Parse command
        response = self._process_command(cmd_line)
        self.responses_sent += 1
        
        if self.verbose:
            print(f"[MockFPGA] read: {response[:50]}")
        
        return response
    
    def reset_input_buffer(self) -> None:
        """Reset input buffer (simulates serial port flush)."""
        self._buffer = b''
        if self.verbose:
            print("[MockFPGA] reset_input_buffer")
    
    def close(self) -> None:
        """Close connection (no-op for mock)."""
        if self.verbose:
            print("[MockFPGA] close")
    
    def _process_command(self, cmd_line: bytes) -> bytes:
        """
        Process a single command line and return response.
        
        Args:
            cmd_line: Command without newline (e.g., b'K:DEADBEEF...')
        
        Returns:
            Response with newline (e.g., b'DEADBEEF...\n')
        """
        cmd_str = cmd_line.decode('ascii', errors='ignore')
        
        if self.verbose:
            print(f"[MockFPGA] Processing: {cmd_str[:50]}")
        
        # Command: K (Key load)
        if cmd_str.startswith('K:'):
            hex_str = cmd_str[2:].strip()
            if self._validate_hex(hex_str, 32):
                self.key = binascii.unhexlify(hex_str)
                response = hex_str.encode('ascii')
                if self.verbose:
                    print(f"[MockFPGA] Key loaded: {hex_str[:16]}...")
                return response + b'\n'
            else:
                if self.verbose:
                    print("[MockFPGA] Invalid key format")
                return b''  # Malformed, no response
        
        # Command: M (Mode set)
        elif cmd_str.startswith('M:'):
            mode_str = cmd_str[2:].strip()
            if mode_str in ('0', '1'):
                self.mode = int(mode_str)
                response = mode_str.encode('ascii')
                if self.verbose:
                    print(f"[MockFPGA] Mode set: {'encrypt' if self.mode else 'decrypt'}")
                return response + b'\n'
            else:
                if self.verbose:
                    print("[MockFPGA] Invalid mode format")
                return b''  # Malformed, no response
        
        # Command: D (Data load)
        elif cmd_str.startswith('D:'):
            hex_str = cmd_str[2:].strip()
            if self._validate_hex(hex_str, 32):
                self.data = binascii.unhexlify(hex_str)
                response = hex_str.encode('ascii')
                if self.verbose:
                    print(f"[MockFPGA] Data loaded: {hex_str[:16]}...")
                return response + b'\n'
            else:
                if self.verbose:
                    print("[MockFPGA] Invalid data format")
                return b''  # Malformed, no response
        
        # Command: S (Start/Execute AES)
        elif cmd_str == 'S':
            if self.key is None or self.mode is None or self.data is None:
                if self.verbose:
                    print("[MockFPGA] Missing key/mode/data")
                return b''  # Missing setup
            
            result = self._execute_aes()
            response = result.encode('ascii')
            if self.verbose:
                print(f"[MockFPGA] AES executed: {result[:16]}...")
            return response + b'\n'
        
        else:
            if self.verbose:
                print(f"[MockFPGA] Unknown command: {cmd_str}")
            return b''  # Unknown command, no response
    
    def _execute_aes(self) -> str:
        """
        Execute AES operation on mock FPGA.
        
        Returns:
            32-character hex string (result)
        """
        # Narrow Optional fields for static analyzers and keep runtime safety.
        if self.key is None or self.data is None or self.mode is None:
            raise RuntimeError("MockFPGA execute called before key/mode/data were set")

        key: bytes = self.key
        data: bytes = self.data

        if self.mode == 1:
            # Encrypt
            cipher = CryptoAES.new(key, CryptoAES.MODE_ECB)
            ciphertext = cipher.encrypt(data)
            return binascii.hexlify(ciphertext).decode('ascii').upper()
        else:
            # Decrypt
            cipher = CryptoAES.new(key, CryptoAES.MODE_ECB)
            plaintext = cipher.decrypt(data)
            return binascii.hexlify(plaintext).decode('ascii').upper()
    
    def _validate_hex(self, hex_str: str, length: int) -> bool:
        """
        Validate hex string format and length.
        
        Args:
            hex_str: String to validate
            length: Expected number of hex characters (not bytes)
        
        Returns:
            True if valid, False otherwise
        """
        if len(hex_str) != length:
            return False
        try:
            binascii.unhexlify(hex_str)
            return True
        except (ValueError, binascii.Error):
            return False
    
    # Fault injection methods
    
    def inject_timeout(self) -> None:
        """Inject timeout fault: next read() returns empty (timeout)."""
        self._timeout_next = True
        if self.verbose:
            print("[MockFPGA] Timeout injected (next read will timeout)")
    
    def inject_malformed(self) -> None:
        """Inject malformed response: next read() returns garbage."""
        self._malformed_next = True
        if self.verbose:
            print("[MockFPGA] Malformed response injected")
    
    def inject_disconnect(self) -> None:
        """Inject disconnect: next read() raises IOError."""
        self._disconnect_next = True
        if self.verbose:
            print("[MockFPGA] Disconnect injected")
    
    def reset_faults(self) -> None:
        """Clear all injected faults."""
        self._timeout_next = False
        self._malformed_next = False
        self._disconnect_next = False
        if self.verbose:
            print("[MockFPGA] Faults cleared")
    
    def get_stats(self) -> dict[str, int]:
        """
        Get statistics about mock FPGA usage.
        
        Returns:
            Dictionary with command/response counts
        """
        return {
            'commands_received': self.commands_received,
            'responses_sent': self.responses_sent,
            'buffer_size': len(self._buffer),
        }
    
    def __repr__(self) -> str:
        """String representation."""
        return f"MockFPGAController(commands={self.commands_received}, responses={self.responses_sent})"


class MockSerialPort:
    """
    Drop-in replacement for pyserial.Serial that uses MockFPGAController.
    
    This class allows aes_hil_test.py to work unchanged with mock FPGA.
    """
    
    def __init__(self, port: Optional[str] = None, baudrate: int = 115200,
                 timeout: float = 1.0, mock_fpga: Optional[MockFPGAController] = None,
                 verbose: bool = False):
        """
        Initialize mock serial port.
        
        Args:
            port: Port name (ignored, not used by mock)
            baudrate: Baud rate (ignored, not used by mock)
            timeout: Read timeout in seconds (used to detect no response)
            mock_fpga: Pre-configured MockFPGAController (or None to create new)
            verbose: Enable debug output
        """
        self.port = port or "MOCK"
        self.baudrate = baudrate
        self.timeout = timeout
        self.verbose = verbose
        self._rx_buffer = b''
        
        # Use provided mock or create new one
        self.mock_fpga = mock_fpga or MockFPGAController(verbose=verbose)
        
        if self.verbose:
            print(f"[MockSerialPort] Opened {self.port}")
    
    def write(self, data: bytes) -> int:
        """Write data to mock FPGA and queue response bytes."""
        written = self.mock_fpga.write(data)
        try:
            response = self.mock_fpga.read(4096)
            if response:
                self._rx_buffer += response
        except IOError:
            # Preserve behavior for injected disconnect faults.
            raise
        return written

    @property
    def in_waiting(self) -> int:
        """Number of bytes currently available for reading."""
        return len(self._rx_buffer)
    
    def read(self, size: int = 1) -> bytes:
        """Read up to size bytes from queued response buffer."""
        start_time = time.time()

        while True:
            if self._rx_buffer:
                chunk = self._rx_buffer[:size]
                self._rx_buffer = self._rx_buffer[size:]
                return chunk

            elapsed = time.time() - start_time
            if elapsed > self.timeout:
                if self.verbose:
                    print(f"[MockSerialPort] Read timeout after {elapsed:.2f}s")
                return b''

            time.sleep(0.001)
    
    def reset_input_buffer(self) -> None:
        """Reset input buffer."""
        self.mock_fpga.reset_input_buffer()
        self._rx_buffer = b''
    
    def close(self) -> None:
        """Close port."""
        self.mock_fpga.close()
    
    def __enter__(self):
        """Context manager support."""
        return self
    
    def __exit__(self, *args):
        """Context manager cleanup."""
        self.close()


if __name__ == '__main__':
    """
    Quick test of mock FPGA controller.
    """
    print("=== Mock FPGA Controller Self-Test ===\n")
    
    # Create mock FPGA
    mock = MockFPGAController(verbose=True)
    
    # Test 1: Basic encryption
    print("\n--- Test 1: Basic Encryption ---")
    mock.write(b'K:000102030405060708090A0B0C0D0E0F\n')
    print(f"Key response: {mock.read(100)}")
    
    mock.write(b'M:1\n')
    print(f"Mode response: {mock.read(100)}")
    
    mock.write(b'D:00112233445566778899AABBCCDDEEFF\n')
    print(f"Data response: {mock.read(100)}")
    
    mock.write(b'S\n')
    print(f"Result: {mock.read(100)}")
    
    # Test 2: Fault injection (timeout)
    print("\n--- Test 2: Fault Injection (Timeout) ---")
    mock.inject_timeout()
    mock.write(b'D:00112233445566778899AABBCCDDEEFF\n')
    result = mock.read(100)
    print(f"Response (should be empty): {result}")
    
    # Test 3: Fault injection (malformed)
    print("\n--- Test 3: Fault Injection (Malformed) ---")
    mock.inject_malformed()
    mock.write(b'D:00112233445566778899AABBCCDDEEFF\n')
    result = mock.read(100)
    print(f"Response (malformed): {result}")
    
    # Test 4: Statistics
    print(f"\n--- Test 4: Statistics ---")
    print(f"Stats: {mock.get_stats()}")
