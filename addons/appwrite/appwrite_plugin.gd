@tool
extends EditorPlugin

func _enter_tree():
	# This runs when the user enables the plugin
	# You can add Singletons (Autoloads) here automatically!
	add_autoload_singleton("Appwrite", "res://addons/appwrite/src/appwrite_client.gd")

func _exit_tree():
	# Clean up when the plugin is disabled
	remove_autoload_singleton("Appwrite")
