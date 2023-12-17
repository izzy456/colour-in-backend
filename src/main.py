from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from image_function import create_colouring_page
import schemas

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/get-colour-in", response_model=schemas.ColourInResponse)
def get_colour_in(request: schemas.ColourInRequest):
    dataPrefix = request.image.split(",")[0]
    colouring_page = create_colouring_page(
        img_data=request.image.split(",")[1],
        blur_val=request.blur_val,
        light_val=request.light_val,
        dark_val=request.dark_val,
        sharpen=request.sharpen
        )

    return {
        "image": request.image,
        "blur_val": request.blur_val,
        "light_val": request.light_val,
        "dark_val": request.dark_val,
        "sharpen": request.sharpen,
        "colour_in": dataPrefix+","+colouring_page
        }