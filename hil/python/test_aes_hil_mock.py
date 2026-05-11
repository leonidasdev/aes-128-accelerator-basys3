"""
Unit tests for AES HIL Test Framework using Mock FPGA

Tests the Python HIL framework (aes_hil_test.py) against a mock FPGA controller.
Does not require actual hardware or USB connection.

Run with:
    python -m pytest test_aes_hil_mock.py -v
    
Or directly:
    python test_aes_hil_mock.py

Test Coverage:
- Command transmission and parsing
- Response validation
- Error handling (timeout, malformed, disconnect)
- Encryption and decryption workflows
- Round-trip verification
- End-to-end test suite execution
"""

import sys
import os
import unittest
from unittest.mock import patch, MagicMock
import binascii

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(__file__))

from mock_fpga_controller import MockFPGAController, MockSerialPort
from aes_hil_test import AESHardwareTest


class TestMockFPGAController(unittest.TestCase):
    """Unit tests for MockFPGAController."""
    
    def setUp(self):
        """Create fresh mock FPGA for each test."""
        self.mock = MockFPGAController(verbose=False)
    
    def test_key_load(self):
        """Test loading a key."""
        key_hex = '000102030405060708090A0B0C0D0E0F'
        
        self.mock.write(f'K:{key_hex}\n'.encode('ascii'))
        response = self.mock.read(100).decode('ascii').strip()
        
        self.assertEqual(response, key_hex.upper())
        self.assertIsNotNone(self.mock.key)
    
    def test_mode_encrypt(self):
        """Test setting encryption mode."""
        self.mock.write(b'M:1\n')
        response = self.mock.read(100).decode('ascii').strip()
        
        self.assertEqual(response, '1')
        self.assertEqual(self.mock.mode, 1)
    
    def test_mode_decrypt(self):
        """Test setting decryption mode."""
        self.mock.write(b'M:0\n')
        response = self.mock.read(100).decode('ascii').strip()
        
        self.assertEqual(response, '0')
        self.assertEqual(self.mock.mode, 0)
    
    def test_data_load(self):
        """Test loading plaintext/ciphertext."""
        data_hex = '00112233445566778899AABBCCDDEEFF'
        
        self.mock.write(f'D:{data_hex}\n'.encode('ascii'))
        response = self.mock.read(100).decode('ascii').strip()
        
        self.assertEqual(response, data_hex.upper())
        self.assertIsNotNone(self.mock.data)
    
    def test_encryption_fips197_vector1(self):
        """Test encryption with FIPS-197 vector 1."""
        # Key: 000102030405060708090A0B0C0D0E0F
        # PT:  00112233445566778899AABBCCDDEEFF
        # CT:  69C4E0D86A7B0430D8CDB78070B4C55A
        
        self.mock.write(b'K:000102030405060708090A0B0C0D0E0F\n')
        self.mock.read(100)  # Consume echo
        
        self.mock.write(b'M:1\n')  # Encrypt
        self.mock.read(100)  # Consume echo
        
        self.mock.write(b'D:00112233445566778899AABBCCDDEEFF\n')
        self.mock.read(100)  # Consume echo
        
        self.mock.write(b'S\n')
        result = self.mock.read(100).decode('ascii').strip()
        
        expected = '69C4E0D86A7B0430D8CDB78070B4C55A'
        self.assertEqual(result, expected)
    
    def test_decryption_fips197_vector1(self):
        """Test decryption with FIPS-197 vector 1."""
        self.mock.write(b'K:000102030405060708090A0B0C0D0E0F\n')
        self.mock.read(100)
        
        self.mock.write(b'M:0\n')  # Decrypt
        self.mock.read(100)
        
        self.mock.write(b'D:69C4E0D86A7B0430D8CDB78070B4C55A\n')
        self.mock.read(100)
        
        self.mock.write(b'S\n')
        result = self.mock.read(100).decode('ascii').strip()
        
        expected = '00112233445566778899AABBCCDDEEFF'
        self.assertEqual(result, expected)
    
    def test_timeout_injection(self):
        """Test timeout fault injection."""
        self.mock.inject_timeout()
        self.mock.write(b'K:000102030405060708090A0B0C0D0E0F\n')
        response = self.mock.read(100)
        
        self.assertEqual(response, b'')
    
    def test_malformed_injection(self):
        """Test malformed response fault injection."""
        self.mock.inject_malformed()
        self.mock.write(b'K:000102030405060708090A0B0C0D0E0F\n')
        response = self.mock.read(100)
        
        # Response should be garbage
        self.assertNotEqual(response, b'000102030405060708090A0B0C0D0E0F\n')
        self.assertTrue(len(response) > 0)
    
    def test_disconnect_injection(self):
        """Test disconnect fault injection."""
        self.mock.inject_disconnect()
        self.mock.write(b'K:000102030405060708090A0B0C0D0E0F\n')
        
        with self.assertRaises(IOError):
            self.mock.read(100)
    
    def test_invalid_key_format(self):
        """Test invalid key (wrong length)."""
        self.mock.write(b'K:0001020304\n')  # Too short
        response = self.mock.read(100)
        
        # Should return empty (malformed)
        self.assertEqual(response, b'')
    
    def test_invalid_mode(self):
        """Test invalid mode value."""
        self.mock.write(b'M:5\n')  # Invalid
        response = self.mock.read(100)
        
        # Should return empty (malformed)
        self.assertEqual(response, b'')
    
    def test_unknown_command(self):
        """Test unknown command."""
        self.mock.write(b'X:00112233445566778899AABBCCDDEEFF\n')
        response = self.mock.read(100)
        
        # Should return empty (unknown command)
        self.assertEqual(response, b'')
    
    def test_stats(self):
        """Test statistics collection."""
        self.mock.write(b'K:000102030405060708090A0B0C0D0E0F\n')
        self.mock.read(100)
        
        stats = self.mock.get_stats()
        self.assertEqual(stats['commands_received'], 1)
        self.assertEqual(stats['responses_sent'], 1)


class TestMockSerialPort(unittest.TestCase):
    """Unit tests for MockSerialPort."""
    
    def test_port_initialization(self):
        """Test port initialization."""
        port = MockSerialPort(port='MOCK_COM3', baudrate=115200)
        self.assertEqual(port.port, 'MOCK_COM3')
        port.close()
    
    def test_read_with_timeout(self):
        """Test read timeout behavior."""
        mock_fpga = MockFPGAController()
        port = MockSerialPort(timeout=0.1, mock_fpga=mock_fpga)
        
        # Write incomplete command (no newline)
        port.write(b'K:000102030405060708090A0B0C0D0E0F')
        
        # Read should timeout
        response = port.read(100)
        self.assertEqual(response, b'')
        
        port.close()
    
    def test_write_and_read(self):
        """Test basic write/read cycle."""
        port = MockSerialPort()
        
        port.write(b'K:000102030405060708090A0B0C0D0E0F\n')
        response = port.read(100)
        
        self.assertEqual(response, b'000102030405060708090A0B0C0D0E0F\n')
        port.close()
    
    def test_context_manager(self):
        """Test context manager support."""
        with MockSerialPort() as port:
            port.write(b'K:000102030405060708090A0B0C0D0E0F\n')
            response = port.read(100)
            self.assertTrue(len(response) > 0)


class TestAESHardwareTestWithMock(unittest.TestCase):
    """Integration tests for AESHardwareTest using mock FPGA."""
    
    def setUp(self):
        """Create mock serial port for each test."""
        self.mock_fpga = MockFPGAController(verbose=False)
        self.mock_port = MockSerialPort(mock_fpga=self.mock_fpga, timeout=1.0)
    
    def tearDown(self):
        """Clean up."""
        self.mock_port.close()
    
    @patch('aes_hil_test.serial.Serial')
    def test_set_key(self, mock_serial_class):
        """Test setting key through HIL test class."""
        # Configure mock to return our mock port
        mock_serial_class.return_value = self.mock_port
        
        tester = AESHardwareTest(port='MOCK', verbose=False)
        
        # Set key
        result = tester.set_key('000102030405060708090A0B0C0D0E0F')
        
        # Should succeed
        self.assertTrue(result)
    
    @patch('aes_hil_test.serial.Serial')
    def test_set_mode(self, mock_serial_class):
        """Test setting mode through HIL test class."""
        mock_serial_class.return_value = self.mock_port
        
        tester = AESHardwareTest(port='MOCK', verbose=False)
        
        # Set mode
        result = tester.set_mode(1)
        
        # Should succeed
        self.assertTrue(result)
    
    @patch('aes_hil_test.serial.Serial')
    def test_set_data(self, mock_serial_class):
        """Test setting data through HIL test class."""
        mock_serial_class.return_value = self.mock_port
        
        tester = AESHardwareTest(port='MOCK', verbose=False)
        
        # Set data
        result = tester.set_data('00112233445566778899AABBCCDDEEFF')
        
        # Should succeed
        self.assertTrue(result)
    
    @patch('aes_hil_test.serial.Serial')
    def test_encryption_workflow(self, mock_serial_class):
        """Test complete encryption workflow."""
        mock_serial_class.return_value = self.mock_port
        
        tester = AESHardwareTest(port='MOCK', verbose=False)
        
        # Full encryption test
        key = '000102030405060708090A0B0C0D0E0F'
        plaintext = '00112233445566778899AABBCCDDEEFF'
        
        # Load setup
        self.assertTrue(tester.set_key(key))
        self.assertTrue(tester.set_mode(1))  # Encrypt
        self.assertTrue(tester.set_data(plaintext))
        
        # Execute and verify
        result = tester.execute()
        self.assertIsNotNone(result)
        
        # Verify against reference
        self.assertTrue(tester.verify_encryption(plaintext, key))
    
    @patch('aes_hil_test.serial.Serial')
    def test_decryption_workflow(self, mock_serial_class):
        """Test complete decryption workflow."""
        mock_serial_class.return_value = self.mock_port
        
        tester = AESHardwareTest(port='MOCK', verbose=False)
        
        # Full decryption test
        key = '000102030405060708090A0B0C0D0E0F'
        ciphertext = '69C4E0D86A7B0430D8CDB78070B4C55A'
        
        # Load setup
        self.assertTrue(tester.set_key(key))
        self.assertTrue(tester.set_mode(0))  # Decrypt
        self.assertTrue(tester.set_data(ciphertext))
        
        # Execute and verify
        result = tester.execute()
        self.assertIsNotNone(result)
        
        # Verify against reference
        self.assertTrue(tester.verify_decryption(ciphertext, key))
    
    @patch('aes_hil_test.serial.Serial')
    def test_roundtrip_workflow(self, mock_serial_class):
        """Test round-trip (encrypt then decrypt)."""
        mock_serial_class.return_value = self.mock_port
        
        tester = AESHardwareTest(port='MOCK', verbose=False)
        
        key = '000102030405060708090A0B0C0D0E0F'
        plaintext = '00112233445566778899AABBCCDDEEFF'
        
        # Verify round-trip
        self.assertTrue(tester.verify_round_trip(plaintext, key))


class TestErrorHandling(unittest.TestCase):
    """Test error handling scenarios."""
    
    @patch('aes_hil_test.serial.Serial')
    def test_timeout_recovery(self, mock_serial_class):
        """Test recovery from timeout."""
        mock_fpga = MockFPGAController()
        mock_port = MockSerialPort(mock_fpga=mock_fpga)
        mock_serial_class.return_value = mock_port
        
        tester = AESHardwareTest(port='MOCK', verbose=False)
        
        # First command times out
        mock_fpga.inject_timeout()
        result1 = tester.set_key('000102030405060708090A0B0C0D0E0F')
        self.assertFalse(result1)  # Should fail
        
        # Second command succeeds
        result2 = tester.set_key('000102030405060708090A0B0C0D0E0F')
        self.assertTrue(result2)  # Should succeed
    
    @patch('aes_hil_test.serial.Serial')
    def test_malformed_response_handling(self, mock_serial_class):
        """Test handling of malformed responses."""
        mock_fpga = MockFPGAController()
        mock_port = MockSerialPort(mock_fpga=mock_fpga)
        mock_serial_class.return_value = mock_port
        
        tester = AESHardwareTest(port='MOCK', verbose=False)
        
        # Inject malformed response
        mock_fpga.inject_malformed()
        result = tester.set_key('000102030405060708090A0B0C0D0E0F')
        
        # Should fail due to malformed response
        self.assertFalse(result)


class TestFIPSVectors(unittest.TestCase):
    """Test against FIPS-197 canonical vectors."""
    
    def setUp(self):
        """Set up FIPS-197 test vectors."""
        self.vectors = [
            {
                'plaintext': '00112233445566778899AABBCCDDEEFF',
                'key': '000102030405060708090A0B0C0D0E0F',
                'ciphertext': '69C4E0D86A7B0430D8CDB78070B4C55A',
            },
            {
                'plaintext': '6BC1BEE22E409F96E93D7E117393172A',
                'key': '2B7E151628AED2A6ABF7158809CF4F3C',
                'ciphertext': '3AD77BB40D7A3660A89ECAF32466EF97',
            },
        ]
    
    def test_all_fips_vectors(self):
        """Test all FIPS-197 vectors with mock FPGA."""
        for i, vector in enumerate(self.vectors):
            mock_fpga = MockFPGAController()
            mock_port = MockSerialPort(mock_fpga=mock_fpga)
            
            with patch('aes_hil_test.serial.Serial', return_value=mock_port):
                tester = AESHardwareTest(port='MOCK', verbose=False)
                
                # Test encryption
                result = tester.verify_encryption(
                    vector['plaintext'], 
                    vector['key']
                )
                self.assertTrue(result, f"Vector {i+1} encryption failed")
                
                # Test decryption
                result = tester.verify_decryption(
                    vector['ciphertext'],
                    vector['key']
                )
                self.assertTrue(result, f"Vector {i+1} decryption failed")
                
                # Test round-trip
                result = tester.verify_round_trip(
                    vector['plaintext'],
                    vector['key']
                )
                self.assertTrue(result, f"Vector {i+1} round-trip failed")


def run_tests():
    """Run all tests with verbose output."""
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add all test classes
    suite.addTests(loader.loadTestsFromTestCase(TestMockFPGAController))
    suite.addTests(loader.loadTestsFromTestCase(TestMockSerialPort))
    suite.addTests(loader.loadTestsFromTestCase(TestAESHardwareTestWithMock))
    suite.addTests(loader.loadTestsFromTestCase(TestErrorHandling))
    suite.addTests(loader.loadTestsFromTestCase(TestFIPSVectors))
    
    # Run with verbose output
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    return 0 if result.wasSuccessful() else 1


if __name__ == '__main__':
    exit(run_tests())
