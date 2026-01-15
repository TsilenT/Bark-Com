class_name FieldManual
extends RefCounted

const TOPICS = ["Controls", "Guide", "Terminal", "Combat", "XP", "Sanity", "Bonds"]

static func get_content(topic: String) -> String:
	match topic:
		"Controls":
			return """
[b]CONTROLS[/b]

[color=yellow]Select Unit:[/color] Left Click
[color=yellow]Move:[/color] Click 'Move' or Press '1' -> Hover Tile -> Click
[color=yellow]Attack:[/color] Click 'Attack' or Press '2' -> Click Target
[color=yellow]Camera:[/color] WASD / Arrow Keys
[color=yellow]Rotate:[/color] Q / E
[color=yellow]Menu:[/color] ESC
"""
		"Guide":
			return """
[b]OPERATIONAL GUIDE[/b]
[color=cyan]The Golden Hydrant is under siege by Eldritch Monsters.[/color]
Your duty is to command the Bark-Commandos to hold the line.

[color=yellow]1. DEPLOY (Missions)[/color]
[color=green]Retrieval:[/color] Secure Treat Bags for supplies.
[color=green]Hacker:[/color] Corrupt their terminals.
[color=green]Rescue:[/color] Locate and save the VIP.
[color=green]Deathmatch:[/color] Clear the sector.

[color=yellow]2. PREPARE (Base)[/color]
Use Kibble to recruit new specialized dogs and buy gear.
- Visit the [b]Quartermaster[/b] for weapons and grenades.
- Visit [b]Therapy[/b] if your dogs are losing their minds (Low Sanity).

[color=yellow]3. DEFEND[/color]
The Eldritch Invasion meter fills over time.
When it hits 100%, they will attack the Base.
You MUST be ready.

[color=yellow]4. TERMINAL[/color]
Press [b]~ (Tilde)[/b] anytime to access the Command Terminal.
Use 'help' to see context-aware commands.
Example: 'recruit' (Base Only) or 'suicide' (Mission Only).

Good luck, Commander.
"""
		"Terminal":
			return """
[b]TERMINAL COMMANDS[/b]
Access via [color=yellow]~ (Tilde)[/color].

[color=yellow]Global[/color]
[color=cyan]help:[/color] List commands.
[color=cyan]clear:[/color] Clear terminal output.
[color=cyan]kibble:[/color] Check current resources.

[color=yellow]Base (Mission Control)[/color]
[color=cyan]recruit [class]:[/color] Recruit a new dog (Cost: 50).
  [i]Ex: 'recruit Sniper'[/i]
[color=cyan]mission:[/color] List available missions.
[color=cyan]start <id>:[/color] Launch mission by ID.
  [i]Ex: 'start 0'[/i]

[color=yellow]Tactical (In-Mission)[/color]
[color=red]suicide:[/color] Emergency Neural Link Termination (Self-Destruct).
"""
		"Combat":
			return """
[b]COMBAT MECHANICS[/b]

[color=yellow]Hit Chance[/color]
Base Accuracy - Enemy Defense - Cover - Distance Penalty.

[color=yellow]Cover Modifiers[/color]
[color=cyan]Half Cover:[/color] -20% Hit Chance (Low Walls)
[color=cyan]Full Cover:[/color] -40% Hit Chance (High Walls)
[color=red]Flanking:[/color] Generally negates cover bonus.

[color=yellow]High Ground[/color]
+15 Aim, +10% Crit Chance.

[color=yellow]Critical Hits[/color]
Deals 1.5x Damage and inflicts [color=purple]15 Sanity Damage[/color] to soldiers.
"""
		"XP":
			return """
[b]XP & PROGRESSION[/b]

[color=yellow]Gaining XP[/color]
[color=green]Kill:[/color] +50 XP (Awarded to killer)
[color=green]Mission Victory:[/color] +20 XP (Awarded to all survivors)

[color=yellow]Ranks[/color]
[color=cyan]Rank 1 (Rookie):[/color] 0 XP
[color=cyan]Rank 2 (Squaddie):[/color] 100 XP
[color=cyan]Rank 3 (Corporal):[/color] 300 XP
[color=cyan]Rank 4 (Sergeant):[/color] 600 XP
[color=cyan]Rank 5 (Lieutenant):[/color] 1000 XP

Leveling up grants +2 HP and unlocks new perks in the Skill Tree.
"""
		"Sanity":
			return """
[b]SANITY & PANIC[/b]

[color=yellow]Sanity[/color] represents mental resilience. Max 100.
Taking critical hits, witnessing death, or specific enemy attacks reduces Sanity.

[color=red]Panic States[/color] (Triggered at low Sanity)
[color=orange]Freeze:[/color] Skip turn (2 turns).
[color=orange]Run:[/color] Flee from enemies (2 turns).
[color=red]Berserk:[/color] Attack nearest target with bonus damage (1 turn).

[color=green]Recovery[/color]
Resting at base restores 10 Sanity per mission.
Dog Treats can restore Sanity in the field.
"""
		"Bonds":
			return """
[b]BONDS[/b]

Surviving missions together improves the bond between soldiers (+1 per mission).

[color=yellow]Combat Actions[/color]
[color=green]Heal Ally:[/color] +3 Bond Points
[color=green]Avenge Ally:[/color] +5 Bond Points (Kill an enemy actively targeting a squadmate)

[color=yellow]Bond Levels[/color]
[color=cyan]Lvl 1 - Buddies (10 pts):[/color] +5 Willpower.
[color=cyan]Lvl 2 - Packmates (25 pts):[/color] +10 Aim when near partner.
[color=cyan]Lvl 3 - Soul Pups (50 pts):[/color] [b]Berserk Vengeance[/b] (Enter Berserk instead of Panic if partner dies).
"""
	return "No content."
