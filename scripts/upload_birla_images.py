"""
Upload Birla Opus product images to Supabase Storage and seed products table.

Usage:
  pip install supabase storage3
  python scripts/upload_birla_images.py
"""

import os
import uuid
import mimetypes
from supabase import create_client, Client

SUPABASE_URL = "https://mlzrqgocvenrwjnabljm.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1senJxZ29jdmVucndqbmFibGptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1NTg5NjEsImV4cCI6MjA4OTEzNDk2MX0.kcO8daZS3KM6keSZX-PlaShP_JRxJ2U0eUS5Nmn6AWA"
BUCKET_NAME = "paint-images"
IMAGES_ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Images")

# -------------------------------------------------------------------
# Mapping: folder_name -> (category, sub_category)
# -------------------------------------------------------------------
FOLDER_MAP = {
    "Luxury_interior":    ("Interior",        "Luxury Interior"),
    "Luxury_exterior":    ("Exterior",        "Luxury Exterior"),
    "Premium_interior":   ("Interior",        "Premium"),
    "Emulsion_interiors": ("Interior",        "Emulsion"),
    "Premium_exteriors":  ("Exterior",        "Premium"),
    "Emulsion_exteriors": ("Exterior",        "Emulsion"),
    "Premium_oil_paint":  ("Oil Paint",       "Premium"),
    "Emulsion_oil_paint": ("Oil Paint",       "Emulsion"),
    "Designer_finish":    ("Designer Finish", "Designer Finish"),
    "All_dry":            ("Alldry",          "Alldry"),
    "All_wood":           ("Allwood",         "Allwood"),
    "Putty":              ("Wall Putty",      "Wall Putty"),
}

def pretty_name(filename: str) -> str:
    """Convert a filename like 'premium_ever_clear_matt.png' -> 'Premium Ever Clear Matt'."""
    name = os.path.splitext(filename)[0]
    return name.replace("_", " ").title()


def get_content_type(filepath: str) -> str:
    ct, _ = mimetypes.guess_type(filepath)
    return ct or "application/octet-stream"


def main():
    sb: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

    # 0. Ensure category & sub_category columns exist in products table
    try:
        sb.rpc("exec_sql", {"query": "ALTER TABLE products ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'Interior';"}).execute()
        sb.rpc("exec_sql", {"query": "ALTER TABLE products ADD COLUMN IF NOT EXISTS sub_category TEXT DEFAULT 'Premium';"}).execute()
        print("Ensured category/sub_category columns exist.")
    except Exception as e:
        print(f"Note: Could not run ALTER TABLE via RPC (may need manual SQL): {e}")
        print("Please run the following SQL in Supabase SQL Editor:")
        print("  ALTER TABLE products ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'Interior';")
        print("  ALTER TABLE products ADD COLUMN IF NOT EXISTS sub_category TEXT DEFAULT 'Premium';")

    # 1. Ensure storage bucket exists
    try:
        sb.storage.get_bucket(BUCKET_NAME)
        print(f"Bucket '{BUCKET_NAME}' already exists.")
    except Exception:
        try:
            sb.storage.create_bucket(BUCKET_NAME, options={"public": True})
            print(f"Created bucket '{BUCKET_NAME}'.")
        except Exception as e:
            print(f"Could not create bucket (may already exist): {e}")

    # 2. Clear existing Birla Opus products to avoid duplicates
    try:
        sb.table("products").delete().eq("brand", "Birla Opus").execute()
        print("Cleared existing Birla Opus products for a clean seed.")
    except Exception as e:
        print(f"Note: Could not clear existing products: {e}")

    inserted = 0

    for folder, (category, sub_category) in FOLDER_MAP.items():
        folder_path = os.path.join(IMAGES_ROOT, folder)
        if not os.path.isdir(folder_path):
            print(f"⚠  Folder not found: {folder_path}")
            continue

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

            # Default prices (can be updated later via admin panel)
            if category == "Wall Putty":
                bucket_sizes = ["1kg", "30kg", "60kg"]
                prices = {"1kg": 20, "30kg": 450, "60kg": 850}
            else:
                bucket_sizes = ["1L", "4L", "10L", "20L"]
                prices = {"1L": 400, "4L": 1500, "10L": 3500, "20L": 6600}

            product_id = f"bo-{uuid.uuid4().hex[:8]}"

            product = {
                "id": product_id,
                "name": product_name,
                "brand": "Birla Opus",
                "category": category,
                "sub_category": sub_category,
                "color_code": "",
                "color_name": product_name,
                "color_hex": "#FFFFFF",
                "description": f"Birla Opus {category} - {sub_category}",
                "image_url": public_url,
                "bucket_sizes": bucket_sizes,
                "prices": prices,
                "stock_level": 100,
                "low_stock_threshold": 10,
            }

            try:
                sb.table("products").insert(product).execute()
                inserted += 1
                print(f"  ✔ Inserted product: {product_name} [{category}/{sub_category}]")
            except Exception as e:
                print(f"  ⚠ Insert error for {product_name}: {e}")

    print(f"\nDone! Inserted {inserted} products into Supabase.")


if __name__ == "__main__":
    main()
