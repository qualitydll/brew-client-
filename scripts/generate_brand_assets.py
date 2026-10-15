from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "brewicon.png"
ASSET_DIR = ROOT / "assets" / "images"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
WINDOWS_ICON = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
BRAND_BACKGROUND = (30, 20, 16)


def square_icon(image: Image.Image, size: int) -> Image.Image:
    """Fit the complete original artwork on a square Brew-colored canvas."""
    source = image.convert("RGBA")
    fitted = ImageOps.contain(
        source,
        (size - max(2, size // 12), size - max(2, size // 12)),
        method=Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", (size, size), (*BRAND_BACKGROUND, 255))
    canvas.alpha_composite(
        fitted,
        ((size - fitted.width) // 2, (size - fitted.height) // 2),
    )
    return canvas.convert("RGB")


def main() -> None:
    if not SOURCE.is_file():
        raise FileNotFoundError(f"Brand image not found: {SOURCE}")

    with Image.open(SOURCE) as original:
        original.load()
        ASSET_DIR.mkdir(parents=True, exist_ok=True)
        original.save(ASSET_DIR / "brew_logo.png", format="PNG", optimize=True)

        android_nodpi = ANDROID_RES / "drawable-nodpi"
        android_nodpi.mkdir(parents=True, exist_ok=True)
        original.save(android_nodpi / "brewicon.png", format="PNG", optimize=True)

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
            square_icon(original, size).save(
                target_dir / "ic_launcher.png",
                format="PNG",
                optimize=True,
            )

        WINDOWS_ICON.parent.mkdir(parents=True, exist_ok=True)
        square_icon(original, 256).save(
            WINDOWS_ICON,
            format="ICO",
            sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
        )

    print("Generated Brew artwork and platform icons from brewicon.png.")


if __name__ == "__main__":
    main()
