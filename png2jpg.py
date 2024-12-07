import os
from PIL import Image


def convert_png_to_jpg(directory):
    for root, _, files in os.walk(directory):
        for file in files:
            if file.lower().endswith(".png"):
                png_path = os.path.join(root, file)
                jpg_path = os.path.splitext(png_path)[0] + ".jpg"

                try:
                    # Open the .png file
                    with Image.open(png_path) as img:
                        # Convert to RGB (required for JPEG format)
                        rgb_img = img.convert("RGB")
                        # Save as .jpg
                        rgb_img.save(jpg_path, "JPEG")
                        print(f"Converted: {png_path} -> {jpg_path}")
                except Exception as e:
                    print(f"Failed to convert {png_path}: {e}")

    # Ask user if they want to delete the .png files
    confirm_delete = (
        input("Do you want to delete the original .png files? (yes/no): ")
        .strip()
        .lower()
    )
    if confirm_delete.lower() in ["yes", "y"]:
        for root, _, files in os.walk(directory):
            for file in files:
                if file.lower().endswith(".png"):
                    png_path = os.path.join(root, file)
                    try:
                        os.remove(png_path)
                        print(f"Deleted: {png_path}")
                    except Exception as e:
                        print(f"Failed to delete {png_path}: {e}")
    else:
        print("No files were deleted.")


if __name__ == "__main__":
    # Start conversion in the current directory
    convert_png_to_jpg(".")
    print("Now you should Ctrl-Shift-F and replace all `.png` with `.jpg`.")
