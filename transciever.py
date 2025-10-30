from PIL import Image
import numpy as np
import serial
import threading
import time

# --- Configuration ---
PORT = 'COM4'
BAUD = 256000

k = 0 # number of bottom rows to exclue to guarentee image generation

# --- Load image ---
img = Image.open("loris_32p.png").convert("L")
arr = np.array(img, dtype=np.uint8)
height, width = arr.shape
data = arr.flatten().tobytes()

# --- Open serial ---
ser = serial.Serial(PORT, baudrate=BAUD)

print("Pixels expected:", width * height)

# --- Thread functions ---
def sender():
    ser.reset_input_buffer()
    ser.reset_output_buffer()

    ser.write(width.to_bytes(2, 'little'))
    ser.write(height.to_bytes(2, 'little'))
    ser.write(data)

    # chunk_size = 100
    # for i in range(0, len(data), chunk_size):
    #     ser.write(data[i:i + chunk_size])
    #     ser.flush()      # ensure data is sent


    print("Image sent.")


def receiver(timeout=1.0):
    print("Start receiving...")
    processed = bytearray()

    total = width * (height - k)
    start_time = time.time()

    while len(processed) < total:
        if ser.in_waiting:
            byte = ser.read(1)
            processed.extend(byte)
            start_time = time.time()  # reset timer
        elif time.time() - start_time > timeout:
            remaining = total - len(processed)
            processed.extend(b'\xFF' * remaining)
            print(f"\nTimeout. Filled {remaining} pixels with white.")
            break

    print("\nReception complete.")
    result = np.frombuffer(processed, dtype=np.uint8).reshape(((height-k), width))
    Image.fromarray(result, mode='L').save("output.png")
    print("Saved output.png")

    return processed




# --- Run both threads ---
t1 = threading.Thread(target=sender)
t2 = threading.Thread(target=receiver)

t1.start()
t2.start()

t1.join()
t2.join()

ser.close()
