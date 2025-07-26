import cloudinary
import cloudinary.uploader
import os
from dotenv import load_dotenv
load_dotenv()
def init_cloudinary():
    cloudinary.config(
        cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
        api_key=os.getenv("CLOUDINARY_API_KEY"),
        api_secret=os.getenv("CLOUDINARY_API_SECRET")
    )

def upload_image(image_bytes, public_id=None, folder=None):
    options = {}
    if public_id:
        options["public_id"] = public_id
    if folder:
        options["folder"] = folder
    return cloudinary.uploader.upload(image_bytes, **options)
