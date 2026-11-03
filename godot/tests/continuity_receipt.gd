extends RefCounted
## Machine-readable observations from the actual Godot checks, not a second simulator.
var observations: Dictionary = {}

func record(description: String, passed: bool) -> void:
	if not observations.has(description):
		observations[description] = {"id": description.sha256_text().left(12), "description": description, "samples": 0, "failures": 0}
	observations[description].samples += 1
	if not passed: observations[description].failures += 1

func finish(suite: String, scope: String, context: Dictionary = {}) -> void:
	var checks := 0
	var failures := 0
	for item in observations.values():
		checks += item.samples
		failures += item.failures
	print("CONTINUITY_JSON:" + JSON.stringify({
		"schema": 1, "suite": suite, "scope": scope, "context": context,
		"checks": checks, "failures": failures, "status": "passed" if checks > 0 and failures == 0 else "failed",
		"observations": observations.values()
	}))
