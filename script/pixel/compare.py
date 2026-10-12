#!/usr/bin/env python3
"""Compare a screenshot of OpenProject with the reference images in the repository.

usage: compare.py <screenshot.png> [--reference DIR] [--out DIR]

The screenshot is the work package table at 1440 x 1000. Two regions are compared, each against its own
reference image: the top bar and the sidebar. A pixel differs when any colour channel is more than
TOLERANCE away from the reference, which lets font smoothing pass. A region fails when more than its
limit of pixels differ.

Exit code: 0 when every region passes, 1 on a regression, 2 when the check could not run
(a missing file, a wrong size). A check that could not run never counts as a pass.
"""
import argparse
import os
import sys

from PIL import Image

WIDTH, HEIGHT = 1440, 1000
TOLERANCE = 24

# name: (left, top, right, bottom), and the share of pixels that may differ.
REGIONS = {
    "top-bar": ((0, 0, 1440, 68), 0.005),
    "sidebar": ((0, 68, 264, 1000), 0.010),
}


class CannotRun(Exception):
    pass


def load(path):
    if not os.path.isfile(path):
        raise CannotRun(f"missing file: {path}")
    return Image.open(path).convert("RGB")


def differing(image_a, image_b, tolerance=TOLERANCE):
    """The share of pixels that differ, and a mask image with those pixels in red."""
    if image_a.size != image_b.size:
        raise CannotRun(f"sizes differ: {image_a.size} against {image_b.size}")
    pixels_a, pixels_b = image_a.load(), image_b.load()
    width, height = image_a.size
    mask = Image.new("RGB", (width, height))
    out = mask.load()
    count = 0
    for y in range(height):
        for x in range(width):
            a, b = pixels_a[x, y], pixels_b[x, y]
            if max(abs(a[0] - b[0]), abs(a[1] - b[1]), abs(a[2] - b[2])) > tolerance:
                out[x, y] = (220, 0, 40)
                count += 1
            else:
                grey = 190 + (b[0] + b[1] + b[2]) // 12
                out[x, y] = (grey, grey, grey)
    return count / float(width * height), mask


def crop(screenshot, box):
    if screenshot.size != (WIDTH, HEIGHT):
        raise CannotRun(f"the screenshot is {screenshot.size}, it must be {(WIDTH, HEIGHT)}")
    return screenshot.crop(box)


def check(screenshot, reference_dir, out_dir=None, regions=REGIONS):
    """Returns a list of (name, share, limit, passed)."""
    results = []
    for name, (box, limit) in regions.items():
        reference = load(os.path.join(reference_dir, f"{name}.png"))
        share, mask = differing(reference, crop(screenshot, box))
        if out_dir:
            os.makedirs(out_dir, exist_ok=True)
            mask.save(os.path.join(out_dir, f"{name}-diff.png"))
        results.append((name, share, limit, share <= limit))
    return results


def write_references(screenshot, reference_dir, regions=REGIONS):
    os.makedirs(reference_dir, exist_ok=True)
    for name, (box, _limit) in regions.items():
        crop(screenshot, box).save(os.path.join(reference_dir, f"{name}.png"))


def main(argv=None):
    here = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(description="Compare a screenshot with the reference images.")
    parser.add_argument("screenshot")
    parser.add_argument("--reference", default=os.path.join(here, "reference"))
    parser.add_argument("--out", default=None, help="folder for images that show where the pixels differ")
    parser.add_argument("--write-reference", action="store_true",
                        help="cut the reference images from this screenshot, in place of comparing")
    args = parser.parse_args(argv)

    try:
        screenshot = load(args.screenshot)
        if args.write_reference:
            write_references(screenshot, args.reference)
            print(f"wrote {len(REGIONS)} reference images to {args.reference}")
            return 0
        results = check(screenshot, args.reference, args.out)
    except CannotRun as error:
        print(f"CANNOT RUN: {error}")
        return 2

    for name, share, limit, passed in results:
        print(f"{'ok  ' if passed else 'FAIL'} {name}: {share * 100:.2f}% of pixels differ, limit {limit * 100:.2f}%")
    return 0 if all(passed for *_rest, passed in results) else 1


if __name__ == "__main__":
    sys.exit(main())
