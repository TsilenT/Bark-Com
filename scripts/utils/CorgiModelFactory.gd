extends RefCounted
class_name CorgiModelFactory

# Colors (Refined)
const COLOR_FUR_SABLE = Color(0.96, 0.62, 0.26) # SABLE (Orange/Tan)
const COLOR_FUR_WHITE = Color(0.98, 0.98, 0.98) # Bright White
const COLOR_NOSE = Color(0.1, 0.1, 0.1)

# Class Tints (Subtler now, applied to gear mostly or slight fur shift)
const TINT_SCOUT = Color(0.4, 0.7, 1.0)
const TINT_HEAVY = Color(0.3, 0.3, 0.35)
const TINT_MEDIC = Color(1.0, 1.0, 1.0)
const TINT_SNIPER = Color(0.25, 0.3, 0.2)
const TINT_GRENADIER = Color(0.6, 0.3, 0.1)


static func generate_corgi(unit_class: String, parent_node: Node3D) -> Dictionary:
	# Returns { "anim_player": AnimationPlayer, "sockets": Dictionary }
	
	var root = Node3D.new()
	root.name = "ModelRoot"
	parent_node.add_child(root)
	
	# --- MATERIALS ---
	var mat_sable = StandardMaterial3D.new()
	mat_sable.albedo_color = COLOR_FUR_SABLE
	
	# Subtle class tinting on the fur
	match unit_class:
		"Heavy": mat_sable.albedo_color = mat_sable.albedo_color.darkened(0.1)
		"Sniper": mat_sable.albedo_color = mat_sable.albedo_color.lerp(Color.DARK_OLIVE_GREEN, 0.1)
		"Scout": mat_sable.albedo_color = mat_sable.albedo_color.lightened(0.1)
	
	var mat_white = StandardMaterial3D.new()
	mat_white.albedo_color = COLOR_FUR_WHITE
	
	var mat_black = StandardMaterial3D.new()
	mat_black.albedo_color = Color.BLACK
	
	# --- ANATOMY: BODY (Long Boy) ---
	var body = MeshInstance3D.new()
	body.name = "Body"
	
	# Use Capsule but elongated
	var body_mesh = CapsuleMesh.new()
	body_mesh.radius = 0.32
	body_mesh.height = 1.3 # Longer!
	
	body.mesh = body_mesh
	body.material_override = mat_sable
	body.rotation.x = deg_to_rad(-90)
	body.position.y = 0.42
	root.add_child(body)
	
	# White Belly/Chest (A separate slightly larger mesh or intersecting?)
	# Let's add a "Bib" mesh.
	var bib = MeshInstance3D.new()
	bib.name = "Bib"
	var bib_mesh = CapsuleMesh.new()
	bib_mesh.radius = 0.325 # Slightly thicker to overlay
	bib_mesh.height = 0.6
	bib.mesh = bib_mesh
	bib.material_override = mat_white
	bib.position = Vector3(0, 0.25, 0.05) # Front underbelly
	bib.rotation.x = deg_to_rad(10) # Tilt to cover front chest
	body.add_child(bib)
	
	# --- ANATOMY: HEAD ---
	var head_pivot = Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0, 0.4, -0.55) # Extended neck/front
	root.add_child(head_pivot)
	
	var head = MeshInstance3D.new()
	head.name = "Head"
	
	# Box/Sphere Hybrid for broad skull
	var head_mesh = SphereMesh.new()
	head_mesh.radius = 0.35
	head_mesh.height = 0.65 # Wider
	head.mesh = head_mesh
	head.material_override = mat_sable
	head.position = Vector3(0, 0.3, 0)
	head.scale = Vector3(1.0, 0.85, 1.0) # Flatten top
	head_pivot.add_child(head)
	
	# Blaze (White Stripe on Face) -> Muzzle connection?
	
	# Snout (Narrower, Tapered)
	var snout = MeshInstance3D.new()
	var snout_mesh = CylinderMesh.new()
	snout_mesh.top_radius = 0.08 # Narrower tip
	snout_mesh.bottom_radius = 0.14 # Base
	snout_mesh.height = 0.28
	snout.mesh = snout_mesh
	snout.material_override = mat_white
	# Fix: Rotate -90 to point Forward (-Z) instead of +90 (Back)
	snout.position = Vector3(0, -0.05, -0.32)
	snout.rotation.x = deg_to_rad(-90) 
	head.add_child(snout)
	
	# Nose (Black Sphere)
	var nose = MeshInstance3D.new()
	var nose_mesh = SphereMesh.new()
	nose_mesh.radius = 0.05
	nose_mesh.height = 0.1
	nose.mesh = nose_mesh
	nose.material_override = mat_black
	# Cylinder is Y-up. Tip is Y=+0.14. 
	nose.position = Vector3(0, 0.14, 0.0) 
	snout.add_child(nose)
	
	# Blept (Maximum Derp)
	var tongue = MeshInstance3D.new()
	tongue.mesh = BoxMesh.new()
	tongue.mesh.surface_set_material(0, StandardMaterial3D.new())
	tongue.mesh.surface_get_material(0).albedo_color = Color(1.0, 0.4, 0.5)
	# Increased scale for more blep
	tongue.scale = Vector3(0.08, 0.02, 0.12)
	# Move to mouth area (lower part of snout face)
	tongue.position = Vector3(0, 0.11, -0.07) 
	# Fix Rotation: -125 to dangle down noticeably
	tongue.rotation.x = deg_to_rad(-125) 
	snout.add_child(tongue)

	# Ears (Larger, Less Buried)
	# User wants Bigger Equilateral
	var ear_mesh = PrismMesh.new()
	ear_mesh.size = Vector3(0.3, 0.3, 0.05) 
	
	# Raised Y to 0.33 so they aren't lost
	var ear_l = MeshInstance3D.new(); ear_l.mesh = ear_mesh; ear_l.material_override = mat_sable; ear_l.position = Vector3(-0.2, 0.33, 0.05); ear_l.rotation.z = deg_to_rad(15); ear_l.rotation.x = deg_to_rad(-10); head.add_child(ear_l)
	var ear_r = MeshInstance3D.new(); ear_r.mesh = ear_mesh; ear_r.material_override = mat_sable; ear_r.position = Vector3(0.2, 0.33, 0.05); ear_r.rotation.z = deg_to_rad(-15); ear_r.rotation.x = deg_to_rad(-10); head.add_child(ear_r)
	
	# Eyes
	var eye_mesh = SphereMesh.new()
	eye_mesh.radius = 0.06
	eye_mesh.height = 0.12 
	
	# Set Z back from -0.32 to -0.29 to sink them in slightly
	var eye_l = MeshInstance3D.new(); eye_l.mesh = eye_mesh; eye_l.material_override = mat_black; eye_l.position = Vector3(-0.16, 0.12, -0.29); head.add_child(eye_l)
	var eye_r = MeshInstance3D.new(); eye_r.mesh = eye_mesh; eye_r.material_override = mat_black; eye_r.position = Vector3(0.16, 0.12, -0.29); head.add_child(eye_r)
	
	# --- LEGS (Short & White) ---
	var leg_h = 0.35
	
	var leg_pos = [
		Vector3(-0.25, 0.175, 0.4), # Back L (Y must be positive!)
		Vector3(0.25, 0.175, 0.4),  # Back R
		Vector3(-0.25, 0.175, -0.35), # Front L
		Vector3(0.25, 0.175, -0.35)   # Front R
	]
	
	for i in range(4):
		var leg = MeshInstance3D.new()
		var lm = CylinderMesh.new()
		lm.top_radius = 0.12 
		lm.bottom_radius = 0.09
		lm.height = leg_h
		leg.mesh = lm
		leg.material_override = mat_white 
		leg.position = leg_pos[i]
		root.add_child(leg)
	
	# --- TAIL (Fox Brush) ---
	var tail = MeshInstance3D.new()
	tail.name = "Tail"
	var tail_mesh = CylinderMesh.new()
	tail_mesh.top_radius = 0.04 
	tail_mesh.bottom_radius = 0.12 
	tail_mesh.height = 0.5
	tail.mesh = tail_mesh
	tail.material_override = mat_sable
	
	# Reverted Position: Back to where it was (Y ~ -0.75 per user request)
	tail.position = Vector3(0, -0.75, 0.2) 
	
	# Fix Rotation: -45 deg X sends it "Up" relative to the "Back" vector of the Body.
	tail.rotation.x = deg_to_rad(-45) 
	body.add_child(tail)
	
	var tip = MeshInstance3D.new()
	var tip_m = SphereMesh.new(); tip_m.radius = 0.05; tip_m.height = 0.1 # Fix: Explicit height
	tip.mesh = tip_m; tip.material_override = mat_white
	tip.position.y = 0.25 
	tail.add_child(tip)
	
	# --- GEAR ---
	_add_class_gear(unit_class, root, head, body)
	
	# --- SOCKETS ---
	var sockets = {}
	
	var head_socket = Node3D.new()
	head_socket.name = "Socket_Head"
	head_socket.position = Vector3(0, 0.45, 0) # Higher on new head
	head.add_child(head_socket)
	sockets["Head"] = head_socket
	
	var neck_socket = Node3D.new()
	neck_socket.name = "Socket_Neck"
	neck_socket.position = Vector3(0, -0.3, 0.2)
	head.add_child(neck_socket)
	sockets["Neck"] = neck_socket
	
	var spine_socket = Node3D.new()
	spine_socket.name = "Socket_Spine"
	spine_socket.position = Vector3(0, 0.35, 0)
	body.add_child(spine_socket)
	sockets["Spine"] = spine_socket
	
	# --- ANIMATION ---
	var anim_player = _create_animation_player(root, body, head_pivot, tail)
	parent_node.add_child(anim_player)
	
	return {"anim_player": anim_player, "sockets": sockets}

# ... (Keep _add_class_gear and _create_animation_player, just update offsets if needed)
static func _add_class_gear(unit_class: String, root: Node3D, head: Node3D, body: Node3D):
	var mat_metal = StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.3, 0.3, 0.35); mat_metal.metallic = 0.8
	
	var mat_tech = StandardMaterial3D.new()
	mat_tech.albedo_color = Color(0.0, 0.8, 1.0)
	mat_tech.emission = Color(0.0, 0.8, 1.0)
	mat_tech.emission_enabled = true
	mat_tech.emission_energy_multiplier = 2.0
	
	var mat_cloth = StandardMaterial3D.new()
	mat_cloth.albedo_color = TINT_GRENADIER
	
	var mat_medic = StandardMaterial3D.new()
	mat_medic.albedo_color = Color(0.9, 0.9, 0.9)

	match unit_class:
		"Scout":
			# Scout AR Visor
			var visor_root = Node3D.new()
			# Default position
			visor_root.position = Vector3(0, 0.12, -0.32) 
			head.add_child(visor_root)

			# Materials
			var mat_glass = StandardMaterial3D.new(); 
			mat_glass.albedo_color = Color(0.0, 1.0, 1.0, 0.4); # Cyan Transparent
			mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat_glass.emission_enabled = true; mat_glass.emission = Color(0.0, 0.8, 0.8); mat_glass.emission_energy_multiplier = 0.5
			
			var mat_frame = StandardMaterial3D.new(); mat_frame.albedo_color = Color(0.15, 0.15, 0.18); mat_frame.metallic = 0.8
			
			# Visor Glass (Curved) - Use a segment of a tube? Or a flattened Cylinder?
			# A flattened Cylinder works well for a wrap-around look.
			var glass_mesh = CylinderMesh.new(); 
			glass_mesh.top_radius = 0.35; glass_mesh.bottom_radius = 0.35; glass_mesh.height = 0.12
			
			# Glass Pane
			var visor_glass = MeshInstance3D.new()
			visor_glass.mesh = glass_mesh; visor_glass.material_override = mat_glass
			# User Tweaked: GLASS: Pos((0.0, 0.0, 0.0)) Rot((90.0, 0.0, 180.0)) Scale((0.7, 0.52, 0.19))
			visor_glass.position = Vector3(0, 0, 0)
			visor_glass.rotation_degrees = Vector3(90, 0, 180)
			visor_glass.scale = Vector3(0.7, 0.52, 0.19)
			visor_root.add_child(visor_glass)
			
			# Tech Frame (Top bar)
			var frame_top = MeshInstance3D.new()
			var ft_mesh = BoxMesh.new(); ft_mesh.size = Vector3(0.44, 0.04, 0.08)
			frame_top.mesh = ft_mesh; frame_top.material_override = mat_frame
			frame_top.position = Vector3(0, 0.07, 0) # Top edge
			visor_root.add_child(frame_top)

			# Emitter/Battery (Side Pods)
			var pod_mesh = BoxMesh.new(); pod_mesh.size = Vector3(0.06, 0.1, 0.15)
			for x in [-1, 1]:
				var pod = MeshInstance3D.new(); pod.mesh = pod_mesh; pod.material_override = mat_frame
				pod.position = Vector3(0.22 * x, 0, 0.05) # Sides
				visor_root.add_child(pod)

			# Antenna (integrated)
			# Replaced old ant_base with integrated ant node below

			var ant = MeshInstance3D.new(); 
			ant.mesh = CylinderMesh.new(); ant.mesh.top_radius = 0.005; ant.mesh.bottom_radius = 0.005; ant.mesh.height = 0.25
			ant.material_override = mat_metal
			ant.position = Vector3(0.24, 0.15, 0) # Stick up from right pod
			visor_root.add_child(ant)
			

			
			var tip = MeshInstance3D.new(); var t_mesh = SphereMesh.new(); t_mesh.radius = 0.02; t_mesh.height=0.04
			tip.mesh = t_mesh; tip.material_override = mat_tech
			tip.position = Vector3(0, 0.2, 0)
			ant.add_child(tip)
			
		"Heavy":
			# "Riot Shield" Flank Plates - Radially positioned to curve around Body (Y-axis cylinder)
			# Slat Dimension: X=Thick, Y=Length (Along Dog), Z=Width (Arc coverage)
			# Actually, easier to use Z for length if we rotate them? 
			# Let's align Y with dog spine. So BoxMesh Y = Length.
			var slat_mesh = BoxMesh.new(); slat_mesh.size = Vector3(0.04, 0.7, 0.18) 
			var bolt_mesh = SphereMesh.new(); bolt_mesh.radius = 0.02; bolt_mesh.height = 0.04
			var mat_bolt = StandardMaterial3D.new(); mat_bolt.albedo_color = Color(0.2, 0.2, 0.2)
			
			var radius = 0.38 # Slightly larger than body 0.35 estimate
			
			for side in [-1, 1]:
				var plate_root = Node3D.new()
				plate_root.position = Vector3(0, 0, 0)
				body.add_child(plate_root)
				
				# 3 Slats Radial: Top (+35 deg), Mid (0), Bot (-35 deg) relative to X axis
				var angles = [35.0, 0.0, -35.0]
				
				for ang_deg in angles:
					var ang = deg_to_rad(ang_deg)
					var slat = MeshInstance3D.new(); slat.mesh = slat_mesh; slat.material_override = mat_metal
					
					# Position on Circle in X-Z plane (since Y is spine)
					# Side is +X or -X.
					# If side is 1 (+X): Angle goes up +Z.
					# If side is -1 (-X): Angle goes up +Z? 
					# We want symmetry. 
					# Base vector `(side, 0, 0)`.
					# Rotated by `ang` around Y? 
					# If ang is +35, vector (1,0,0) -> (cos 35, 0, -sin 35)? (Right Hand Y up)
					# Let's simple math: X = R * cos(ang), Z = R * sin(ang).
					# For side -1: X = -R * cos(ang), Z = R * sin(ang).
					
					var x_pos = radius * cos(ang) * side
					var z_pos = radius * sin(ang) 
					slat.position = Vector3(x_pos, 0, z_pos)
					
					# Rotation: Normal should face out.
					# Rotate around Y axis.
					# If ang=0, RotY=0.
					# If ang=35, RotY = -35 (to tilt face)?
					# Normal is (cos, 0, sin). Face X axis. 
					# RotY = -ang * side?
					slat.rotation.y = -ang * side
					plate_root.add_child(slat)
					
					# Bolts (Top/Bottom of slat Y)
					var b1 = MeshInstance3D.new(); b1.mesh = bolt_mesh; b1.material_override = mat_bolt
					b1.position = Vector3(0.025 * side, 0.3, 0) 
					slat.add_child(b1)
					var b2 = MeshInstance3D.new(); b2.mesh = bolt_mesh; b2.material_override = mat_bolt
					b2.position = Vector3(0.025 * side, -0.3, 0)
					slat.add_child(b2)
			
			# Armored Collar (Torus)
			var collar = MeshInstance3D.new()
			# Torus: Inner 0.38, Outer 0.55 (Thicker per request)
			var cm = TorusMesh.new(); cm.inner_radius = 0.38; cm.outer_radius = 0.55
			collar.mesh = cm; collar.material_override = mat_metal
			
			# Position (User Tweaked): Pos((0.0, -0.12, 0.1)) Rot(-42)
			collar.position = Vector3(0, -0.12, 0.1) 
			collar.rotation.x = deg_to_rad(-42)
			head.add_child(collar)
				
		"Paramedic":
			# Z is "Height" in World because Body is Rotated -90 X. 
			# Y is "Length" along body.
			# X is "Thickness".
			var bag_mesh = BoxMesh.new(); bag_mesh.size = Vector3(0.2, 0.4, 0.35) # Shorter height (Z=0.35)
			
			# Flap - Thin lid on top
			var flap_mesh = BoxMesh.new(); flap_mesh.size = Vector3(0.22, 0.4, 0.1) 
			
			var mat_red = StandardMaterial3D.new(); mat_red.albedo_color = Color(0.9, 0.1, 0.1)
			var mat_button = StandardMaterial3D.new(); mat_button.albedo_color = Color(1.0, 0.8, 0.2) # Gold button
			var button_mesh = CylinderMesh.new(); button_mesh.top_radius = 0.03; button_mesh.bottom_radius = 0.03; button_mesh.height = 0.02
			
			for x in [-1, 1]:
				var b = MeshInstance3D.new(); b.mesh = bag_mesh; b.material_override = mat_medic
				b.position = Vector3(0.42 * x, 0.05, -0.05); body.add_child(b) # Lowered Z slightly
				
				# Flap - On "Top" (Local +Z)
				var f = MeshInstance3D.new(); f.mesh = flap_mesh; f.material_override = mat_medic
				f.position = Vector3(0.0 * x, 0.0, 0.225); # Sit on top of bag (0.35/2 = 0.175 + half flap 0.05)
				b.add_child(f)
				
				# Button - On the outside face of the flap (+X)
				var btn = MeshInstance3D.new(); btn.mesh = button_mesh; btn.material_override = mat_button
				# Rotate to face out
				btn.rotation.z = deg_to_rad(90)
				btn.position = Vector3(0.12 * x, 0, 0) # Just barely poking out of flap X (0.11)
				f.add_child(btn)
				
				# Cross (Two Thin Boxes forming a +)
				# Scaled down to fit new height
				var v_bar = MeshInstance3D.new(); v_bar.mesh = BoxMesh.new(); v_bar.mesh.size = Vector3(0.02, 0.08, 0.2)
				v_bar.material_override = mat_red; v_bar.position = Vector3(0.11*x, 0, 0) # Poke out of bag
				b.add_child(v_bar)
				
				var h_bar = MeshInstance3D.new(); h_bar.mesh = BoxMesh.new(); h_bar.mesh.size = Vector3(0.02, 0.2, 0.08)
				h_bar.material_override = mat_red; h_bar.position = Vector3(0.11*x, 0, 0)
				b.add_child(h_bar)
			
			# OPTIONAL: Stethoscope Loop & Disc
			# Tube: Thin Torus around neck
			var steth_tube = MeshInstance3D.new()
			var tube_mesh = TorusMesh.new(); tube_mesh.inner_radius = 0.36; tube_mesh.outer_radius = 0.39 # Thin wire
			steth_tube.mesh = tube_mesh
			var mat_black = StandardMaterial3D.new(); mat_black.albedo_color = Color(0.1, 0.1, 0.1)
			steth_tube.material_override = mat_black
			# User Tweaked: Pos((0.0, -0.23, 0.17)) Rot(-54)
			steth_tube.position = Vector3(0, -0.23, 0.17)
			steth_tube.rotation.x = deg_to_rad(-54)
			head.add_child(steth_tube)
			
			# Chest Piece: Silver Disc
			var disc = MeshInstance3D.new()
			var disc_mesh = CylinderMesh.new(); disc_mesh.top_radius=0.06; disc_mesh.bottom_radius=0.06; disc_mesh.height=0.02
			disc.mesh = disc_mesh
			
			var mat_silver = StandardMaterial3D.new(); mat_silver.albedo_color = Color(0.85, 0.85, 0.9); mat_silver.metallic = 0.8; mat_silver.roughness = 0.2
			disc.material_override = mat_silver
			
			# User Tweaked: Pos((0.0, -0.02, -0.41)) Rot(150.65)
			# Note: -0.41 Z makes sense if it's hanging down? 
			disc.position = Vector3(0.0, -0.02, -0.41) 
			disc.rotation.x = deg_to_rad(150.65) 
			steth_tube.add_child(disc)
				
		"Sniper":
			# Ghillie Cape - Redesigned as Radial Segments to curve
			# Body Local: Y is Length, Z is Dorsal (Up)
			
			var cape_root = Node3D.new()
			# User Tweaked: Pos((0.0, -0.22, -0.04)) Rot(0.0)
			cape_root.position = Vector3(0.0, -0.22, -0.04)
			body.add_child(cape_root)
			
			var mat_camo = StandardMaterial3D.new(); mat_camo.albedo_color = Color(0.2, 0.35, 0.15)
			
			# Curvature: Wrap around Top arc (Z+)
			# Radius ~0.36 to sit on fur
			var radius = 0.38
			var segment_mesh = BoxMesh.new(); segment_mesh.size = Vector3(0.18, 0.9, 0.04) # Narrow strips
			var leaf_mesh = PrismMesh.new(); leaf_mesh.size = Vector3(0.08, 0.12, 0.04)
			var rng = RandomNumberGenerator.new(); rng.seed = 999
			
			# 5 Segments: -50, -25, 0, 25, 50 degrees
			var angles = [-50.0, -25.0, 0.0, 25.0, 50.0]
			
			for ang_deg in angles:
				var ang = deg_to_rad(ang_deg)
				var seg = MeshInstance3D.new(); seg.mesh = segment_mesh; seg.material_override = mat_camo
				
				# Math: In X-Z plane. Z is Up.
				# Angle 0 = Top (+Z).
				# Angle +90 = Right (+X)?
				# X = R * sin(ang)
				# Z = R * cos(ang)
				
				seg.position = Vector3(radius * sin(ang), 0, radius * cos(ang))
				# Rotate to face normal out.
				# RotY is around body length (axis).
				# Positive RotY moves Z+ (Normal) towards +X.
				# Our Pos X is sin(ang). If ang > 0, X > 0.
				# We want Normal to point +X. So Rot should be +ang.
				seg.rotation.y = ang # Tilt around spine to match Normal
				
				cape_root.add_child(seg)
				
				# Leaves on this segment
				for i in range(3):
					var l = MeshInstance3D.new(); l.mesh = leaf_mesh; l.material_override = mat_camo
					l.position = Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.4, 0.4), 0.03)
					l.rotation = Vector3(rng.randf(), rng.randf(), rng.randf())
					seg.add_child(l)

			# Tactical Scope
			var scope_root = Node3D.new()
			head.add_child(scope_root)
			
			# Strap (Thin Torus around head)
			var strap = MeshInstance3D.new()
			var sm = TorusMesh.new(); sm.inner_radius=0.36; sm.outer_radius=0.38
			strap.mesh = sm; var mat_blk = StandardMaterial3D.new(); mat_blk.albedo_color = Color.BLACK; strap.material_override = mat_blk
			# User Tweaked: Pos((0.15, 0.15, 0.0)) Rot(0, 0, -41) Scale(0.73)
			strap.position = Vector3(0.15, 0.15, 0.0)
			strap.rotation = Vector3(0, 0, deg_to_rad(-41))
			strap.scale = Vector3(0.73, 0.73, 0.73)
			scope_root.add_child(strap)

			# Scope Housing
			var housing = MeshInstance3D.new()
			# Stubbier and Wider: 
			# Height reduced (0.15 -> 0.08)
			# Radius increased (0.045 -> 0.065) to cover eye
			var hm = CylinderMesh.new(); hm.top_radius=0.06; hm.bottom_radius=0.065; hm.height=0.08
			housing.mesh = hm; housing.material_override = mat_metal
			# User Tweaked: Pos((0.16, 0.12, -0.3)) Rot((-90.0, 0.0, 0.0))
			housing.position = Vector3(0.16, 0.12, -0.3)
			housing.rotation_degrees = Vector3(-90, 0, 0)
			scope_root.add_child(housing)
			
			# Lens
			var lens = MeshInstance3D.new()
			# Widen lens to match housing
			var lm = CylinderMesh.new(); lm.top_radius=0.055; lm.bottom_radius=0.055; lm.height=0.02
			lens.mesh = lm
			var mat_glass = StandardMaterial3D.new(); mat_glass.albedo_color = Color(0.2, 0.8, 1.0); mat_glass.metallic=0.9; mat_glass.roughness=0.1
			lens.material_override = mat_glass
			lens.position = Vector3(0, 0.045, 0) # Tip of housing (0.04 + small offset)
			housing.add_child(lens)
			
		"Grenadier":
			# Bandolier (Sash)
			var sash = MeshInstance3D.new()
			# Length (Y)=0.9? Width (X)=0.6? 
			# We want a ring around the body, but diagonal. 
			# Torus is easiest for a "Ring" around a cylinder body.
			var sash_mesh = TorusMesh.new(); sash_mesh.inner_radius=0.42; sash_mesh.outer_radius=0.48 # Flat strap
			# Flatten it to look like a strap? Scale Y axis
			sash.mesh = sash_mesh; 
			var mat_g = StandardMaterial3D.new(); mat_g.albedo_color = Color(0.3, 0.2, 0.1) # Leather
			sash.material_override = mat_g
			
			# User Tweaked: SASH: Pos((0.0, 0.0, 0.0)) Rot(7.8, 0.0, 35.2) ScaleZ(0.77)
			sash.position = Vector3(0, 0, 0) 
			sash.rotation_degrees = Vector3(7.8, 0, 35.2)
			sash.scale.z = 0.77
			body.add_child(sash)
			
			# Grenades attached to Sash
			var nade_holder = Node3D.new()
			# User Tweaked: GROUP: Pos((0.0, 0.19, 0.0)) Rot((90.0, 0.0, 180.0))
			nade_holder.position = Vector3(0.0, 0.19, 0.0)
			nade_holder.rotation_degrees = Vector3(90, 0, 180)
			sash.add_child(nade_holder)
			
			var nade_mesh = SphereMesh.new(); nade_mesh.radius = 0.08; nade_mesh.height = 0.16
			var mat_nade = StandardMaterial3D.new(); mat_nade.albedo_color = Color(0.1, 0.4, 0.1)
			
			for i in range(3):
				var nade = MeshInstance3D.new(); nade.mesh = nade_mesh; nade.material_override = mat_nade
				# Attach to sash
				# Sash radius is ~0.45.
				# Position along ring: Angle
				var ang = deg_to_rad(-40 + i * 40) # Spread out
				var r = 0.45
				# Sash is in X-Y plane (before rotation).
				nade.position = Vector3(r * cos(ang), r * sin(ang), 0.15) # Stick out
				
				# Counter scale: Sash Z is 0.77. We want Nade Z to be ~1 (relative to world) or slightly flattened.
				# If Sash Z is 0.77, then Nade Scale Z = 1/0.77 = 1.3
				nade.scale = Vector3(1, 1, 1.3) 
				nade_holder.add_child(nade)

			# Blast Goggles
			var glasses = Node3D.new()
			glasses.position = Vector3(0, 0.12, 0.3) # Forehead
			head.add_child(glasses)
			
			# Strap
			var g_strap = MeshInstance3D.new()
			var sm = TorusMesh.new(); sm.inner_radius=0.36; sm.outer_radius=0.4
			g_strap.mesh = sm; g_strap.material_override = mat_g # Leather
			# User Tweaked: Strap: pos y = 0.07, pos z -0.28, rot x = 0, scale = 0.8
			g_strap.position = Vector3(0, 0.07, -0.28)
			g_strap.rotation_degrees.x = 0
			g_strap.scale = Vector3(0.8, 0.8, 0.8)
			glasses.add_child(g_strap)
			
			# Lenses Holder
			var lenses_root = Node3D.new()
			# User Tweaked: LENSES: Pos((0.0, 0.0, -1.05)) Rot((-180.0, 0.0, 0.0)) Scale(1.23)
			lenses_root.position = Vector3(0.0, 0.0, -1.05)
			lenses_root.rotation_degrees = Vector3(-180, 0, 0)
			lenses_root.scale = Vector3(1.23, 1.23, 1.23)
			glasses.add_child(lenses_root)
			
			# Lenses Geometry (Match Sniper Monocle style)
			var mat_lens = StandardMaterial3D.new(); mat_lens.albedo_color = Color(1.0, 0.6, 0.0); mat_lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat_lens.albedo_color.a = 0.6
			var mat_rim = StandardMaterial3D.new(); mat_rim.albedo_color = Color(0.2, 0.2, 0.2)
			
			# Housing/Rim Mesh (Outer)
			var housing_mesh = CylinderMesh.new(); housing_mesh.top_radius=0.06; housing_mesh.bottom_radius=0.065; housing_mesh.height=0.08
			# Lens Glass Mesh (Inner)
			var glass_mesh = CylinderMesh.new(); glass_mesh.top_radius=0.055; glass_mesh.bottom_radius=0.055; glass_mesh.height=0.02
			
			for x in [-1, 1]:
				var housing = MeshInstance3D.new(); housing.mesh = housing_mesh; housing.material_override = mat_rim
				housing.position = Vector3(0.15 * x, 0.4, 0) # Stick out front relative to strap center? 
				# We will adjust this via sliders. Start somewhere reasonable.
				# Glasses root is at forehead. 
				# If we put them at local 0,0,0 they are inside the head.
				# Strap is at local 0,0,0.
				# So we want Lenses to be "in front" (Z+) of the strap?
				# Wait, head looks at -Z? No, head looks +Z (Nose is +Z usually? Or -Z?)
				# Corgi Head: Nose is -Z? Let's check. 
				# Sniper Scope was at Z -0.28. So -Z is forward.
				# So "Front" of strap is -Z (if strap is around head).
				# But Strap is a Torus at 0,0,0. 
				# Let's put lenses at Z -0.35 (Front of face).
				housing.position = Vector3(0.12 * x, 0.0, -0.38) 
				housing.rotation.x = deg_to_rad(90) # Face forward
				
				var lens = MeshInstance3D.new(); lens.mesh = glass_mesh; lens.material_override = mat_lens
				lens.position = Vector3(0, 0.045, 0) # Tip of housing
				housing.add_child(lens)
				
				lenses_root.add_child(housing)


static func _create_animation_player(root: Node, body: Node, head_pivot: Node, tail: Node) -> AnimationPlayer:
	var anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	var lib = AnimationLibrary.new()
	
	# -- IDLE --
	var idle = Animation.new(); idle.loop_mode = Animation.LOOP_LINEAR; idle.length = 2.0
	var t_s = idle.add_track(Animation.TYPE_VALUE)
	idle.track_set_path(t_s, str(root.name) + "/" + str(body.name) + ":scale")
	idle.track_insert_key(t_s, 0.0, Vector3(1.0, 1.0, 1.0))
	idle.track_insert_key(t_s, 1.0, Vector3(1.02, 1.02, 1.0))
	idle.track_insert_key(t_s, 2.0, Vector3(1.0, 1.0, 1.0))
	
	var t_tl = idle.add_track(Animation.TYPE_VALUE)
	idle.track_set_path(t_tl, str(root.name) + "/" + str(body.name) + "/Tail:rotation:z")
	idle.track_insert_key(t_tl, 0.0, deg_to_rad(-10)); idle.track_insert_key(t_tl, 1.0, deg_to_rad(10)); idle.track_insert_key(t_tl, 2.0, deg_to_rad(-10))
	lib.add_animation("Idle", idle)
	
	# -- RUN --
	var run = Animation.new(); run.loop_mode = Animation.LOOP_LINEAR; run.length = 0.3
	var t_p = run.add_track(Animation.TYPE_VALUE)
	run.track_set_path(t_p, str(root.name) + "/" + str(body.name) + ":position:y")
	run.track_insert_key(t_p, 0.0, 0.42); run.track_insert_key(t_p, 0.15, 0.55); run.track_insert_key(t_p, 0.3, 0.42)
	
	var t_r = run.add_track(Animation.TYPE_VALUE)
	run.track_set_path(t_r, str(root.name) + "/" + str(body.name) + ":rotation:x")
	run.track_insert_key(t_r, 0.0, deg_to_rad(-90)); run.track_insert_key(t_r, 0.15, deg_to_rad(-100)); run.track_insert_key(t_r, 0.3, deg_to_rad(-90))
	lib.add_animation("Run", run)
	
	# -- ATTACK --
	var atk = Animation.new(); atk.length = 0.5
	var t_a = atk.add_track(Animation.TYPE_VALUE)
	atk.track_set_path(t_a, str(root.name) + ":position:z")
	atk.track_insert_key(t_a, 0.0, 0.0); atk.track_insert_key(t_a, 0.1, -0.8); atk.track_insert_key(t_a, 0.4, 0.0)
	lib.add_animation("Attack", atk)
	
	anim.add_animation_library("", lib)
	return anim
