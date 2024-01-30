import numpy as np
import cv2 as cv
import base64

def create_colouring_page(img_data, blur_val=0, contrast_val=0, brighten_val=0, sharpen=0):
    # Convert b64 image data to OpenCV Mat format
    img_bytes = base64.b64decode(img_data)
    img_np = np.frombuffer(img_bytes, np.uint8)
    img = cv.imdecode(img_np, cv.IMREAD_COLOR)

    # Convert image to grayscale
    img = cv.cvtColor(img, cv.COLOR_BGR2GRAY)
    
    # Adjust image contrast and brightness
    if brighten_val>=-127 and brighten_val<=127 \
        and contrast_val>-127 and contrast_val<127:
        img = cv.convertScaleAbs(img, alpha=contrast_val/127+1, beta=brighten_val)

    # Add blur to image
    if blur_val>0:
        img = cv.blur(img, (blur_val, blur_val))
    
    # Get image outline (outline = dilate - erode)
    kernel = np.ones((2,2),np.uint8)
    img = cv.morphologyEx(img, cv.MORPH_GRADIENT, kernel)

    # Invert image
    img = cv.bitwise_not(img)

    # Sharpen image
    if sharpen:
        kernel = np.array([[0, -1, 0], [-1, 5, -1], [0, -1, 0]])
        img = cv.filter2D(img, -1, kernel)
    
    # Convert image back to b64 string
    _,buf = cv.imencode(".png", img)
    img_data = str(base64.b64encode(buf), "utf-8")
    
    return img_data