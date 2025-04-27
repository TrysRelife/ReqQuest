# NpcInteractionScene.gd
# Affiche un dialogue ou une question spécifique et gère la réponse/continuation.

extends Control

# Références UI (vérifie les chemins !)
@onready var npc_avatar = $MainMargin/VerticalLayout/NpcInfoBar/NpcAvatar # Optionnel
@onready var npc_name_label = $MainMargin/VerticalLayout/NpcInfoBar/NpcNameLabel # Optionnel
@onready var interaction_text = $MainMargin/VerticalLayout/InteractionPanel/PanelVBox/InteractionText
@onready var options_container = $MainMargin/VerticalLayout/InteractionPanel/PanelVBox/OptionsContainer
@onready var option_button_1 = $MainMargin/VerticalLayout/InteractionPanel/PanelVBox/OptionsContainer/OptionButton1
@onready var option_button_2 = $MainMargin/VerticalLayout/InteractionPanel/PanelVBox/OptionsContainer/OptionButton2
@onready var option_button_3 = $MainMargin/VerticalLayout/InteractionPanel/PanelVBox/OptionsContainer/OptionButton3
@onready var continue_button = $MainMargin/VerticalLayout/ContinueButton

var interaction_data: Dictionary = {}
var correct_option_index: int = -1
var answer_selected: bool = false # Pour éviter double traitement si on clique vite

# =============================================================================
# Initialisation
# =============================================================================
func _ready():
	# --- Vérification de la référence au bouton Continue ---
	if continue_button == null:
		printerr("NpcInteractionScene: ERREUR CRITIQUE - @onready var continue_button est NULL. Vérifie le chemin !")
	else:
		print("NpcInteractionScene: Référence ContinueButton OK.")
	# -----------------------------------------------------

	interaction_data = GameState.current_interaction_data
	if interaction_data.is_empty():
		printerr("NpcInteractionScene: ERREUR - Aucune donnée d'interaction trouvée. Retour.")
		_go_back_to_npc_selection()
		return

	_display_npc_info(interaction_data.get("npc_role", ""))
	interaction_text.text = interaction_data.get("text", "...")

	options_container.visible = false
	continue_button.visible = false # Important: Commence caché
	answer_selected = false

	var interaction_type = interaction_data.get("type", "dialogue")
	print("NpcInteractionScene: Interaction Type = ", interaction_type)

	match interaction_type:
		"question":
			# ... (logique pour configurer les questions, inchangée) ...
			var options = interaction_data.get("options", [])
			correct_option_index = interaction_data.get("correct_index", -1)
			if options.size() == 3 and correct_option_index >= 0 and correct_option_index <= 2:
				# ... (assigner texte, reset apparence, activer boutons) ...
				_reset_option_buttons_appearance()
				option_button_1.text = options[0]; option_button_1.disabled = false
				option_button_2.text = options[1]; option_button_2.disabled = false
				option_button_3.text = options[2]; option_button_3.disabled = false
				if option_button_1 and option_button_2 and option_button_3: # Vérifier si les boutons existent
					if not option_button_1.is_connected("pressed", Callable(self, "_on_option_button_pressed")):
						option_button_1.pressed.connect(_on_option_button_pressed.bind(0))
					if not option_button_2.is_connected("pressed", Callable(self, "_on_option_button_pressed")):
						option_button_2.pressed.connect(_on_option_button_pressed.bind(1))
					if not option_button_3.is_connected("pressed", Callable(self, "_on_option_button_pressed")):
						option_button_3.pressed.connect(_on_option_button_pressed.bind(2))
				else:
					printerr("NpcInteractionScene: ERREUR - @onready var pour les boutons d'option est NULL.")

				options_container.visible = true
			else:
				printerr("NpcInteractionScene: Données de question invalides. Fallback en dialogue.")
				continue_button.visible = true # Affiche Continue si question invalide

		"dialogue":
			print("NpcInteractionScene: Traitement comme DIALOGUE. Affichage du bouton Continuer.")
			continue_button.visible = true # Affiche Continue pour un dialogue

		_:
			printerr("NpcInteractionScene: Type inconnu. Fallback en dialogue.")
			continue_button.visible = true # Affiche Continue par défaut

	# --- Connexion du signal ContinueButton ---
	# On le fait ici, après avoir potentiellement rendu le bouton visible
	if continue_button: # Vérifier si le bouton existe
		if not continue_button.is_connected("pressed", Callable(self, "_on_continue_button_pressed")):
			var err = continue_button.pressed.connect(_on_continue_button_pressed)
			if err == OK:
				print("NpcInteractionScene: Signal 'pressed' de ContinueButton connecté avec succès.")
			else:
				printerr("NpcInteractionScene: ERREUR de connexion du signal ContinueButton ! Code: ", err)
		else:
			print("NpcInteractionScene: Signal 'pressed' de ContinueButton déjà connecté.")
	# -----------------------------------------


# ... (Fonctions _display_npc_info, _find_npc_data_by_role, _on_option_button_pressed, _reset_option_buttons_appearance restent identiques) ...

func _display_npc_info(npc_role: String):
	if npc_name_label == null or npc_avatar == null: return
	var npc_data = _find_npc_data_by_role(npc_role)
	if not npc_data.is_empty():
		npc_name_label.text = npc_data.get("name", "Unknown")
		if npc_data.has("image"):
			var image_path = npc_data.get("image", "")
			if not image_path.is_empty() and FileAccess.file_exists(image_path):
				npc_avatar.texture = load(image_path)
			else: npc_avatar.texture = null
		else: npc_avatar.texture = null
	else:
		npc_name_label.text = "Narrator"
		npc_avatar.texture = null

func _find_npc_data_by_role(role_to_find: String) -> Dictionary:
	if GameState.current_quest_runtime_data.is_empty(): return {}
	var npcs = GameState.current_quest_runtime_data.get("npcs", [])
	for npc in npcs:
		if npc.get("role", "") == role_to_find: return npc
	return {}

func _on_option_button_pressed(selected_index: int):
	if answer_selected: return
	answer_selected = true
	print("Option sélectionnée: Index ", selected_index)
	option_button_1.disabled = true
	option_button_2.disabled = true
	option_button_3.disabled = true
	var points = interaction_data.get("points", 0)
	var is_correct = (selected_index == correct_option_index)
	var buttons = [option_button_1, option_button_2, option_button_3]
	for i in range(buttons.size()):
		var button = buttons[i]
		var stylebox = StyleBoxFlat.new()
		if i == correct_option_index:
			stylebox.bg_color = Color.DARK_GREEN
			button.add_theme_color_override("font_disabled_color", Color.WHITE)
		elif i == selected_index:
			stylebox.bg_color = Color.DARK_RED
			button.add_theme_color_override("font_disabled_color", Color.WHITE)
		else:
			stylebox.bg_color = Color(0.3, 0.05, 0.05, 0.6)
			button.add_theme_color_override("font_disabled_color", Color.LIGHT_GRAY)
		button.add_theme_stylebox_override("normal", stylebox)
		button.add_theme_stylebox_override("hover", stylebox)
		button.add_theme_stylebox_override("pressed", stylebox)
		button.add_theme_stylebox_override("disabled", stylebox)
	if is_correct:
		GameState.add_to_quest_score(points)
		print("Réponse Correcte ! Score ajouté: ", points)
	else: print("Réponse Incorrecte.")
	continue_button.visible = true # Affiche le bouton après la réponse

func _reset_option_buttons_appearance():
	var buttons = [option_button_1, option_button_2, option_button_3]
	for button in buttons:
		button.remove_theme_stylebox_override("normal")
		button.remove_theme_stylebox_override("hover")
		button.remove_theme_stylebox_override("pressed")
		button.remove_theme_stylebox_override("disabled")
		button.remove_theme_color_override("font_disabled_color")


# =============================================================================
# Navigation
# =============================================================================

# Appelé quand le bouton "Continue" est cliqué (après dialogue ou réponse QCM)
func _on_continue_button_pressed():
	# --- Log pour vérifier si la fonction est appelée ---
	print("NpcInteractionScene: _on_continue_button_pressed() - DÉBUT")

	# Vérifier si le bouton n'est pas désactivé (ne devrait pas arriver mais sécurité)
	if continue_button and continue_button.disabled:
		print("NpcInteractionScene: Clic ignoré, ContinueButton est désactivé.")
		return

	# Appeler GameState pour avancer
	print("NpcInteractionScene: Appel de GameState.advance_interaction()...")
	GameState.advance_interaction()
	print("NpcInteractionScene: GameState.advance_interaction() terminé.")

	# Appeler la fonction pour retourner en arrière
	print("NpcInteractionScene: Appel de _go_back_to_npc_selection()...")
	_go_back_to_npc_selection()
	print("NpcInteractionScene: _on_continue_button_pressed() - FIN") # Vérifie que la fonction se termine


# Fonction pour retourner à l'écran précédent (InteractionScreen)
func _go_back_to_npc_selection():
	print("NpcInteractionScene: Tentative de retour vers InteractionScreen...") # Log avant changement
	var interaction_scene_path = "res://Scenes/InteractionScreen.tscn"
	if FileAccess.file_exists(interaction_scene_path):
		var err = get_tree().change_scene_to_file(interaction_scene_path)
		if err != OK:
			printerr("NpcInteractionScene: ERREUR lors du changement de scène vers InteractionScreen ! Code: ", err)
	else:
		printerr("NpcInteractionScene: ERREUR - Scene InteractionScreen.tscn non trouvée ! Fallback vers QuestListScreen.")
		get_tree().change_scene_to_file("res://Scenes/QuestListScreen.tscn") # Plan C