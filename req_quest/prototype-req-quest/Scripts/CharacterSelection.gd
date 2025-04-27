extends Control

# Connect signals from TextureButtons in the editor to these functions
# You'll need references to the buttons to get their textures
@onready var ninja_button = $VBoxContainer/GridContainer/NinjaButton # Adjust path as needed
@onready var detective_button = $VBoxContainer/GridContainer/DetectiveButton
# ... add others

func _on_ninja_button_pressed():
    select_character(ninja_button.texture_normal)

func _on_detective_button_pressed():
    select_character(detective_button.texture_normal)

# ... add functions for other buttons

func select_character(texture: Texture2D):
    GameState.set_selected_character(texture)
    print("Character selected!")
    # Transition to the next scene (Quest or simplified Quest Start)
    get_tree().change_scene_to_file("res://Scenes/QuestScreen.tscn") # Go directly to quest for now