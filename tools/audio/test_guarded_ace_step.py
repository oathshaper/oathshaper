"""Lightweight supervisor regressions; no model imports or inference."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

import psutil
import guarded_ace_step as guard


class GuardTests(unittest.TestCase):
    def setUp(self):
        self.state = dict(available_bytes=5 * guard.GIB,
                          system_disk_free_bytes=40 * guard.GIB,
                          swap_used_bytes=5 * guard.GIB, pressure=1)

    def test_quantized_retry_allows_bounded_warning(self):
        self.assertFalse(guard.preflight_reasons(dict(self.state, pressure=2), True))
        self.assertTrue(guard.preflight_reasons(self.state))  # full precision needs more RAM

    def test_preflight_rejects_exhausted_reserves_and_unknown_pressure(self):
        for field, value in (("pressure", 4), ("pressure", 0),
                             ("available_bytes", 3 * guard.GIB),
                             ("swap_used_bytes", 13 * guard.GIB),
                             ("system_disk_free_bytes", 29 * guard.GIB)):
            with self.subTest(field=field, value=value):
                self.assertTrue(guard.preflight_reasons(dict(self.state, **{field: value}), True))

    def test_exit_accounting_race_preserves_success(self):
        # Observed on macOS: task accounting disappears while poll() is still
        # None. Reaping the child must complete the report without an exception.
        child = Mock(pid=987654, returncode=None)
        child.poll.side_effect = lambda: child.returncode

        def reap(timeout=None):
            child.returncode = 0
            return 0

        child.wait.side_effect = reap
        process = Mock()
        process.memory_info.side_effect = psutil.NoSuchProcess(child.pid)
        with tempfile.TemporaryDirectory() as directory:
            argv = ["guard", "--repo", directory, "--data", directory,
                    "--checkpoint-dir", directory, "--quantized-mlx"]
            with patch("sys.argv", argv), patch.object(guard, "snapshot", return_value=self.state), \
                 patch.object(guard.subprocess, "Popen", return_value=child), \
                 patch.object(guard.psutil, "Process", return_value=process), patch("builtins.print"):
                self.assertEqual(guard.main(), 0)
            reports = list(Path(directory).glob("outputs/*/guard.json"))
            self.assertEqual(len(reports), 1)
            report = json.loads(reports[0].read_text())
            self.assertEqual(report["status"], "completed")
            self.assertEqual(report["exit_code"], 0)

    def test_stop_only_signals_dedicated_process_group(self):
        child = Mock(pid=987654)
        with patch.object(guard.os, "killpg") as kill:
            guard.stop_trial(child)
            kill.assert_called_once_with(child.pid, guard.signal.SIGTERM)
            child.wait.assert_called_once_with(timeout=3)


if __name__ == "__main__":
    unittest.main()
