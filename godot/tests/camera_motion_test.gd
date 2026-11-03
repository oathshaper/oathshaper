extends SceneTree
## Real garden geometry with staged actor paths: camera continuity, not battle AI.
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
 checks += 1
 if not ok: failures += 1; push_error(message)
func run():
 var trial := preload("res://scripts/command_trial.gd").new()
 trial.preview_mode = true
 root.add_child(trial)
 trial.set_process(false)
 trial.stage.set_process(false)
 await physics_frame
 var stage = trial.stage
 var target_id := ""
 for actor in trial.state.actors:
  if actor.faction == "hostile": target_id = actor.id; break
 assert(target_id != "")
 stage._state.party.selected_target_id = target_id
 stage.recenter_camera()
 var start: Vector3 = stage.actors[target_id].position
 var maximum_step := 0.0
 var maximum_turn := 0.0
 stage._position_camera(1.0/60.0) # Initial placement before measuring motion.
 var previous: Transform3D = stage.camera.transform
 for frame in range(720):
  # Small crossing movements used to keep changing the duel axis and shoulder.
  if frame > 180: stage.actors[target_id].position = start + Vector3(sin(frame*.02)*1.1, 0, cos(frame*.02)*.5)
  stage._position_camera(1.0/60.0)
  var now: Transform3D = stage.camera.transform
  maximum_step = maxf(maximum_step, previous.origin.distance_to(now.origin))
  maximum_turn = maxf(maximum_turn, previous.basis.get_rotation_quaternion().angle_to(now.basis.get_rotation_quaternion()))
  check(stage.camera_candidates_last_frame <= stage.CAMERA_SEARCH_BUDGET, "Obstruction search stays within the frame budget")
  previous = now
 check(maximum_step <= stage.CAMERA_TRAVEL_SPEED/60.0 + .001, "Automatic camera never jumps to a candidate: %.4fm/frame"%maximum_step)
 check(maximum_turn < deg_to_rad(8), "Automatic camera has no single-frame direction snap: %.3f degrees"%rad_to_deg(maximum_turn))
 var yaw: float = stage._yaw
 for frame in range(120):
  stage.actors[target_id].position = start + Vector3(cos(frame*.1)*2,0,sin(frame*.1)*2)
  stage._position_camera(1.0/60.0)
 check(absf(angle_difference(yaw,stage._yaw)) < .001,"Enemy movement does not reselect the camera shoulder")
 print("CAMERA_MOTION: %d checks, %d failures; max step %.4fm, max turn %.3f degrees"%[checks,failures,maximum_step,rad_to_deg(maximum_turn)])
 trial.free()
 quit(1 if failures else 0)
