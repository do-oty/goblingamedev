extends Node2D

@onready var tree_layer = $trees

var tree_tiles = [
	Vector2i(0, 0),  # replace these with your actual tree atlas coords
	Vector2i(1, 0),  # if you have multiple tree tile variants
]

var map_width := 50
var map_height := 50
var tree_count := 80
var source_id := 0  # usually 0, check your TileSet

func _ready():
	randomize()
	spawn_trees()

func spawn_trees():
	for i in tree_count:
		var x = randi_range(-map_width, map_width)
		var y = randi_range(-map_height, map_height)
		var random_tree = tree_tiles[randi() % tree_tiles.size()]
		tree_layer.set_cell(Vector2i(x, y), source_id, random_tree)
