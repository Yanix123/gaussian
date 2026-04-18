import shutil
import subprocess
from pathlib import Path


def try_convert_to_usdz(obj_path: str, out_path: str) -> tuple[bool, str]:
    converter = shutil.which("usdz_converter")
    if converter is None:
        return False, "usdz_converter not found"

    src = Path(obj_path)
    dst = Path(out_path)
    if not src.exists():
        return False, "Source OBJ does not exist"

    completed = subprocess.run(
        [converter, str(src), str(dst)],
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        return False, completed.stderr.strip() or "usdz conversion failed"

    return True, "USDZ conversion successful"
import subprocess


def convert_to_usdz(obj_path: str, out_path: str):
    subprocess.run([
        "usdz_converter",
        obj_path,
        out_path
    ], check=True)

    return out_path