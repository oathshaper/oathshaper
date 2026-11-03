extends SceneTree
## Actual ModelSlot timing at walking and keyboard travel speeds, in the quay.
var demo: Node3D
var player: CharacterBody3D
var camera: Camera3D
var tick := 0
func _initialize(): call_deferred('run')
func run():
 demo=load('res://scenes/demo.tscn').instantiate();root.add_child(demo)
 await process_frame
 demo.set_process(false)
 player=demo.get_node('Player');player.set_physics_process(false)
 demo.get_node('CameraRig').set_process(false)
 camera=demo.get_node('CameraRig/Camera3D');camera.current=true;camera.fov=45
 for child in demo.get_children():
  if child is CanvasLayer:child.visible=false
 player.position=Vector3(0,1.05,5)
 process_frame.connect(step)
func step():
 tick+=1
 if tick>540: quit();return
 var section=(tick-1)/180
 var speed=[1.5,4.5,2.0][mini(section,2)]
 player.rotation.y=0
 player.velocity=Vector3(0,0,-speed)
 # Move on the actual deck for each 3-second section; follow from a fixed angle.
 if tick%180==1:player.position=Vector3(0,1.05,5)
 player.position+=player.velocity/60.0
 camera.global_position=player.position+Vector3(2.5,1.2,3.5)
 camera.look_at(player.position+Vector3(0,.1,0))
