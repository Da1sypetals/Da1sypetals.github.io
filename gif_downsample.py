from PIL import Image
import sys
import os
import math

def downsample_gif(input_path, ratio):
    # Open the GIF
    with Image.open(input_path) as img:
        # Calculate new size
        width, height = img.size
        new_width = math.floor(width * ratio)
        new_height = math.floor(height * ratio)
        
        # Downsample each frame
        frames = []
        try:
            while True:
                frame = img.copy()
                frame = frame.resize((new_width, new_height), Image.LANCZOS)
                frames.append(frame)
                img.seek(len(frames))  # Move to next frame
        except EOFError:
            pass  # End of sequence
        
        # Save downsampled GIF
        output_path = os.path.splitext(input_path)[0] + f"_downsampled{ratio}.gif"
        frames[0].save(
            output_path,
            save_all=True,
            append_images=frames[1:],
            loop=0,
            duration=img.info['duration'],
            disposal=img.disposal_method
        )
        return output_path

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python gif_downsample.py input.gif ratio")
        sys.exit(1)
        
    input_gif = sys.argv[1]
    ratio = float(sys.argv[2])
    
    if ratio <= 0 or ratio > 1:
        print("Ratio must be between 0 and 1")
        sys.exit(1)
        
    output_path = downsample_gif(input_gif, ratio)
    print(f"Downsampled GIF saved to: {output_path}")
