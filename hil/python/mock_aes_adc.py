"""
Mock AES ADC controller for AES Hardware-in-the-Loop testing.

This module simulates the autonomous ADC-to-AES-to-UART path used by
adc_monitor.py without requiring FPGA hardware.

It is intentionally narrow: it models the PC-facing serial stream and the
key-loading handshake, then emits encrypted ADC samples as UART lines.
"""

import binascii
from collections import deque
from typing import Deque, Iterable, Optional

from Crypto.Cipher import AES


class MockAESADCController:
    """Drop-in serial port mock for ADC monitor integration tests."""

    def __init__(
        self,
        port: str = "MOCK_ADC",
        baudrate: int = 115200,
        timeout: float = 1.0,
        sample_values: Optional[Iterable[int]] = None,
        verbose: bool = False,
    ):
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self.verbose = verbose
        self.key: Optional[bytes] = None
        self._incoming = b""
        self._samples: Deque[int] = deque(sample_values or [0x010, 0x123, 0x2AA, 0x3FF])

    def write(self, data: bytes) -> int:
        """Accept key-load commands from adc_monitor.py."""
        self._incoming += data

        while b"\n" in self._incoming:
            line, self._incoming = self._incoming.split(b"\n", 1)
            command = line.decode("ascii", errors="ignore").strip()
            if command.startswith("K:"):
                key_hex = command[2:].strip()
                if len(key_hex) == 32 and all(c in "0123456789abcdefABCDEF" for c in key_hex):
                    self.key = binascii.unhexlify(key_hex)
                    if self.verbose:
                        print(f"[MockAESADC] Key loaded: {key_hex}")

        return len(data)

    def readline(self) -> bytes:
        """Return the next encrypted ADC sample as a UART line."""
        if self.key is None or not self._samples:
            return b""

        adc_value = self._samples.popleft() & 0xFFF
        plaintext = adc_value.to_bytes(16, byteorder="big")
        cipher = AES.new(self.key, AES.MODE_ECB)
        ciphertext = cipher.encrypt(plaintext)

        line = binascii.hexlify(ciphertext).upper() + b"\n"

        if self.verbose:
            print(f"[MockAESADC] Sample {adc_value:04X} -> {line[:16].decode('ascii')}...")

        return line

    def reset_input_buffer(self) -> None:
        self._incoming = b""

    def close(self) -> None:
        return None


if __name__ == "__main__":
    mock = MockAESADCController(verbose=True)
    mock.write(b"K:000102030405060708090A0B0C0D0E0F\n")
    for _ in range(3):
        print(mock.readline().decode("ascii").strip())


# Backward-compatible alias.
MockADCSerialPort = MockAESADCController