import os
import sys
from PyQt6.QtWidgets import (
    QApplication, QWidget, QListWidget, QLabel, QPushButton,
    QHBoxLayout, QVBoxLayout, QFileDialog, QSizePolicy
)
from PyQt6.QtGui import QPixmap
from PyQt6.QtCore import Qt, QThread, pyqtSignal
from transciever import send_and_receive_image  # Use your previous function

INPUT_DIR = "input_images"


class ImageWorker(QThread):
    finished = pyqtSignal(str)

    def __init__(self, image_path, output_path="output.png"):
        super().__init__()
        self.image_path = image_path
        self.output_path = os.path.join("output_images", output_path)

    def run(self):
        send_and_receive_image(self.image_path, self.output_path)
        self.finished.emit(self.output_path)


class ImageTransferApp(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Image Transfer GUI")
        self.resize(1200, 600)

        self.images = [f for f in os.listdir(INPUT_DIR) if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp'))]
        self.current_original_path = None

        self.setup_ui()

    def setup_ui(self):
        main_layout = QHBoxLayout()
        self.setLayout(main_layout)

        # Left: image list and button
        left_layout = QVBoxLayout()
        self.list_widget = QListWidget()
        self.list_widget.addItems(self.images)
        self.list_widget.currentRowChanged.connect(self.on_image_select)
        left_layout.addWidget(self.list_widget)

        self.send_button = QPushButton("Send and Process")
        self.send_button.clicked.connect(self.process_current_image)
        left_layout.addWidget(self.send_button)

        main_layout.addLayout(left_layout, 1)

        # Right: original and processed images
        right_layout = QHBoxLayout()
        self.original_label = QLabel("Original Image")
        self.original_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.original_label.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        self.original_label.setStyleSheet("background-color: gray;")
        right_layout.addWidget(self.original_label)

        self.processed_label = QLabel("Processed Image")
        self.processed_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.processed_label.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        self.processed_label.setStyleSheet("background-color: gray;")
        right_layout.addWidget(self.processed_label)

        main_layout.addLayout(right_layout, 3)

    def on_image_select(self, index):
        if index < 0:
            return
        self.current_original_path = os.path.join(INPUT_DIR, self.images[index])
        self.show_image(self.current_original_path, self.original_label)

    def show_image(self, path, label):
        pixmap = QPixmap(path)
        if pixmap.isNull():
            return
        label.setPixmap(pixmap.scaled(
            label.width(), label.height(),
            Qt.AspectRatioMode.KeepAspectRatio,
            Qt.TransformationMode.SmoothTransformation
        ))

    def resizeEvent(self, event):
        # Update displayed images on window resize
        if self.current_original_path:
            self.show_image(self.current_original_path, self.original_label)
        if hasattr(self, 'processed_path'):
            self.show_image(self.processed_path, self.processed_label)
        super().resizeEvent(event)

    def process_current_image(self):
        if not self.current_original_path:
            return
        self.send_button.setEnabled(False)
        self.worker = ImageWorker(self.current_original_path)
        self.worker.finished.connect(self.on_process_finished)
        self.worker.start()

    def on_process_finished(self, output_path):
        self.processed_path = output_path
        self.show_image(output_path, self.processed_label)
        self.send_button.setEnabled(True)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = ImageTransferApp()
    window.show()
    sys.exit(app.exec())
