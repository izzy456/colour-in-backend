import numpy as np
import cv2 as cv
import base64

def gamma_correction(gamma_val, img):
    invGamma = 1.0/gamma_val
    table = np.array([((i/255.0) ** invGamma) * 255
        for i in np.arange(0, 256)]).astype(np.uint8)
    return cv.LUT(img, table)

def create_colouring_page(img_data, blur_val=0, light_val=0, dark_val=0, sharpen=0):
    # Convert b64 image data to cv format
    img_bytes = base64.b64decode(img_data)
    img_np = np.frombuffer(img_bytes, np.uint8)
    img = cv.imdecode(img_np, cv.IMREAD_COLOR)

    # Convert image to grayscale
    img = cv.cvtColor(img, cv.COLOR_BGR2GRAY)

    # Add blur to image
    if blur_val>0:
        img = cv.blur(img, (blur_val, blur_val))

    # Get image outline (outline = dilate - erode)
    kernel = np.ones((2,2),np.uint8)
    img_result = cv.morphologyEx(img, cv.MORPH_GRADIENT, kernel)

    # Lighten image, get outline and combine with normal image outline
    if light_val>1:
        light_img = gamma_correction(light_val, img)
        light_img = cv.morphologyEx(light_img, cv.MORPH_GRADIENT, kernel)
        img_result = cv.bitwise_or(img_result, light_img)
    
    # Darken image, get outline and combine with normal+light image outline
    if dark_val>0 and dark_val<1:
        dark_img = gamma_correction(dark_val, img)
        dark_img = cv.morphologyEx(dark_img, cv.MORPH_GRADIENT, kernel)
        img_result = cv.bitwise_or(img_result, dark_img)

    # Invert image
    img_result = cv.bitwise_not(img_result)

    # Sharpen image
    if sharpen:
        kernel = np.array([[0, -1, 0], [-1, 5, -1], [0, -1, 0]])
        img_result = cv.filter2D(img_result, -1, kernel)
    
    # Convert image back to b64 string
    _,buf = cv.imencode(".jpg", img_result)
    img_data = str(base64.b64encode(buf), "utf-8")
    
    return img_data