import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("acceptance", Path(__file__).with_name("test-exported-demo.py"))
acceptance = importlib.util.module_from_spec(spec)
spec.loader.exec_module(acceptance)


class DiagnosticBoundaryTests(unittest.TestCase):
    def test_known_dummy_diagnostic_is_still_failure_on_real_renderer(self):
        diagnostic = 'ERROR: Parameter "m" is null.\n   at: mesh_get_surface_count (servers/rendering/dummy/storage/mesh_storage.h:120)'
        self.assertEqual(acceptance.classify_errors(diagnostic, True), ([], [diagnostic.replace('\n   ', ' ')]))
        self.assertEqual(len(acceptance.classify_errors(diagnostic, False)[0]), 1)

    def test_script_failure_and_other_null_errors_are_never_exempt(self):
        for log in ['SCRIPT ERROR: Assertion failed', 'ERROR: Parameter "m" is null.',
                    'ERROR: Parameter "m" is null.\n at: another_call (game.gd:120)',
                    'ERROR: 10 resources still in use at exit']:
            with self.subTest(log=log):
                self.assertEqual(len(acceptance.classify_errors(log, True)[0]), 1)


if __name__ == "__main__":
    unittest.main()
