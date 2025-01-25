extends Sprite2D

const BOARD_SIZE = 8
const CELL_WIDTH = 18

const TEXTURE_HOLDER = preload("res://Scenes/texture_holder.tscn")

const BLACK_KING = preload("res://Assets/black_king.png")
const WHITE_KING = preload("res://Assets/white_king.png")

const TURN_WHITE = preload("res://Assets/turn-white.png")
const TURN_BLACK = preload("res://Assets/turn-black.png")

const PIECE_MOVE = preload("res://Assets/Piece_move.png")

@onready var pieces = $Pieces
@onready var dots = $Dots
@onready var turn = $Turn

@onready var white_pieces = $"../CanvasLayer/white_pieces"
@onready var black_pieces = $"../CanvasLayer/black_pieces"

# Piece codes:
# -6 = black king
# -5 = black queen
# -4 = black rook
# -3 = black bishop
# -2 = black knight
# -1 = black pawn
#  0 = empty
#  6 = white king
#  5 = white queen
#  4 = white rook
#  3 = white bishop
#  2 = white knight
#  1 = white pawn

var board : Array = []
var white : bool = true

# We'll just use a single variable to track if a piece is currently selected
var is_selected = false
var selected_piece : Vector2 = Vector2(-1, -1)
var moves = []

var white_king_pos = Vector2(0, 4)
var black_king_pos = Vector2(7, 4)

# (Other booleans unused for now)
var fifty_move_rule = 0
var unique_board_moves : Array = []
var amount_of_same : Array = []

func _ready():
	# Initialize empty board
	for row in range(BOARD_SIZE):
		var row_array = []
		for col in range(BOARD_SIZE):
			row_array.append(0)
		board.append(row_array)

	# Place kings
	board[0][4] = 6
	board[7][4] = -6

	display_board()
	
	var white_buttons = get_tree().get_nodes_in_group("white_pieces")
	var black_buttons = get_tree().get_nodes_in_group("black_pieces")
	for button in white_buttons:
		button.pressed.connect(self._on_button_pressed.bind(button))
	for button in black_buttons:
		button.pressed.connect(self._on_button_pressed.bind(button))
		
	var music_player = AudioStreamPlayer.new()
	var music_stream = preload("res://Assets/background_music.mp3")
	music_player.stream = music_stream
	music_stream.loop = true
	music_player.autoplay = true
	add_child(music_player)


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
			
			# 1) If nothing is selected:
			if not is_selected:
				# If it belongs to the current player
				if (white and piece_code > 0) or (not white and piece_code < 0):
					selected_piece = Vector2(var2, var1)
					is_selected = true
					show_options()
				# else: do nothing if we clicked an empty square or enemy piece
			else:
				# 2) If a piece is already selected
				if selected_piece == Vector2(var2, var1):
					# Same piece => "oxygen +1" + end turn
					print("oxygen +1")
					end_turn()
				else:
					# Try to move
					set_move(var2, var1)

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
			
			match board[i][j]:
				-6:
					holder.texture = BLACK_KING
				6:
					holder.texture = WHITE_KING
				_:
					holder.texture = null
	
	if white:
		turn.texture = TURN_WHITE
	else:
		turn.texture = TURN_BLACK

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
		if move_pos == Vector2(target_row, target_col):
			# We found a valid move
			did_move = true
			# Move piece on board
			board[target_row][target_col] = board[selected_piece.x][selected_piece.y]
			board[selected_piece.x][selected_piece.y] = 0
			
			# If it's a king, record its position
			if board[target_row][target_col] == 6:
				white_king_pos = Vector2(target_row, target_col)
			elif board[target_row][target_col] == -6:
				black_king_pos = Vector2(target_row, target_col)
			
			break
	
	delete_dots()
	deselect()

	if did_move:
		# If we actually moved => end the turn
		end_turn()
		display_board()
	# else, we clicked an invalid move => no turn change

func deselect():
	is_selected = false
	selected_piece = Vector2(-1, -1)
	moves.clear()
	delete_dots()

# -------------------------------------------------------
# UNIFY ALL "END OF TURN" LOGIC IN THIS SINGLE FUNCTION!
# -------------------------------------------------------
func end_turn():
	white = not white
	deselect()
	# Optionally do a board redraw if you want immediate feedback
	display_board()
	# print("Turn ended. Now it is " + (white ? "White" : "Black") + "'s turn.")

# -------------------------------------------------
# Only call the king's movement logic in get_moves!
# -------------------------------------------------
func get_moves(piece_position : Vector2):
	var piece_value = board[piece_position.x][piece_position.y]
	var _moves = []

	if abs(piece_value) == 6:
		_moves = get_king_moves(piece_position)
	else:
		_moves = []
	
	return _moves

func get_king_moves(piece_position : Vector2):
	var _moves = []
	var directions = [
		Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0),
		Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)
	]
	
	for direction in directions:
		var pos = piece_position + direction
		if is_valid_position(pos):
			if is_empty(pos) or is_enemy(pos):
				_moves.append(pos)
	return _moves

func is_valid_position(pos : Vector2):
	return pos.x >= 0 and pos.x < BOARD_SIZE and pos.y >= 0 and pos.y < BOARD_SIZE

func is_empty(pos : Vector2):
	return board[pos.x][pos.y] == 0

func is_enemy(pos : Vector2):
	if white and board[pos.x][pos.y] < 0:
		return true
	elif not white and board[pos.x][pos.y] > 0:
		return true
	return false

# The rest of your unused logic can remain or be stripped out
func _on_button_pressed(button):
	pass

func is_stalemate():
	return false

func insuficient_material():
	return false

func threefold_position(var1 : Array):
	pass
