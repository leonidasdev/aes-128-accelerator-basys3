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


def main():
    parser = argparse.ArgumentParser(description='Probe FPGA reset and serial behavior')
    parser.add_argument('--port', default='COM6', help='Serial port (default: COM6)')
    parser.add_argument('--baudrate', type=int, default=115200, help='UART baud rate (default: 115200)')
    parser.add_argument('--timeout', type=float, default=0.5, help='Serial read timeout in seconds (default: 0.5)')
    parser.add_argument('--break-time', type=float, default=0.25, help='UART break duration in seconds (default: 0.25)')
    parser.add_argument('--post-break-wait', type=float, default=0.2, help='Wait after break before clearing buffers')
    parser.add_argument('--final-wait', type=float, default=1.0, help='Wait after newline probe before reading')
    parser.add_argument('--disable-buffer-reset', action='store_true', help='Do not clear RX/TX buffers before probing')

    args = parser.parse_args()

    serial_port = open_serial(args.port, args.baudrate, args.timeout)
    if serial_port is None:
        sys.exit(1)

    try:
        print('Port open:', serial_port.is_open)
        try:
            print('CTS:', serial_port.cts)
            print('DSR:', serial_port.dsr)
            print('RI :', serial_port.ri)
            print('CD :', serial_port.cd)
        except Exception as e:
            print('Modem status not available:', e)

        print('DTR (before):', serial_port.dtr, 'RTS (before):', serial_port.rts)

        print('Toggling DTR/RTS:')
        serial_port.dtr = False
        serial_port.rts = False
        time.sleep(0.2)
        print('DTR:', serial_port.dtr, 'RTS:', serial_port.rts)
        serial_port.dtr = True
        serial_port.rts = True
        time.sleep(0.2)
        print('DTR:', serial_port.dtr, 'RTS:', serial_port.rts)

        print(f'Sending break ({int(args.break_time * 1000)} ms)')
        try:
            serial_port.send_break(args.break_time)
        except Exception as e:
            print('send_break not supported:', e)

        time.sleep(args.post_break_wait)
        if not args.disable_buffer_reset:
            try:
                serial_port.reset_input_buffer()
                serial_port.reset_output_buffer()
            except Exception:
                pass

        print('Sending newline probe')
        serial_port.write(b'\n')
        time.sleep(args.final_wait)
        resp = serial_port.read(2048)
        print('Received bytes:', len(resp))
        if resp:
            print('RESP:', resp)
        else:
            print('No response from FPGA')
    finally:
        serial_port.close()
        print('Closed serial')


if __name__ == '__main__':
    main()
