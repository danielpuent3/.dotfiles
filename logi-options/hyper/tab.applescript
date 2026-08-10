-- Hyper tab (tmux window) create-or-switch
-- Prompts for a name. If a tmux window with that name exists in the
-- attached session, switch to it. Otherwise create it. Focuses Hyper at the end.

on run
	set tmuxBin to "/opt/homebrew/bin/tmux"

	try
		set sessionName to do shell script tmuxBin & " list-clients -F '#{session_name}' | head -n 1"
	on error
		set sessionName to ""
	end try

	if sessionName is "" then
		display dialog "No attached tmux session found." buttons {"OK"} default button "OK" with icon stop
		return
	end if

	tell application "Hyper" to activate
	set dlg to display dialog "Tab name:" default answer "" buttons {"Cancel", "Go"} default button "Go" with title "Hyper tab"
	set tabName to text returned of dlg
	if tabName is "" then
		tell application "Hyper" to activate
		return
	end if

	set qSession to quoted form of sessionName
	set qName to quoted form of tabName

	set existing to do shell script tmuxBin & " list-windows -t " & qSession & " -F '#W' | /usr/bin/grep -Fx -- " & qName & " || true"

	try
		if existing is "" then
			do shell script tmuxBin & " new-window -t " & qSession & ": -n " & qName
		else
			do shell script tmuxBin & " select-window -t " & qSession & ":" & qName
		end if
	on error errMsg
		display dialog "tmux error: " & errMsg buttons {"OK"} default button "OK" with icon stop
	end try

	tell application "Hyper" to activate
end run
