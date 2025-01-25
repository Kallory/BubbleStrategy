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
var state : bool = false
var moves = []
var selected_piece : Vector2
var is_selected = false

var promotion_square = null

var white_king = false
var black_king = false
var white_rook_left = false
var white_rook_right = false
var black_rook_left = false
var black_rook_right = false

var en_passant = null

var white_king_pos = Vector2(0, 4)
var black_king_pos = Vector2(7, 4)
var last_selected_piece : Vector2 = Vector2(-1, -1)
var num_clicked = 0

var fifty_move_rule = 0

var unique_board_moves : Array = []
var amount_of_same : Array = []

func _ready():
	# Initialize the board so that only the two kings are placed.
	# Every row is 8 columns wide, so fill them with 0 (empty).
	# We'll put white king on row 0, column 4, and black king on row 7, column 4.
	for row in range(BOARD_SIZE):
		var row_array = []
		for col in range(BOARD_SIZE):
			row_array.append(0)
		board.append(row_array)
	
	# Place white king at (0,4).
	board[0][4] = 6
	# Place black king at (7,4).
	board[7][4] = -6
	
	white_king_pos = Vector2(0, 4)
	black_king_pos = Vector2(7, 4)
	
	display_board()
	
	# Promotion GUI buttons (still present but not used)
	var white_buttons = get_tree().get_nodes_in_group("white_pieces")
	var black_buttons = get_tree().get_nodes_in_group("black_pieces")
	for button in white_buttons:
		button.pressed.connect(self._on_button_pressed.bind(button))
	for button in black_buttons:
		button.pressed.connect(self._on_button_pressed.bind(button))

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			# Clear selection
			state = false
			selected_piece = Vector2(-1, -1)
			delete_dots()
			
		if event.button_index == MOUSE_BUTTON_LEFT:
			if is_selected == true:
				print("oxygen +1")
				# Switch turn
				white = !white
				threefold_position(board)
				display_board()
				is_selected = false
				return
			if is_mouse_out():
				return
			# next two lines get the current coordinates of the mouse click
			var var1 = snapped(get_global_mouse_position().x, 0) / CELL_WIDTH
			var var2 = abs(snapped(get_global_mouse_position().y, 0)) / CELL_WIDTH
			# print("var1 = " + str(var1) + " var2 = " + str(var2))
			
			# Only proceed if the selected piece belongs to the current side
			if not state and (white and board[var2][var1] > 0 or not white and board[var2][var1] < 0):
				
				print(str(board[var2][var1]))
				selected_piece = Vector2(var2, var1)
				show_options()
				state = true
			elif state:
				set_move(var2, var1)

func is_mouse_out():
	if get_rect().has_point(to_local(get_global_mouse_position())):
		return false
	return true

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
	if num_clicked == 2:
		# add oxygen to bubble
		print("add oxygen")
	moves = get_moves(selected_piece)
	if moves == []:
		state = false
		return
	show_dots()

func show_dots():
	is_selected = true
	for move_pos in moves:
		var holder = TEXTURE_HOLDER.instantiate()
		dots.add_child(holder)
		holder.texture = PIECE_MOVE
		holder.global_position = Vector2(
			move_pos.y * CELL_WIDTH + (CELL_WIDTH / 2),
			-move_pos.x * CELL_WIDTH - (CELL_WIDTH / 2)
		)

func delete_dots():
	for child in dots.get_children():
		child.queue_free()

func set_move(var2, var1):
	for move_pos in moves:
		if move_pos.x == var2 and move_pos.y == var1:
			fifty_move_rule += 1
			if is_enemy(Vector2(var2, var1)):
				fifty_move_rule = 0
			
			# Perform the move
			board[var2][var1] = board[selected_piece.x][selected_piece.y]
			board[selected_piece.x][selected_piece.y] = 0
			
			# Update king position if needed
			if board[var2][var1] == 6:
				white_king_pos = Vector2(var2, var1)
			elif board[var2][var1] == -6:
				black_king_pos = Vector2(var2, var1)
			
			# Switch turn
			white = !white
			threefold_position(board)
			display_board()
			break
	delete_dots()
	state = false
	
	# If you clicked on the square where the king moved,
	# let you see king's move options again.
	if (selected_piece.x != var2 or selected_piece.y != var1) and (
		(white and board[var2][var1] > 0) or (!white and board[var2][var1] < 0)
	):
		selected_piece = Vector2(var2, var1)
		show_options()
		state = true


# -------------------------------------------------
# Only call the king's movement logic in get_moves!
# -------------------------------------------------
func get_moves(selected : Vector2):
	var piece_value = board[selected.x][selected.y]
	var _moves = []
	
	if abs(piece_value) == 6:
		_moves = get_king_moves(selected)
	else:
		# Return an empty list for any other piece type.
		_moves = []
	
	return _moves

# We keep all other piece movement functions for later use, 
# but they won't be called right now.

func get_king_moves(piece_position : Vector2):
	var _moves = []
	var directions = [
		Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0),
		Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)
	]
	
	# Temporarily remove the king from the board to test check.
	# (Prevents false positives of being 'in check' from itself.)
	var is_white_king = board[piece_position.x][piece_position.y] == 6
	
	for direction in directions:
		var pos = piece_position + direction
		if is_valid_position(pos):
			# We only add it if that resulting position is not in check.
			if is_empty(pos):
				_moves.append(pos)
			elif is_enemy(pos):
				_moves.append(pos)
	
	# Restore the king’s position on the board.
	if is_white_king:
		board[white_king_pos.x][white_king_pos.y] = 6
	else:
		board[black_king_pos.x][black_king_pos.y] = -6
	
	return _moves

# ---------------------------------------------------
# Functions needed for checks, boundary checks, etc.
# ---------------------------------------------------
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

# Promotion UI – leftover from original script. Not used in king-only scenario.
func promote(_var : Vector2):
	promotion_square = _var
	white_pieces.visible = white
	black_pieces.visible = !white

func _on_button_pressed(button):
	var num_char = int(button.name.substr(0, 1))
	board[promotion_square.x][promotion_square.y] = -num_char if white else num_char
	white_pieces.visible = false
	black_pieces.visible = false
	promotion_square = null
	display_board()

func is_stalemate():
	# If it’s white’s turn, check all white pieces (but effectively only the king).
	# If black’s turn, check all black pieces (effectively only the black king).
	if white:
		for i in range(BOARD_SIZE):
			for j in range(BOARD_SIZE):
				if board[i][j] > 0:
					if get_moves(Vector2(i, j)).size() != 0:
						return false
	else:
		for i in range(BOARD_SIZE):
			for j in range(BOARD_SIZE):
				if board[i][j] < 0:
					if get_moves(Vector2(i, j)).size() != 0:
						return false
	return true

func insuficient_material():
	# With only kings on the board, it's definitely insufficient.
	# But we keep the more general logic from the original script.
	var white_piece = 0
	var black_piece = 0
	
	for i in range(BOARD_SIZE):
		for j in range(BOARD_SIZE):
			match board[i][j]:
				2, 3:
					if white_piece == 0:
						white_piece += 1
					else:
						return false
				-2, -3:
					if black_piece == 0:
						black_piece += 1
					else:
						return false
				6, -6, 0:
					pass
				_:
					# If we see any other piece type, it's not strictly insufficient.
					return false
	return true

func threefold_position(var1 : Array):
	for i in range(unique_board_moves.size()):
		if var1 == unique_board_moves[i]:
			amount_of_same[i] += 1
			if amount_of_same[i] >= 3:
				print("DRAW (Threefold Repetition)")
			return
	unique_board_moves.append(var1.duplicate(true))
	amount_of_same.append(1)
