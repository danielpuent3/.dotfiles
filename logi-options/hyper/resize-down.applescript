-- Resize active tmux pane down by 5 cells.
on run
	set tmuxBin to "/opt/homebrew/bin/tmux"
	try
		set sessionName to do shell script tmuxBin & " list-clients -F '#{session_name}' | head -n 1"
		if sessionName is "" then return
		do shell script tmuxBin & " resize-pane -t " & quoted form of (sessionName & ":") & " -D 5"
	end try
	tell application "Hyper" to activate
end run
