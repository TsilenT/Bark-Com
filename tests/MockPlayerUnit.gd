extends Node3D

var faction = "Player"
var grid_pos = Vector2(1,1)
var current_ap = 2
var current_hp = 10
var max_hp = 10
var current_sanity = 100
var vision_range = 8

func spend_ap(cost):
	current_ap -= cost
