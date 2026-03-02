
# Aegis.ai YOLOv8 Action Unit Detection Model

This document provides instructions and details for using the fine-tuned YOLOv8 model developed for Action Unit (AU) detection in facial expressions.

## 1. Model Overview

The model is a YOLOv8-Small architecture fine-tuned to detect four specific Action Units (AUs) in human faces. These AUs are:

*   **AU4:** Brow Lowerer (associated with anger, sadness, concentration)
*   **AU7:** Lid Tightener (associated with stress, focus, fear)
*   **AU23:** Lip Tightener (associated with contempt, effort, happiness)
*   **AU43:** Eyes Closed (associated with blinking, surprise, sleepiness)

The model is provided in `.onnx` format for efficient inference in deployment environments like FastAPI backends.

## 2. Model Location

The trained ONNX model is located at:
`/content/drive/MyDrive/Hackmatrix/aegis_final_production/weights/best.onnx`

## 3. How to Use the Model

### Prerequisites

Ensure you have the `ultralytics` and `opencv-python` libraries installed:

```bash
!pip install ultralytics opencv-python onnxruntime-gpu # or onnxruntime for CPU
```

### Loading the Model

Use the `YOLO` class from `ultralytics` to load the ONNX model:

```python
from ultralytics import YOLO
import cv2

# Path to your downloaded ONNX model
onnx_path = '/path/to/your/best.onnx' 
model = YOLO(onnx_path, task='detect')
```

### AU Mapping

The model predicts class IDs from 0 to 3. These correspond to the following Action Units:

```python
au_map = {
    0: 'AU4 (Brow Lowerer)',
    1: 'AU7 (Lid Tightener)',
    2: 'AU23 (Lip Tightener)',
    3: 'AU43 (Eyes Closed)'
}
```

### Making Predictions

The `model.predict()` method is used for inference. Key parameters are:

*   `source`: The input image or video frame (can be a file path, PIL Image, NumPy array, etc.).
*   `conf`: Confidence threshold for object detection (e.g., `0.25`). Detections with confidence below this value will be discarded. Lower values mean more detections, potentially with more false positives.
*   `imgsz`: Image size for inference (e.g., `640`). It's recommended to use the size the model was trained with.
*   `verbose`: Set to `False` to suppress verbose output during prediction.

### Example Inference on an Image

```python
# Load an image
image_path = 'your_image.jpg'
img = cv2.imread(image_path)

# Ensure image is loaded correctly
if img is None:
    print(f"Error: Could not load image from {image_path}")
else:
    # Predict AUs
    results = model.predict(source=img, conf=0.25, imgsz=640, verbose=False)

    # Process results
    for r in results:
        for box in r.boxes:
            cls_id = int(box.cls[0])
            score = float(box.conf[0])
            x1, y1, x2, y2 = map(int, box.xyxy[0])

            au_name = au_map.get(cls_id, f"AU{cls_id}")
            print(f"Detected {au_name} with score: {score:.2f} at [{x1}, {y1}, {x2}, {y2}]")

            # You can also draw on the image:
            cv2.rectangle(img, (x1, y1), (x2, y2), (0, 255, 0), 2)
            cv2.putText(img, f"{au_name}: {score:.2f}", (x1, y1 - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
    
    # Display or save the annotated image (example for Colab)
    # from google.colab.patches import cv2_imshow
    # cv2_imshow(img)

```

## 4. Understanding the Results

The `results` object returned by `model.predict()` is an `ultralytics.engine.results.Results` object. It contains a list of detection objects, typically one per input image/frame.

Each detection object (`r` in the loop above) has a `boxes` attribute, which is an `ultralytics.engine.results.Boxes` object. This `boxes` object contains tensor data for each detected object:

*   `box.xyxy`: Bounding box coordinates in `[x1, y1, x2, y2]` format.
*   `box.conf`: Confidence score of the detection (0 to 1).
*   `box.cls`: Class ID of the detected object.

The `score` (confidence) indicates the intensity or presence likelihood of the detected Action Unit. A higher score means the model is more confident that the AU is present. You can adjust the `conf` parameter during prediction to control the sensitivity of detections.

## 5. Interpreting AUs for Moods

While this model directly predicts Action Units, these AUs can be combined or interpreted to infer broader emotional states or 'moods'. For example:

*   **Sad / Angry:** Often associated with high `AU4` scores.
*   **Stressed:** May involve `AU7`.
*   **Focused / Happy:** Could involve `AU23` (e.g., slight lip corner pull).
*   **Blink / Surprise:** `AU43` specifically targets eye closure.

Further logic would be required to map combinations of AU scores into a definitive 'mood' classification.
