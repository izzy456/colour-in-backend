from typing import List, Optional
from pydantic import BaseModel

class ColourInRequest(BaseModel):
    image: str
    blur_val: int
    light_val: float
    dark_val: float
    sharpen: int

class ColourInResponse(ColourInRequest):
    colour_in: str