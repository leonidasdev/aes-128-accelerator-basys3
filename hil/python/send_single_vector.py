import serial, time, sys

PORT = 'COM6'
BAUD = 115200
try:
    s = serial.Serial(PORT, BAUD, timeout=0.5)
except Exception as e:
    print('ERROR: open serial', e)
    sys.exit(1)

def write_and_read(cmd, pause=0.05):
    try:
        print('SEND:', repr(cmd))
        s.write(cmd.encode())
        # allow FPGA time to process and respond
        time.sleep(pause)
        # read available data
        data = s.read(1024)
        print('RECV:', data)
        return data
    except Exception as e:
        print('ERROR during write/read:', e)
        return b''

time.sleep(0.2)
# small wake delay and clear buffers
time.sleep(0.5)
try:
    s.reset_input_buffer()
    s.reset_output_buffer()
except Exception:
    pass

# increased delays to account for FPGA response latency
write_and_read('K:000102030405060708090A0B0C0D0E0F\n', 0.5)
write_and_read('M:1\n', 0.2)
write_and_read('D:00112233445566778899AABBCCDDEEFF\n', 0.2)
write_and_read('S\n', 1.0)
# final drain
time.sleep(0.2)
print('FINAL RECV:', s.read(2048))
s.close()
