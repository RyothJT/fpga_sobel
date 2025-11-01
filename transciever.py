from PIL import Image
import numpy as np
import serial
import threading
import time

# --- Configuration ---
PORT = 'COM4'
BAUD = 256_000

k = 0 # number of bottom rows to exclue to guarentee image generation

# --- Load image ---
# img = Image.open("test_image.jpg").convert("L")
img = Image.open("loris_480p.png").convert("L")


# Rotate if width > height
rotated = False
if img.width > img.height:
    img = img.rotate(90, expand=True)
    rotated = True

arr = np.array(img, dtype=np.uint8)
height, width = arr.shape
data = arr.flatten().tobytes()

# --- Open serial ---
ser = serial.Serial(PORT, baudrate=BAUD)

print("Pixels expected:", width * height)

# --- Thread functions ---
import time

def sender():
    ser.reset_input_buffer()
    ser.reset_output_buffer()

    ser.write(width.to_bytes(2, 'little'))
    ser.write(height.to_bytes(2, 'little'))

    ser.write(data)

    # pack_size = 4200
    # for i in range(0, len(data), pack_size):
    #     pack = data[i:i + pack_size]
    #     ser.write(pack)
    #     ser.flush()  # ensure transmission completes before next pack
    #     time.sleep(0.1)  # small delay between packs

    print("Image sent.")


def receiver(timeout=1.0):
    print("Start receiving...")
    processed = bytearray()

    total = width * (height - k)
    start_time = time.time()

    total = width * (height - k)
    start_time = time.time()

    while len(processed) < total:
        if ser.in_waiting:
            byte = ser.read(1)
            processed.extend(byte)
            start_time = time.time()  # reset timer
            #print(f"\r{len(processed)}/{total} pixels received", end="")
        elif time.time() - start_time > timeout:
            remaining = total - len(processed)
            processed.extend(b'\xFF' * remaining)
            print(f"\nTimeout. Filled {remaining} pixels with white.")
            break


    print("\nReception complete.")
    result = np.frombuffer(processed, dtype=np.uint8).reshape(((height-k), width))
    img_out = Image.fromarray(result, mode='L')

    # Rotate back if original was rotated
    if rotated:
        img_out = img_out.rotate(-90, expand=True)

    img_out.save("output.png")
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
