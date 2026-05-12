#!/usr/bin/env python3
"""
serial_diagnostics.py
Run multiple serial checks useful for HIL debugging:
- list available COM ports
- open the target port and print modem/control lines
- toggle DTR/RTS and send break
- send simple newline probe
- run loop of probe writes with increasing delays
- run the full single-vector sequence with configurable pauses

Usage: python serial_diagnostics.py --port COM6
"""

import argparse
import sys
import time

import serial
import serial.tools.list_ports as comports


def list_ports():
    print('Available serial ports:')
    for p in comports.comports():
        print(f'  {p.device} | {p.description} | {p.hwid}')
    print()


def open_port(port, baud=115200, timeout=0.5):
    try:
        s = serial.Serial(port, baud, timeout=timeout)
        print(f'Opened {port} @ {baud}, timeout={timeout}s')
        return s
    except Exception as e:
        print('ERROR: open serial', e)
        return None


def probe_modem_and_toggle(s):
    try:
        print('Port open:', s.is_open)
        try:
            print('CTS:', s.cts, 'DSR:', s.dsr, 'RI:', s.ri, 'CD:', s.cd)
        except Exception as e:
            print('Modem status not available:', e)
        print('DTR (before):', s.dtr, 'RTS (before):', s.rts)

        print('Toggling DTR/RTS:')
        s.dtr = False
        s.rts = False
        time.sleep(0.2)
        print('DTR:', s.dtr, 'RTS:', s.rts)
        s.dtr = True
        s.rts = True
        time.sleep(0.2)
        print('DTR:', s.dtr, 'RTS:', s.rts)

        print('Sending break (0.25s)')
        try:
            s.send_break(0.25)
        except Exception as e:
            print('send_break not supported:', e)

    except Exception as e:
        print('ERROR probing/modem/toggle:', e)


def newline_probe(s):
    print('\nSending newline probe and reading reply (1s)...')
    try:
        s.reset_input_buffer()
        s.reset_output_buffer()
    except Exception:
        pass
    s.write(b"\n")
    time.sleep(1.0)
    data = s.read(2048)
    print('Received bytes:', len(data))
    if data:
        print('RESP:', data)
    else:
        print('No response')


def incremental_probes(s):
    probes = [0.02, 0.05, 0.2, 0.5, 1.0]
    print('\nRunning incremental probe writes (single ASCII char)')
    for p in probes:
        try:
            s.reset_input_buffer()
            s.reset_output_buffer()
        except Exception:
            pass
        print(f'  SEND A, wait {p}s ->', end=' ')
        s.write(b'A')
        time.sleep(p)
        r = s.read(256)
        print('RECV len=', len(r))
        if r:
            print('    DATA:', r)


def run_single_vector_sequence(s):
    print('\nRunning single-vector sequence (K, M, D, S) with longer margins')
    seq = [ ('K:000102030405060708090A0B0C0D0E0F\n', 0.5),
            ('M:1\n', 0.2),
            ('D:00112233445566778899AABBCCDDEEFF\n', 0.5),
            ('S\n', 1.5) ]
    try:
        s.reset_input_buffer()
        s.reset_output_buffer()
    except Exception:
        pass
    for cmd, pause in seq:
        print('SEND:', repr(cmd.strip()), 'pause', pause)
        s.write(cmd.encode('ascii'))
        time.sleep(pause)
        data = s.read(4096)
        print('RECV len=', len(data))
        if data:
            print('RECV:', data)

    # final drain
    time.sleep(0.2)
    final = s.read(8192)
    print('FINAL RECV len=', len(final))
    if final:
        print('FINAL RECV:', final)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', '-p', default='COM6', help='Serial port (default: COM6)')
    parser.add_argument('--baud', '-b', default=115200, type=int, help='UART baud rate (default: 115200)')
    parser.add_argument('--timeout', type=float, default=0.5, help='Serial read timeout in seconds (default: 0.5)')
    parser.add_argument('--skip-modem-probe', action='store_true', help='Skip DTR/RTS and break probing')
    parser.add_argument('--skip-newline-probe', action='store_true', help='Skip the newline response probe')
    parser.add_argument('--skip-incremental-probes', action='store_true', help='Skip single-byte write probes')
    parser.add_argument('--skip-single-vector', action='store_true', help='Skip the K/M/D/S vector sequence')
    args = parser.parse_args()

    list_ports()

    s = open_port(args.port, baud=args.baud, timeout=args.timeout)
    if s is None:
        print('Unable to open port', args.port)
        sys.exit(1)

    if not args.skip_modem_probe:
        probe_modem_and_toggle(s)
    if not args.skip_newline_probe:
        newline_probe(s)
    if not args.skip_incremental_probes:
        incremental_probes(s)
    if not args.skip_single_vector:
        run_single_vector_sequence(s)

    s.close()
    print('\nClosed serial port')

if __name__ == '__main__':
    main()
