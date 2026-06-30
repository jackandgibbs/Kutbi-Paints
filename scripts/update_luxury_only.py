"""
Update only Luxury Interior and Luxury Exterior products for Birla Opus.
This script is a subset of the main upload script, focusing on the newly separated luxury folders.

Usage:
  pip install supabase storage3
  python scripts/update_luxury_only.py
"""

import os
import uuid
import mimetypes
from supabase import create_client, Client

SUPABASE_URL = "https://mlzrqgocvenrwjnabljm.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1senJxZ29jdmVucndqbmFibGptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1NTg5NjEsImV4cCI6MjA4OTEzNDk2MX0.kcO8daZS3KM6keSZX-PlaShP_JRxJ2U0eUS5Nmn6AWA"
BUCKET_NAME = "paint-images"
IMAGES_ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Images")

# Only mapping the luxury folders
FOLDER_MAP = {
    "Luxury_interior":    ("Interior", "Luxury Interior"),
    "Luxury_exterior":    ("Exterior", "Luxury Exterior"),
}

def pretty_name(filename: str) -> str:
    name = os.path.splitext(filename)[0]
    return name.replace("_", " ").title()

def get_content_type(filepath: str) -> str:
    ct, _ = mimetypes.guess_type(filepath)
    return ct or "application/octet-stream"

def main():
    sb: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

    # 1. Clear existing Luxury products for Birla Opus to avoid duplicates
    print("Clearing existing Birla Opus Luxury products...")
    try:
        # Delete any combination that might exist (Legacy 'Luxury' or the new specific ones)
        for sub in ["Luxury", "Luxury Interior", "Luxury Exterior"]:
            sb.table("products").delete().eq("brand", "Birla Opus").eq("sub_category", sub).execute()
        print("✔ Cleared existing luxury products.")
    except Exception as e:
        print(f"Note: Could not clear existing products: {e}")

    inserted = 0

    for folder, (category, sub_category) in FOLDER_MAP.items():
        folder_path = os.path.join(IMAGES_ROOT, folder)
        if not os.path.isdir(folder_path):
            print(f"⚠  Folder not found: {folder_path}")
            continue

        print(f"Processing folder: {folder} -> {category}/{sub_category}")

        for filename in sorted(os.listdir(folder_path)):
            filepath = os.path.join(folder_path, filename)
            if not os.path.isfile(filepath):
                continue

            product_name = pretty_name(filename)
            storage_path = f"birla_opus/{folder}/{filename}"
            content_type = get_content_type(filepath)

            # Upload to Supabase Storage
            try:
                with open(filepath, "rb") as f:
                    sb.storage.from_(BUCKET_NAME).upload(
                        path=storage_path,
                        file=f.read(),
                        file_options={"content-type": content_type, "upsert": "true"},
                    )
                print(f"  ✔ Uploaded {storage_path}")
            except Exception as e:
                print(f"  ⚠ Upload error for {storage_path}: {e}")

            # Build public URL
            public_url = f"{SUPABASE_URL}/storage/v1/object/public/{BUCKET_NAME}/{storage_path}"

            if category == "Wall Putty":
                bucket_sizes = ["1kg", "30kg", "60kg"]
                prices = {"1kg": 20, "30kg": 600, "60kg": 1100}
            else:
                bucket_sizes = ["1L", "4L", "10L", "20L"]
                prices = {"1L": 400, "4L": 1500, "10L": 3500, "20L": 6600}
            product_id = f"bo-{str(uuid.uuid4().hex)[:8]}"

            product = {
                "id": product_id,
                "name": product_name,
                "brand": "Birla Opus",
                "category": category,
                "sub_category": sub_category,
                "color_code": "",
                "color_name": product_name,
                "color_hex": "#FFFFFF",
                "description": f"Birla Opus luxury product for {category}",
                "image_url": public_url,
                "bucket_sizes": bucket_sizes,
                "prices": prices,
                "stock_level": 100,
                "low_stock_threshold": 10,
            }

            try:
                sb.table("products").insert(product).execute()
                inserted += 1
                print(f"  ✔ Inserted: {product_name}")
            except Exception as e:
                print(f"  ⚠ Insert error for {product_name}: {e}")

    print(f"\nDone! Updated {inserted} luxury products.")

if __name__ == "__main__":
    main()
