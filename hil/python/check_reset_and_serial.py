import serial, time, sys

PORT='COM6'
BAUD=115200
try:
    s = serial.Serial(PORT, BAUD, timeout=0.5)
except Exception as e:
    print('ERROR: open serial', e)
    sys.exit(1)

print('Port open:', s.is_open)
# Print modem/control lines where available
try:
    print('CTS:', s.cts)
    print('DSR:', s.dsr)
    print('RI :', s.ri)
    print('CD :', s.cd)
except Exception as e:
    print('Modem status not available:', e)

print('DTR (before):', s.dtr, 'RTS (before):', s.rts)

# Toggle DTR and RTS to see if board responds (safe pulse)
print('Toggling DTR/RTS:')
s.dtr = False
s.rts = False
time.sleep(0.2)
print('DTR:', s.dtr, 'RTS:', s.rts)
s.dtr = True
s.rts = True
time.sleep(0.2)
print('DTR:', s.dtr, 'RTS:', s.rts)

# Send a UART break which sometimes triggers reset handlers
print('Sending break (250 ms)')
try:
    s.send_break(0.25)
except Exception as e:
    print('send_break not supported:', e)

# Wait and clear buffers
time.sleep(0.2)
try:
    s.reset_input_buffer()
    s.reset_output_buffer()
except Exception:
    pass

# Send a simple newline to see if any prompt/echo appears
print('Sending newline probe')
s.write(b"\n")
# Wait a little longer for any response
time.sleep(1.0)
resp = s.read(2048)
print('Received bytes:', len(resp))
if resp:
    print('RESP:', resp)
else:
    print('No response from FPGA')

s.close()
print('Closed serial')
