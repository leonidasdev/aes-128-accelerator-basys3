"""
Integration tests for adc_monitor.py using a mock ADC serial stream.

These tests validate the PC-side ADC monitoring flow without requiring the FPGA
or a live UART connection.
"""

import csv
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, os.path.dirname(__file__))

from adc_monitor import ADCMonitor
from mock_aes_adc import MockAESADCController


class TestADCMonitorWithMock(unittest.TestCase):
    """End-to-end monitor tests against the ADC stream mock."""

    def setUp(self):
        self._old_cwd = os.getcwd()
        self._tempdir = tempfile.TemporaryDirectory()
        os.chdir(self._tempdir.name)

    def tearDown(self):
        os.chdir(self._old_cwd)
        self._tempdir.cleanup()

    @patch('adc_monitor.serial.Serial')
    def test_load_key(self, mock_serial_class):
        mock_port = MockAESADCController(sample_values=[])
        mock_serial_class.return_value = mock_port

        monitor = ADCMonitor(port='MOCK', verbose=False)
        self.assertTrue(monitor.load_key('000102030405060708090A0B0C0D0E0F'))
        self.assertIsNotNone(mock_port.key)

    @patch('adc_monitor.serial.Serial')
    def test_monitor_logs_adc_samples(self, mock_serial_class):
        sample_values = [0x000, 0x123, 0xABC]
        mock_port = MockAESADCController(sample_values=sample_values, verbose=False)
        mock_serial_class.return_value = mock_port

        monitor = ADCMonitor(port='MOCK', verbose=False)
        monitor.monitor(duration=1.0, key_hex='000102030405060708090A0B0C0D0E0F', csv_file='adc_mock.csv')

        csv_path = Path('results') / 'adc_mock.csv'
        self.assertTrue(csv_path.exists())

        with csv_path.open(newline='') as handle:
            rows = list(csv.reader(handle))

        self.assertEqual(rows[0], ['Timestamp', 'Sample #', 'Ciphertext (hex)', 'ADC Value (raw)', 'ADC Voltage (V)'])
        self.assertEqual(len(rows) - 1, 3)
        self.assertEqual([int(row[3]) for row in rows[1:]], sample_values)


if __name__ == '__main__':
    unittest.main()