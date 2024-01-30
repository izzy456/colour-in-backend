from pydantic import BaseModel

class ColourInRequest(BaseModel):
    image: str
    blur_val: int
    contrast_val: int
    brighten_val: int
    sharpen: int

class ColourInResponse(ColourInRequest):
    colour_in: str