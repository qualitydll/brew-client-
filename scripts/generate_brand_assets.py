from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "images" / "brewicon.jpg"
ASSET_DIR = ROOT / "assets" / "images"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
WINDOWS_ICON = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"


def square_icon(image: Image.Image, size: int) -> Image.Image:
    image = image.convert("RGB")
    image = ImageOps.fit(
        image,
        (size, size),
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    )
    return image


def main() -> None:
    if not SOURCE.is_file():
        raise FileNotFoundError(f"Brand image not found: {SOURCE}")

    with Image.open(SOURCE) as original:
        original.load()
        # Keep the full composition for in-app branding and the README.
        ASSET_DIR.mkdir(parents=True, exist_ok=True)
        original.convert("RGB").save(ASSET_DIR / "brew_logo.png", format="PNG", optimize=True)

        # Android launcher icons use the same artwork cropped to a square.
        sizes = {
            "mipmap-mdpi": 48,
            "mipmap-hdpi": 72,
            "mipmap-xhdpi": 96,
            "mipmap-xxhdpi": 144,
            "mipmap-xxxhdpi": 192,
        }
        for folder, size in sizes.items():
            target_dir = ANDROID_RES / folder
            target_dir.mkdir(parents=True, exist_ok=True)
            square_icon(original, size).save(target_dir / "ic_launcher.png", format="PNG", optimize=True)

        # Windows reads the ICO referenced by Runner.rc.
        WINDOWS_ICON.parent.mkdir(parents=True, exist_ok=True)
        square_icon(original, 256).save(
            WINDOWS_ICON,
            format="ICO",
            sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
        )

    print("Generated Brew in-app logo, Android launcher icons, and Windows ICO from brewicon.jpg.")


if __name__ == "__main__":
    main()
