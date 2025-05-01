# NpcInteractionScene.gd
# Affiche un dialogue ou une question QCM.
# Après un dialogue, enchaîne l'interaction suivante si elle existe.
# Après une question, ou si la quête est finie, retourne à l'écran de sélection des PNJ.

extends Control

# Références UI
@onready var npc_avatar: TextureRect = $MainMargin/VerticalLayout/NpcInfoBar/NpcAvatar
@onready var npc_name_label: Label = $MainMargin/VerticalLayout/NpcInfoBar/NpcNameLabel
@onready var interaction_text: Label = $MainMargin/VerticalLayout/InteractionPanel/PanelVBox/InteractionText
@onready var options_container: VBoxContainer = $MainMargin/VerticalLayout/InteractionPanel/PanelVBox/OptionsContainer
@onready var option_button_1: Button = $MainMargin/VerticalLayout/InteractionPanel/PanelVBox/OptionsContainer/OptionButton1
@onready var option_button_2: Button = $MainMargin/VerticalLayout/InteractionPanel/PanelVBox/OptionsContainer/OptionButton2
@onready var option_button_3: Button = $MainMargin/VerticalLayout/InteractionPanel/PanelVBox/OptionsContainer/OptionButton3
@onready var continue_button: Button = $MainMargin/VerticalLayout/ContinueButton

# Variables d'état
var interaction_data: Dictionary = {}
var correct_option_index: int = -1
var answer_selected: bool = false

# =============================================================================
# Initialisation
# =============================================================================
func _ready():
	# Récupère l'interaction à afficher depuis GameState
	interaction_data = GameState.current_interaction_data

	if interaction_data.is_empty():
		printerr("NpcInteractionScene: Aucune donnée d'interaction. Retour.")
		_go_back_to_npc_selection()
		return

	# Affiche les détails de l'interaction actuelle
	_display_interaction(interaction_data)

	# Connecte le bouton Continuer (sera rendu visible par _display_interaction si nécessaire)
	_connect_continue_button()

# =============================================================================
# Affichage et Configuration de l'Interaction Actuelle
# =============================================================================
func _display_interaction(data: Dictionary):
	# Met à jour les données locales et l'UI de base
	interaction_data = data
	_display_npc_info(interaction_data.get("npc_role", ""))
	interaction_text.text = interaction_data.get("text", "[Interaction Text Missing]")

	# Réinitialise l'état et cache les éléments
	options_container.visible = false
	continue_button.visible = false
	answer_selected = false

	# Configure l'UI selon le type d'interaction
	var interaction_type = interaction_data.get("type", "dialogue")
	match interaction_type:
		"question":
			var options = interaction_data.get("options", [])
			var raw_correct_index = interaction_data.get("correct_index", -1)
			var index_int = -1
			if raw_correct_index is int: index_int = raw_correct_index
			elif raw_correct_index is float: index_int = int(raw_correct_index)
			else: printerr("NpcInteractionScene: correct_index invalide: ", raw_correct_index)

			# Vérification finale des données de la question
			if options.size() == 3 and index_int >= 0 and index_int <= 2:
				correct_option_index = index_int
				_reset_option_buttons_appearance()
				# Configure et active les boutons d'option
				option_button_1.text = options[0]; option_button_1.disabled = false
				option_button_2.text = options[1]; option_button_2.disabled = false
				option_button_3.text = options[2]; option_button_3.disabled = false
				# Connecte les signaux des options
				_connect_option_button(option_button_1, 0)
				_connect_option_button(option_button_2, 1)
				_connect_option_button(option_button_3, 2)
				# Affiche le conteneur des options
				options_container.visible = true
			else: # Question invalide -> Fallback dialogue
				printerr("NpcInteractionScene: Données Question Invalides. Fallback Dialogue.")
				continue_button.disabled = false; continue_button.visible = true
		"dialogue", _: # Dialogue ou type inconnu
			continue_button.disabled = false; continue_button.visible = true

# =============================================================================
# Fonctions Helper (Connexion, Affichage, Recherche, Reset Style)
# =============================================================================
func _connect_option_button(button: Button, index: int):
	if button:
		var callable_func = Callable(self, "_on_option_button_pressed")
		# Déconnecte d'abord pour éviter doublons
		if button.is_connected("pressed", callable_func): button.disconnect("pressed", callable_func)
		button.pressed.connect(_on_option_button_pressed.bind(index))

func _connect_continue_button():
	if continue_button:
		var callable_func = Callable(self, "_on_continue_button_pressed")
		if continue_button.is_connected("pressed", callable_func): continue_button.disconnect("pressed", callable_func)
		var err = continue_button.pressed.connect(callable_func)
		if err != OK: printerr("ERREUR connexion ContinueButton! Code: ", err)

func _display_npc_info(npc_role: String):
	if npc_name_label == null or npc_avatar == null: return
	var npc_data = _find_npc_data_by_role(npc_role)
	if not npc_data.is_empty():
		npc_name_label.text = npc_data.get("name", "Unknown")
		if npc_data.has("image"):
			var image_path = npc_data.get("image", "");
			if not image_path.is_empty() and FileAccess.file_exists(image_path): npc_avatar.texture = load(image_path)
			else: npc_avatar.texture = null
		else: npc_avatar.texture = null
	else: npc_name_label.text = "Narrator"; npc_avatar.texture = null

func _find_npc_data_by_role(role_to_find: String) -> Dictionary:
	if GameState.current_quest_runtime_data.is_empty(): return {}
	var npcs = GameState.current_quest_runtime_data.get("npcs", [])
	for npc in npcs:
		if npc.get("role", "") == role_to_find: return npc
	return {}

func _reset_option_buttons_appearance():
	var buttons = [option_button_1, option_button_2, option_button_3]
	for button in buttons:
		if button:
			button.remove_theme_stylebox_override("normal"); button.remove_theme_stylebox_override("hover")
			button.remove_theme_stylebox_override("pressed"); button.remove_theme_stylebox_override("disabled")
			button.remove_theme_color_override("font_disabled_color")

# =============================================================================
# Gestion des Actions Utilisateur
# =============================================================================
func _on_option_button_pressed(selected_index: int):
	if answer_selected: return
	answer_selected = true

	option_button_1.disabled = true; option_button_2.disabled = true; option_button_3.disabled = true

	var is_correct = (selected_index == correct_option_index)
	var points = interaction_data.get("points", 0)
	if is_correct: GameState.add_to_quest_score(points)

	# Applique feedback visuel
	var buttons = [option_button_1, option_button_2, option_button_3]
	for i in range(buttons.size()):
		var button = buttons[i]; if not button: continue
		var stylebox = StyleBoxFlat.new(); stylebox.set_corner_radius_all(4)
		if i == correct_option_index: stylebox.bg_color = Color.DARK_GREEN; button.add_theme_color_override("font_disabled_color", Color.WHITE)
		elif i == selected_index: stylebox.bg_color = Color.DARK_RED; button.add_theme_color_override("font_disabled_color", Color.WHITE)
		else: stylebox.bg_color = Color(0.4, 0.4, 0.4, 0.8); button.add_theme_color_override("font_disabled_color", Color.LIGHT_GRAY)
		button.add_theme_stylebox_override("normal", stylebox); button.add_theme_stylebox_override("hover", stylebox)
		button.add_theme_stylebox_override("pressed", stylebox); button.add_theme_stylebox_override("disabled", stylebox)

	# Affiche le bouton Continuer après avoir répondu
	continue_button.disabled = false
	continue_button.visible = true
	_connect_continue_button() # Reconnecte au cas où

# Appelé quand le bouton "Continue" est cliqué
func _on_continue_button_pressed():
	# Récupère le type de l'interaction qu'on vient de terminer
	var previous_interaction_type = interaction_data.get("type", "dialogue")

	# Avance toujours à l'interaction suivante dans GameState
	GameState.advance_interaction()

	# Décide de la suite
	if GameState.is_quest_finished():
		# Si la quête est finie après l'avancement, retourne à l'écran de sélection
		_go_back_to_npc_selection()
	elif previous_interaction_type == "question":
		# Si on vient de répondre à une question, retourne à l'écran de sélection
		_go_back_to_npc_selection()
	else:
		# Si on vient de voir un dialogue et qu'il reste des interactions,
		# met à jour cette scène avec l'interaction suivante
		var next_interaction_data = GameState.get_next_interaction()
		_display_interaction(next_interaction_data)

# =============================================================================
# Navigation
# =============================================================================
func _go_back_to_npc_selection():
	# Navigue vers l'écran de sélection des PNJ
	var interaction_scene_path = "res://Scenes/InteractionScreen.tscn"
	if FileAccess.file_exists(interaction_scene_path):
		get_tree().change_scene_to_file(interaction_scene_path)
	else:
		printerr("NpcInteractionScene: ERREUR - Scene InteractionScreen.tscn non trouvée ! Fallback.")
		get_tree().change_scene_to_file("res://Scenes/QuestListScreen.tscn")