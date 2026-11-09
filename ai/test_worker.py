import base64
import unittest
import worker


class WorkerChecks(unittest.TestCase):
    def setUp(self):
        self.photo = worker.np.zeros((240, 320, 3), worker.np.uint8)
        self.photo[:, :160] = [30, 90, 180]
        self.encoded = worker.jpeg(self.photo)

    def test_official_models_load_and_blank_selfies_are_rejected(self):
        self.assertTrue(worker.handle({"operation": "health"})["ready"])
        with self.assertRaisesRegex(ValueError, "one face"):
            worker.handle({"operation": "enroll", "imageBase64": self.encoded})

    def test_private_previews_are_watermarked_and_editing_changes_real_pixels(self):
        result = worker.handle({"operation": "prepare_photo", "imageBase64": self.encoded})
        self.assertEqual(result["faces"], [])
        self.assertNotEqual(result["originalBase64"], result["previewBase64"])
        edited = worker.handle({"operation": "render_photo", "imageBase64": self.encoded, "edits": {"rotation": 90, "filter": "mono", "sticker": {"type": "star", "x": .5, "y": .5, "scale": .1}}})
        self.assertEqual((edited["width"], edited["height"]), (240, 320))
        self.assertNotEqual(edited["imageBase64"], self.encoded)

    def test_ambiguous_matches_are_not_assigned_to_a_visitor(self):
        vector = [1.0] + [0.0] * 127
        result = worker.handle({"operation": "match_faces", "faces": [{"feature": vector}], "templates": [{"uid": "first", "feature": vector}, {"uid": "second", "feature": vector}]})
        self.assertEqual(result["matches"], [])
        unique = worker.handle({"operation": "match_faces", "faces": [{"feature": vector}], "templates": [{"uid": "first", "feature": vector}]})
        self.assertEqual(unique["matches"][0]["uid"], "first")

    def test_invalid_image_and_crop_do_not_return_a_download(self):
        with self.assertRaises(ValueError):
            worker.handle({"operation": "render_photo", "imageBase64": "not-an-image"})
        with self.assertRaises(ValueError):
            worker.handle({"operation": "render_photo", "imageBase64": self.encoded, "edits": {"crop": {"x": .9, "y": 0, "width": .8, "height": .8}}})


if __name__ == "__main__":
    unittest.main()
