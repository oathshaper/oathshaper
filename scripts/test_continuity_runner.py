"""The reporting boundary must never turn missing evidence into a pass."""
import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("runner", Path(__file__).with_name("check-continuity.py"))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class ContinuityRunnerTests(unittest.TestCase):
    def test_missing_or_malformed_evidence_is_not_passed(self):
        for output in ["", "ordinary output", "CONTINUITY_JSON:[]", 'CONTINUITY_JSON:{"schema":1,"checks":12,"failures":0,"status":"passed"}']:
            self.assertEqual(runner.classify("engine", 0, output)[0], "incomplete")

    def test_timeout_or_budget_is_incomplete(self):
        self.assertEqual(runner.classify("command", None, "")[0], "incomplete")
        self.assertEqual(runner.classify("matrix", 2, '{"complete_within_scope":false}')[0], "incomplete")

    def test_colored_engine_diagnostics_are_counted_and_scoped(self):
        known = '\x1b[1;31mERROR:\x1b[0;91m Parameter "m" is null.\n at: mesh_get_surface_count (servers/rendering/dummy/storage/mesh_storage.h:120)'
        self.assertEqual(runner.engine_diagnostics(known)["known_count"], 1)
        self.assertEqual(runner.classify("command", 0, known)[0], "passed")
        different_origin = known.replace("servers/rendering/dummy/storage/mesh_storage.h:120", "gameplay/combat.gd:20")
        self.assertEqual(runner.classify("command", 0, different_origin)[0], "failed")
        self.assertEqual(runner.classify("command", 0, '\x1b[1;31mSCRIPT ERROR:\x1b[0m bad camera')[0], "failed")

    def test_receipt_counts_must_match_observations(self):
        receipt = {"schema":1,"checks":8,"failures":0,"status":"passed","observations":[{"samples":1,"failures":0}]}
        self.assertEqual(runner.classify("engine", 0, "CONTINUITY_JSON:" + json.dumps(receipt))[0], "incomplete")

    def test_script_error_overrides_a_successful_counter(self):
        receipt = {"schema":1,"checks":1,"failures":0,"status":"passed","observations":[{"samples":1,"failures":0}]}
        output = "CONTINUITY_JSON:" + json.dumps(receipt)
        self.assertEqual(runner.classify("engine", 0, output)[0], "passed")
        self.assertEqual(runner.classify("engine", 0, output + "\nSCRIPT ERROR: bad camera")[0], "failed")
        self.assertEqual(runner.classify("engine", 1, output)[0], "failed")

    def test_warning_does_not_silently_become_contract_failure(self):
        receipt = {"complete_within_scope":True,"findings":[{"certainty":"heuristic_suspicion"}]}
        self.assertEqual(runner.classify("matrix", 0, json.dumps(receipt))[0], "passed")
        self.assertEqual(runner.classify("dialogue-script", 0, json.dumps(receipt))[0], "passed")
        incomplete = dict(receipt, complete_within_scope=False)
        self.assertEqual(runner.classify("dialogue-script", 2, json.dumps(incomplete))[0], "incomplete")
        receipt["findings"][0]["certainty"] = "contract_violation"
        self.assertEqual(runner.classify("matrix", 0, json.dumps(receipt))[0], "failed")


if __name__ == "__main__": unittest.main()
