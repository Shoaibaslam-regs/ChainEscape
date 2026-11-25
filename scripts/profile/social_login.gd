class_name SocialLogin
extends RefCounted
## Where social sign-in (Facebook first) plugs in. Today no provider is set
## up, so is_available() is false and sign_in() reports "coming soon".
##
## To add Facebook later: put the OAuth flow (a Godot Android plugin for the
## Facebook SDK, or a web OAuth flow) in sign_in(), emit finished(true, name)
## with the player's display name, and make is_available() return true.
## Note: once login sends data anywhere, the Settings privacy line and the
## Play Store Data safety form must change too.

## [param success] false comes with a message to show the player.
signal finished(success: bool, message: String)

const FACEBOOK := "facebook"
const COMING_SOON := "Facebook login is coming soon."


func is_available(_provider: String) -> bool:
	return false


func sign_in(provider: String) -> void:
	if not is_available(provider):
		finished.emit.call_deferred(false, COMING_SOON)
