from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_bad_image():
    test_req = {
        "image": "bad_image",
        "blur_val": 1,
        "contrast_val": 1,
        "brighten_val": 1,
        "sharpen": 1
    }
    response = client.post("/get-colour-in", json=test_req)
    assert response.status_code == 500