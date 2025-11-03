from PIL import Image
import numpy as np
import serial
import threading
import time

PORT = 'COM4'
BAUD = 112_000 * 4  # Max ~448_000 Baud

def process_image(image_path):
    img = Image.open(image_path).convert("L")

    rotated = False
    if img.width > img.height:
        img = img.rotate(90, expand=True)
        rotated = True

    arr = np.array(img, dtype=np.uint8)
    height, width = arr.shape
    data = arr.flatten().tobytes()

    return data, width, height, rotated

def send_and_receive_image(image_path, output_path="output.png"):
    data, width, height, rotated = process_image(image_path)

    ser = serial.Serial(PORT, baudrate=BAUD)
    print("Pixels expected:", width * height)

    def sender():
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        ser.write(width.to_bytes(2, 'little'))
        ser.write(height.to_bytes(2, 'little'))
        ser.write(data)
        print("Image sent.")

    def receiver(timeout=10.0):
        print("Start receiving...")
        processed = bytearray()
        total = width * height
        start_time = time.time()

        while len(processed) < total:
            if ser.in_waiting:
                processed.append(ser.read(1)[0])
                start_time = time.time()
            elif time.time() - start_time > timeout:
                remaining = total - len(processed)
                processed.extend(b'\xFF' * remaining)
                print(f"\nTimeout. Filled {remaining} pixels with white.")
                break

        print("\nReception complete.")
        result = np.frombuffer(processed, dtype=np.uint8).reshape((height, width))

        max_val = result.max()
        if max_val > 0:
            result = (result.astype(np.float32) * (255.0 / max_val)).astype(np.uint8)

        img_out = Image.fromarray(result, mode='L')
        if rotated:
            img_out = img_out.rotate(-90, expand=True)

        img_out.save(output_path)
        print(f"Saved {output_path}")
        return processed

    t1 = threading.Thread(target=sender)
    t2 = threading.Thread(target=receiver)

    t1.start()
    t2.start()

    t1.join()
    result = t2.join()

    ser.close()
    return result

# Example call
# send_and_receive_image("input_images/loris_480p.png")
