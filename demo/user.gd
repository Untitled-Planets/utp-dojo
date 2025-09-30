class_name User

enum {
	STATUS_NONE,
	STATUS_WORKING,
	STATUS_READY,
}

var status = STATUS_NONE
var user_id = null


func _user_get_git():
	var output = []
	var ret = OS.execute("git", ["config", "--get", "user.email"], output)
	printt("git command returns ", ret, output)
	if ret != 0:
		return ""

	return output[0].strip_edges()


func _user_get_system():
	var user = OS.get_environment("USER")
	if user == "":
		user = OS.get_environment("USERNAME")

	if user == "":
		return ""

	var host = OS.get_environment("HOSTNAME")
	if host == "":
		var output = []
		var ret = OS.execute("hostname", [], output)
		if ret == 0:
			host = output[0].strip_edges()

	if host == "":
		return user

	return user + "@" + host


func _user_get_local():
	var user = _user_get_git()
	if user != "":
		return user

	user = _user_get_system()

	return user


func initialize():
	# read from git files, or login to some service
	user_id = _user_get_local()
	if user_id != "":
		status = STATUS_READY
	return OK


func get_status():
	# return status none, initializing, ready
	return status


func get_user_id():
	# returns an opaque user_id
	# can be compared with other user_ids
	# can be converted to unique string
	# null means no user

	return user_id
