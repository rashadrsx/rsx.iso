# pip install pillow
from PIL import Image

image = Image.open("image.jpeg")
image.save("image.png")
