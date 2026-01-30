extends Node3D

var faction = "Player"
var grid_pos = Vector2(0,0)
var current_ap = 2
var accuracy = 100
var primary_weapon = null
var max_hp = 10
var current_hp = 10
var inventory = []
var mobility = 10
var current_sanity = 100

func spend_ap(c): 
	current_ap -= c

func take_damage(d): 
	current_hp -= d

func heal(a): 
	current_hp += a

func trigger_bond_growth(target, amount): 
	pass
