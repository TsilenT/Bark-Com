extends RefCounted
class_name PropBuilder

## PropBuilder
##
## Helper to construct complex composite meshes from primitives.
## Used by DestructibleCover to build "Ambitious" procedural variants.

var root_node: Node3D
var _meshes: Array[MeshInstance3D] = []

func start():
	if root_node:
		root_node.queue_free()
	root_node = Node3D.new()
	root_node.name = "PropRoot"
	_meshes.clear()

func commit(parent: Node) -> Node3D:
	if not root_node:
		return null
	
	parent.add_child(root_node)
	var result = root_node
	
	# Reset for next usage
	root_node = null
	_meshes.clear()
	
	return result

static var _material_cache: Dictionary = {}

static func flush_cache():
	_material_cache.clear()

# --- Primitives ---

func add_box(pos: Vector3, size: Vector3, color: Color, rot_degrees: Vector3 = Vector3.ZERO, roughness: float = 0.8, metallic: float = 0.0) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	return _add_mesh(mesh, pos, color, rot_degrees, roughness, metallic)

func add_cylinder(pos: Vector3, radius: float, height: float, color: Color, rot_degrees: Vector3 = Vector3.ZERO, roughness: float = 0.5, metallic: float = 0.0) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return _add_mesh(mesh, pos, color, rot_degrees, roughness, metallic)

func add_sphere(pos: Vector3, radius: float, color: Color, roughness: float = 0.5, metallic: float = 0.0) -> MeshInstance3D:
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	return _add_mesh(mesh, pos, color, Vector3.ZERO, roughness, metallic)

func add_prism(pos: Vector3, size: Vector3, color: Color, rot_degrees: Vector3 = Vector3.ZERO, roughness: float = 0.5, metallic: float = 0.0) -> MeshInstance3D:
	var mesh = PrismMesh.new()
	mesh.size = size
	return _add_mesh(mesh, pos, color, rot_degrees, roughness, metallic)

# --- Internal ---

func _add_mesh(mesh_resource: Mesh, pos: Vector3, color: Color, rot: Vector3, roughness: float = 0.5, metallic: float = 0.0) -> MeshInstance3D:
	if not root_node:
		root_node = Node3D.new()
		root_node.name = "PropRoot"

	var mi = MeshInstance3D.new()
	mi.mesh = mesh_resource
	mi.position = pos
	mi.rotation_degrees = rot
	
	# Material Caching Logic
	var cache_key = str(color) + "_" + str(roughness) + "_" + str(metallic)
	var mat: StandardMaterial3D
	
	if _material_cache.has(cache_key):
		mat = _material_cache[cache_key]
	else:
		mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = roughness
		mat.metallic = metallic
		if color.a < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material_cache[cache_key] = mat
		
	mi.material_override = mat
	
	root_node.add_child(mi)
	_meshes.append(mi)
	return mi
