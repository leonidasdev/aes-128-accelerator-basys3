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


def write_and_read(serial_port, cmd, pause=0.05):
    try:
        print('SEND:', repr(cmd))
        serial_port.write(cmd.encode('ascii'))
        time.sleep(pause)
        data = serial_port.read(1024)
        print('RECV:', data)
        return data
    except Exception as e:
        print('ERROR during write/read:', e)
        return b''


def main():
    parser = argparse.ArgumentParser(description='Send one AES vector to the FPGA over UART')
    parser.add_argument('--port', default='COM6', help='Serial port (default: COM6)')
    parser.add_argument('--baudrate', type=int, default=115200, help='UART baud rate (default: 115200)')
    parser.add_argument('--timeout', type=float, default=0.5, help='Serial read timeout in seconds (default: 0.5)')
    parser.add_argument('--key', default='000102030405060708090A0B0C0D0E0F', help='128-bit key as 32 hex characters')
    parser.add_argument('--mode', default='1', choices=('0', '1'), help='AES mode: 1=encrypt, 0=decrypt')
    parser.add_argument('--data', default='00112233445566778899AABBCCDDEEFF', help='128-bit input block as 32 hex characters')
    parser.add_argument('--initial-wait', type=float, default=0.7, help='Delay after opening the port before sending commands')
    parser.add_argument('--key-pause', type=float, default=0.5, help='Delay after K command')
    parser.add_argument('--mode-pause', type=float, default=0.2, help='Delay after M command')
    parser.add_argument('--data-pause', type=float, default=0.2, help='Delay after D command')
    parser.add_argument('--start-pause', type=float, default=1.0, help='Delay after S command')
    parser.add_argument('--final-pause', type=float, default=0.2, help='Delay before final drain read')
    parser.add_argument('--disable-buffer-reset', action='store_true', help='Do not clear RX/TX buffers before sending')

    args = parser.parse_args()

    serial_port = open_serial(args.port, args.baudrate, args.timeout)
    if serial_port is None:
        sys.exit(1)

    try:
        time.sleep(args.initial_wait)
        if not args.disable_buffer_reset:
            try:
                serial_port.reset_input_buffer()
                serial_port.reset_output_buffer()
            except Exception:
                pass

        write_and_read(serial_port, f'K:{args.key}\n', args.key_pause)
        write_and_read(serial_port, f'M:{args.mode}\n', args.mode_pause)
        write_and_read(serial_port, f'D:{args.data}\n', args.data_pause)
        write_and_read(serial_port, 'S\n', args.start_pause)
        time.sleep(args.final_pause)
        print('FINAL RECV:', serial_port.read(2048))
    finally:
        serial_port.close()


if __name__ == '__main__':
    main()
