"""Unit tests for script/pixel/compare.py. Run: python3 -m unittest discover -s test/pixel"""
import os
import sys
import tempfile
import unittest

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "script", "pixel"))
import compare  # noqa: E402


def page(top_bar=(54, 105, 165), sidebar=(255, 255, 255)):
    image = Image.new("RGB", (compare.WIDTH, compare.HEIGHT), (245, 246, 248))
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, 1439, 67), fill=top_bar)
    draw.rectangle((0, 68, 263, 999), fill=sidebar)
    return image


class CompareTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.reference = os.path.join(self.dir.name, "reference")
        compare.write_references(page(), self.reference)

    def tearDown(self):
        self.dir.cleanup()

    def save(self, image, name="shot.png"):
        path = os.path.join(self.dir.name, name)
        image.save(path)
        return path

    def test_the_same_page_passes(self):
        self.assertEqual(0, compare.main([self.save(page()), "--reference", self.reference]))

    def test_a_small_colour_shift_within_the_tolerance_passes(self):
        self.assertEqual(0, compare.main([self.save(page(top_bar=(60, 110, 170))), "--reference", self.reference]))

    def test_another_top_bar_colour_fails(self):
        self.assertEqual(1, compare.main([self.save(page(top_bar=(0, 70, 153))), "--reference", self.reference]))

    def test_a_higher_top_bar_fails_in_both_regions(self):
        image = page()
        ImageDraw.Draw(image).rectangle((0, 0, 1439, 80), fill=(54, 105, 165))
        results = dict((name, passed) for name, _share, _limit, passed in compare.check(image, self.reference))
        self.assertFalse(results["sidebar"])
        self.assertTrue(results["top-bar"], "the top bar region itself still has the bar's colour")

    def test_a_change_outside_both_regions_passes(self):
        image = page()
        ImageDraw.Draw(image).rectangle((400, 200, 1400, 900), fill=(0, 0, 0))
        self.assertEqual(0, compare.main([self.save(image), "--reference", self.reference]))

    def test_a_few_pixels_pass_and_a_block_fails(self):
        few = page()
        ImageDraw.Draw(few).rectangle((10, 10, 20, 20), fill=(255, 255, 255))
        block = page()
        ImageDraw.Draw(block).rectangle((0, 100, 263, 300), fill=(0, 0, 0))
        self.assertEqual(0, compare.main([self.save(few), "--reference", self.reference]))
        self.assertEqual(1, compare.main([self.save(block), "--reference", self.reference]))

    def test_a_screenshot_of_the_wrong_size_cannot_run(self):
        small = Image.new("RGB", (1280, 800), (0, 0, 0))
        self.assertEqual(2, compare.main([self.save(small), "--reference", self.reference]))

    def test_a_missing_screenshot_or_reference_cannot_run(self):
        self.assertEqual(2, compare.main([os.path.join(self.dir.name, "nope.png"), "--reference", self.reference]))
        self.assertEqual(2, compare.main([self.save(page()), "--reference", os.path.join(self.dir.name, "empty")]))

    def test_it_writes_images_that_show_the_difference(self):
        out = os.path.join(self.dir.name, "out")
        compare.main([self.save(page(top_bar=(0, 0, 0))), "--reference", self.reference, "--out", out])
        self.assertEqual(["sidebar-diff.png", "top-bar-diff.png"], sorted(os.listdir(out)))
        self.assertEqual((220, 0, 40), Image.open(os.path.join(out, "top-bar-diff.png")).getpixel((5, 5)))

    def test_write_reference_cuts_both_regions(self):
        target = os.path.join(self.dir.name, "fresh")
        self.assertEqual(0, compare.main([self.save(page()), "--reference", target, "--write-reference"]))
        self.assertEqual((1440, 68), Image.open(os.path.join(target, "top-bar.png")).size)
        self.assertEqual((264, 932), Image.open(os.path.join(target, "sidebar.png")).size)


if __name__ == "__main__":
    unittest.main()
