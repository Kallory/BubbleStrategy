extends Sprite2D

const BOARD_SIZE = 9
const CELL_WIDTH = 19

const TEXTURE_HOLDER = preload("res://Scenes/texture_holder.tscn")

const PLAYER2_BUBBLE = preload("res://Assets/player2_bubble.png")
const PLAYER2_BUBBLE_LVL2 = preload("res://Assets/player2_bubble_2.png")
const PLAYER2_BUBBLE_LVL3 = preload("res://Assets/player2_bubble_3.png")
const PLAYER2_BUBBLE_LVL4 = preload("res://Assets/player2_bubble_4.png")

const PLAYER1_BUBBLE = preload("res://Assets/player1_bubble.png")
const PLAYER1_BUBBLE_LVL2 = preload("res://Assets/player1_bubble_2.png")
const PLAYER1_BUBBLE_LVL3 = preload("res://Assets/player1_bubble_3.png")
const PLAYER1_BUBBLE_LVL4 = preload("res://Assets/player1_bubble_4.png")

const TURN_PLAYER1 = preload("res://Assets/turn-player1.png")
const TURN_PLAYER2 = preload("res://Assets/turn-player2.png")

const PIECE_MOVE = preload("res://Assets/Piece_move.png")
const BUBBLE_MOVE_SOUND = preload("res://Assets/Bubble Move.wav")
const BUBBLE_CREATE_SOUND = preload("res://Assets/Bubble Appear Fill.wav")
const BUBBLE_PROMOTE_SOUND = preload("res://Assets/Bubble Rank Up.wav")
const BUBBLE_COMBAT_SOUND = preload("res://Assets/Bubble Combat V4.wav")
const BUBBLE_DESTROYED_SOUND = preload("res://Assets/Bubble Burst.wav")
const BUBBLE_MERGED_SOUND = preload("res://Assets/Bubble Merge.wav")

@onready var pieces = $Pieces
@onready var dots = $Dots
@onready var turn = $Turn

@onready var player1_pieces = $"../CanvasLayer/player1_pieces"
@onready var player2_pieces = $"../CanvasLayer/player2_pieces"

# Piece codes:
# -1 = player2 bubble lvl 1
# -2 = player2 bubble lvl 2
# -3 = player2 bubble lvl 3
# -4 = player2 bubble lvl 4

#  0 = empty
#  1 = player1 bubble lvl 1
#  2 = player1 bubble lvl 2
#  3 = player1 bubble lvl 3
#  4 = player1 bubble lvl 4


var board : Array = []
var player1 : bool = true

# We'll just use a single variable to track if a piece is currently selected
var is_selected = false
var selected_piece : Vector2 = Vector2(-1, -1)
var moves = []

var player1_base_pos = Vector2(0, 8)
var player2_bubble_pos = Vector2(8, 0)
var player1_base = Vector2(0, 8)
var player2_base = Vector2(8, 0)

var bubble_move_player: AudioStreamPlayer
var bubble_create_sound: AudioStreamPlayer
var bubble_promote_sound: AudioStreamPlayer
var bubble_combat_sound: AudioStreamPlayer
var bubble_destroyed_sound: AudioStreamPlayer
var bubble_merged_sound: AudioStreamPlayer

func _ready():
	# Initialize empty board
	for row in range(BOARD_SIZE):
		var row_array = []
		for col in range(BOARD_SIZE):
			row_array.append(0)
		board.append(row_array)

	# Place bases, initial bubble
	board[0][8] = 1
	board[8][0] = -1
	
	display_board()
	
	var player1_buttons = get_tree().get_nodes_in_group("player1_pieces")
	var player2_buttons = get_tree().get_nodes_in_group("player2_pieces")
	for button in player1_buttons:
		button.pressed.connect(self._on_button_pressed.bind(button))
	for button in player2_buttons:
		button.pressed.connect(self._on_button_pressed.bind(button))
		
	var music_player = AudioStreamPlayer.new()
	var music_stream = preload("res://Assets/background_music.mp3")
	music_player.stream = music_stream
	music_stream.loop = true
	#music_player.autoplay = true
	add_child(music_player)
	
	bubble_move_player = AudioStreamPlayer.new()
	bubble_move_player.stream = BUBBLE_MOVE_SOUND  # BUBBLE_MOVE_SOUND = preload("res://Assets/Bubble Move.wav")
	add_child(bubble_move_player)
	
	bubble_create_sound = AudioStreamPlayer.new()
	bubble_create_sound.stream = BUBBLE_CREATE_SOUND
	add_child(bubble_create_sound)
	
	bubble_promote_sound = AudioStreamPlayer.new()
	bubble_promote_sound.stream = BUBBLE_PROMOTE_SOUND
	add_child(bubble_promote_sound)
	
	bubble_combat_sound = AudioStreamPlayer.new()
	bubble_combat_sound.stream = BUBBLE_COMBAT_SOUND
	add_child(bubble_combat_sound)
	
	bubble_destroyed_sound = AudioStreamPlayer.new()
	bubble_destroyed_sound.stream = BUBBLE_DESTROYED_SOUND
	add_child(bubble_destroyed_sound)
	
	bubble_merged_sound = AudioStreamPlayer.new()
	bubble_merged_sound.stream = BUBBLE_MERGED_SOUND
	add_child(bubble_merged_sound)


func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			# Right-click => just deselect, no turn change
			deselect()
			return
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if is_mouse_out():
				return

			var var1 = int(get_global_mouse_position().x / CELL_WIDTH)
			var var2 = int(abs(get_global_mouse_position().y) / CELL_WIDTH)

			var piece_code = board[var2][var1]
			#print(str(var2) + ", " + str(var1))
			print("Strength = " + str(piece_code))
			
			# 1) If nothing is selected:
			if not is_selected:
				if player1 and Vector2(var2, var1) == player1_base and board[var2][var1] == 0:
					board[var2][var1] = 1 
					print("New Player1 bubble created at base!")
					bubble_create_sound.play()
					end_turn()
					return  
				
				if not player1 and Vector2(var2, var1) == player2_base and board[var2][var1] == 0:
					board[var2][var1] = -1
					print("New player2 bubble created at base")
					bubble_create_sound.play()
					end_turn()
					return
				
				# If it belongs to the current player
				if (player1 and piece_code > 0) or (not player1 and piece_code < 0):
					selected_piece = Vector2(var2, var1)
					is_selected = true
					show_options()
				# else: do nothing if we clicked an empty square or enemy piece
			else:
				# 2) If a piece is already selected
				if selected_piece == Vector2(var2, var1) and (selected_piece == player1_base or selected_piece == player2_base) and abs(piece_code) < 4:
					# Same piece => "oxygen +1" + end turn
					var success = promote_bubble(selected_piece)
					if success:
						end_turn()
				else:
					# Try to move
					set_move(var2, var1)

func promote_bubble(pos: Vector2):
	var code = board[pos.x][pos.y]
	var done_something = true
	
	if code == 1:
		# Player 1 bubble goes from lvl 1 (1) -> lvl 2 (2)
		board[pos.x][pos.y] = 2
		print("Promoted Player 1 bubble to level 2!")
		bubble_promote_sound.play()
	elif code == -1:
		# Player 2 bubble goes from lvl 1 (-1) -> lvl 2 (-2)
		board[pos.x][pos.y] = -2
		print("Promoted Player 2 bubble to level 2!")
		bubble_promote_sound.play()
	elif code == 2:
		# Player 1 bubble goes from lvl 2 -> lvl 3
		board[pos.x][pos.y] = 3
		print("Bubble promoted 2 -> 3")
		bubble_promote_sound.play()
	elif code == -2:
		# Player 2 bubble goes from lvl 2 -> lvl 3
		board[pos.x][pos.y] = -3
		print("Bubble promoted 2 -> 3")
		bubble_promote_sound.play()
	elif code == 3:
		# Player 1 bubble goes from lvl 3 -> lvl 4
		board[pos.x][pos.y] = 4
		print("Bubble promoted 3 -> 4")
		bubble_promote_sound.play()
	elif code == -3:
		# Player 2 bubble goes from lvl 3 -> lvl 4
		board[pos.x][pos.y] = -4
		print("Bubble promoted 3 -> 4")
		bubble_promote_sound.play()
	else:
		# If it's not a level 1 bubble, do nothing or handle differently
		print("No promotion possible.")
		done_something = false
	
	display_board()
	return done_something

func is_mouse_out():
	return not get_rect().has_point(to_local(get_global_mouse_position()))

func display_board():
	for child in pieces.get_children():
		child.queue_free()
	
	for i in range(BOARD_SIZE):
		for j in range(BOARD_SIZE):
			var holder = TEXTURE_HOLDER.instantiate()
			pieces.add_child(holder)
			holder.global_position = Vector2(
				j * CELL_WIDTH + (CELL_WIDTH / 2),
				-i * CELL_WIDTH - (CELL_WIDTH / 2)
			)
				
			# UPDATE TO ADD MORE LEVELS TO BUBBLES
			match board[i][j]:
				-1:
					holder.texture = PLAYER2_BUBBLE
				-2:
					holder.texture = PLAYER2_BUBBLE_LVL2
				-3:
					holder.texture = PLAYER2_BUBBLE_LVL3
				-4:
					holder.texture = PLAYER2_BUBBLE_LVL4
				1:
					holder.texture = PLAYER1_BUBBLE
				2:
					holder.texture = PLAYER1_BUBBLE_LVL2
				3:
					holder.texture = PLAYER1_BUBBLE_LVL3
				4:
					holder.texture = PLAYER1_BUBBLE_LVL4
				_:
					holder.texture = null
	
	if player1:
		turn.texture = TURN_PLAYER1
	else:
		turn.texture = TURN_PLAYER2

func show_options():
	moves = get_moves(selected_piece)
	if moves == []:
		# If no moves, just deselect
		deselect()
		return
	
	show_dots()

func show_dots():
	for pos in moves:
		var holder = TEXTURE_HOLDER.instantiate()
		dots.add_child(holder)
		holder.texture = PIECE_MOVE
		holder.global_position = Vector2(
			pos.y * CELL_WIDTH + (CELL_WIDTH / 2),
			-pos.x * CELL_WIDTH - (CELL_WIDTH / 2)
		)

func delete_dots():
	for child in dots.get_children():
		child.queue_free()

func set_move(target_row, target_col):
	
	var did_move = false
	for move_pos in moves:
		# case 1, no enemy, no friend
		if move_pos == Vector2(target_row, target_col) and not is_enemy(move_pos) and not is_friend(move_pos):
			# We found a valid move, no enemy
			did_move = true
			# Move piece on board
			board[target_row][target_col] = board[selected_piece.x][selected_piece.y]
			board[selected_piece.x][selected_piece.y] = 0
			
			# If it's a bubble, record its position
			if board[target_row][target_col] == 1:
				player1_base_pos = Vector2(target_row, target_col)
			elif board[target_row][target_col] == -1:
				player2_bubble_pos = Vector2(target_row, target_col)
			
			bubble_move_player.play()
			break
		# case 2, enemy is occupied, combat
		elif move_pos == Vector2(target_row, target_col) and is_enemy(move_pos):
			# selected piece is current player's piece, move_pos is where the enemy is
			var winner = handle_combat(selected_piece, move_pos)
			# player1 attacks and wins
			if player1 and winner > 0:
				board[selected_piece.x][selected_piece.y] = winner
				board[target_row][target_col] = board[selected_piece.x][selected_piece.y]
				board[selected_piece.x][selected_piece.y] = 0
			# player1 attacks and loses
			elif player1 and winner < 0:
				board[selected_piece.x][selected_piece.y] = 0
				board[target_row][target_col] = winner
			# player2 attacks and wins
			elif not player1 and winner < 0:
				board[selected_piece.x][selected_piece.y] = winner
				board[target_row][target_col] = board[selected_piece.x][selected_piece.y]
				board[selected_piece.x][selected_piece.y] = 0
			# player2 attacks and loses
			elif not player1 and winner > 0:
				board[selected_piece.x][selected_piece.y] = 0
				board[target_row][target_col] = winner
			# pieces are equal
			else:
				board[selected_piece.x][selected_piece.y] = 0
				board[target_row][target_col] = 0
				
			did_move = true
			break
			
		# case 3, friend is in occupied position, merge
		
		elif move_pos == Vector2(target_row, target_col) and is_friend(move_pos):
			var success = handle_merge(selected_piece, move_pos)
			if success:
				did_move = true
			break
	
	delete_dots()
	deselect()

	if did_move:
		# If we actually moved => end the turn
		end_turn()
		display_board()
	# else, we clicked an invalid move => no turn change

func handle_combat(attacker: Vector2, defender: Vector2):
	print("FIGHT!")
	bubble_combat_sound.play()
	bubble_destroyed_sound.play()
	# 1 get our piece_code at the selected pos
	print("attacker at: " + str(board[attacker.x][attacker.y]))
	var attacking_bubble_strength = abs(board[attacker.x][attacker.y])
	# 2 get enemy piece_code at the select pos
	print("defender at: " + str(board[defender.x][defender.y]))
	var defending_bubble_strength = abs(board[defender.x][defender.y])
	# 3 do math
	var result
	# case 1, attacker bigger than defender
	if (attacking_bubble_strength > defending_bubble_strength):
		result = attacking_bubble_strength - defending_bubble_strength
		if (player1):
			return board[attacker.x][attacker.y] - defending_bubble_strength
		else:
			return board[attacker.x][attacker.y] + defending_bubble_strength
	# case 2, defender stronger
	elif (attacking_bubble_strength < defending_bubble_strength):
		result = defending_bubble_strength - attacking_bubble_strength
		print("attacker less than defender, result = " + str(defending_bubble_strength) + " - " + str(attacking_bubble_strength) + " = " + str(result))
		if (player1):
			return board[defender.x][defender.y] + attacking_bubble_strength
		else:
			return board[defender.x][defender.y] - attacking_bubble_strength
	# case 3, same strength
	else:
		result = 0
		return result
	
	# 4 bigger piece wins, subtracting loser's piece_code from it
	# so set_move will do board[target_row][target_col] = result


func handle_merge(posA: Vector2, posB: Vector2) -> bool:
	print("MERGE!")
	bubble_merged_sound.play()
	
	var codeA = board[posA.x][posA.y]  # The moving bubble
	var codeB = board[posB.x][posB.y]  # The bubble on the tile we're merging into

	var new_level = abs(codeA) + abs(codeB)
	if new_level > 4:
		print("Cannot merge; resulting bubble would exceed level 4. Doing nothing.")
		return false  # Merge not performed

	var sign = signf(codeB)  # Keep the sign of the bubble at posB (the 'destination')
	board[posB.x][posB.y] = int(new_level * sign)
	board[posA.x][posA.y] = 0
	print("Merge complete! Now tile", posB, "has code", board[posB.x][posB.y])
	return true  # Merge succeeded

func deselect():
	is_selected = false
	selected_piece = Vector2(-1, -1)
	moves.clear()
	delete_dots()

# -------------------------------------------------------
# UNIFY ALL "END OF TURN" LOGIC IN THIS SINGLE FUNCTION!
# -------------------------------------------------------
func end_turn():
	player1 = not player1
	deselect()
	# Optionally do a board redraw if you want immediate feedback
	display_board()
	# print("Turn ended. Now it is " + (player1 ? "White" : "Black") + "'s turn.")

# -------------------------------------------------
# Only call the bubble's movement logic in get_moves!
# -------------------------------------------------
func get_moves(piece_position : Vector2):
	var piece_value = board[piece_position.x][piece_position.y]
	var _moves = []

	if abs(piece_value) > 0:
		_moves = get_bubble_moves(piece_position)
	else:
		_moves = []
	
	return _moves

func get_bubble_moves(piece_position : Vector2):
	var _moves = []
	var directions = [
		Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0),
		Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)
	]
	
	for direction in directions:
		var pos = piece_position + direction
		if is_valid_position(pos):
			if is_empty(pos) or is_enemy(pos) or is_friend(pos):
				_moves.append(pos)
	return _moves

func is_valid_position(pos : Vector2):
	return pos.x >= 0 and pos.x < BOARD_SIZE and pos.y >= 0 and pos.y < BOARD_SIZE

func is_empty(pos : Vector2):
	return board[pos.x][pos.y] == 0

func is_enemy(pos : Vector2):
	if player1 and board[pos.x][pos.y] < 0:
		return true
	elif not player1 and board[pos.x][pos.y] > 0:
		return true
	return false

func is_friend(pos : Vector2):
	if player1 and board[pos.x][pos.y] > 0:
		return true
	elif not player1 and board[pos.x][pos.y] < 0:
		return true
	return false

# The rest of your unused logic can remain or be stripped out
func _on_button_pressed(button):
	pass
