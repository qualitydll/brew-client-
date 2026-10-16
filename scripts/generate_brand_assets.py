from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "brewicon.png"
ASSET_DIR = ROOT / "assets" / "images"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
WINDOWS_ICON = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
BRAND_BACKGROUND = (30, 20, 16)


def trim_transparent_edges(image: Image.Image) -> Image.Image:
    """Trim transparent/near-transparent edge noise without cutting the artwork."""
    source = image.convert("RGBA")
    alpha = source.getchannel("A")
    # Ignore faint antialiasing and transparent export noise around the icon.
    mask = alpha.point(lambda value: 255 if value >= 96 else 0)
    bounds = mask.getbbox()
    return source.crop(bounds) if bounds else source


def square_icon(image: Image.Image, size: int) -> Image.Image:
    """Trim the supplied artwork and render a crisp square icon for each platform size."""
    source = trim_transparent_edges(image)
    inset = max(2, round(size * 0.07))
    fitted = ImageOps.contain(
        source,
        (size - inset * 2, size - inset * 2),
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
        original = trim_transparent_edges(original)
        ASSET_DIR.mkdir(parents=True, exist_ok=True)
        # Keep the in-app logo tightly cropped; platform launchers get their own
        # padded, square renders below rather than stretching the source image.
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
