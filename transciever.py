from PIL import Image
import numpy as np
import serial
import threading

# --- Configuration ---
PORT = 'COM4'
BAUD = 256000

# --- Load image ---
img = Image.open("loris_480p.png").convert("L")
arr = np.array(img, dtype=np.uint8)
height, width = arr.shape
data = arr.flatten().tobytes()

# --- Open serial ---
ser = serial.Serial(PORT, baudrate=BAUD)

print("Pixels expected:", width * height)

# --- Thread functions ---
def sender():
    ser.write(width.to_bytes(2, 'little'))
    ser.write(height.to_bytes(2, 'little'))
    ser.write(data)
    print("Image sent.")

def receiver():
    print("Start receiving...")
    processed = bytearray()

    for pixel in range(width * height):
        byte = ser.read(1)
        if not byte:
            print("Not a byte!")
            continue  # wait for data if timeout
        processed.extend(byte)
        print(f"{pixel+1}/{width*height} bytes received", end='\r')

    print("\nReception complete.")
    result = np.frombuffer(processed, dtype=np.uint8).reshape((height, width))
    Image.fromarray(result, mode='L').save("output.png")
    print("Saved output.png")

# --- Run both threads ---
t1 = threading.Thread(target=sender)
t2 = threading.Thread(target=receiver)

t1.start()
t2.start()

t1.join()
t2.join()

ser.close()
