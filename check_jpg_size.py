import os


def convert_size(size_bytes):
    if size_bytes == 0:
        return "0B"
    size_name = ("B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB")
    i = int(math.floor(math.log(size_bytes, 1024)))
    p = math.pow(1024, i)
    s = round(size_bytes / p, 2)
    return f"{s} {size_name[i]}"


def list_jpg_files(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.lower().endswith(".jpg"):
                file_path = os.path.join(root, file)
                file_size = os.path.getsize(file_path)
                file_size_str = convert_size(file_size)
                print(f"File: {file_path}, Size: {file_size_str}")


if __name__ == "__main__":
    import math  # 添加 math 模块导入

    current_directory = os.getcwd()
    list_jpg_files(current_directory)
