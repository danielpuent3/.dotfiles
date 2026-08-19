-- open-or-focus.applescript — open a URL in Safari, or focus the tab already showing it.
--
-- Ported from ~/Raycast Scripts/open_or_focus_url.scpt and kept as plain text so it
-- diffs in review; the original was a compiled .scpt.
--
-- Changes from the original:
--   * matches on a normalised prefix instead of a bare `contains`, so a short URL
--     cannot grab an unrelated tab
--   * prefers an exact match over a prefix one when both exist
--   * opens a new window when Safari has none, instead of erroring on `window 1`
--   * survives windows with no tabs and tabs with no URL
--   * puts new tabs in the frontmost *visible* window, never an invisible leftover
--   * prints what it did, so the caller can report it

on run argv
	if (count of argv) < 1 then return "error: no URL given"
	return openOrFocus(item 1 of argv)
end run

on normalise(u)
	if u ends with "/" then return text 1 thru -2 of u
	return u
end normalise

-- Safari keeps closed windows in the enumeration as invisible, zero-tab objects,
-- so `window 1` is not reliably a window you can see.
on frontmostUsableWindow()
	tell application "Safari"
		repeat with w in windows
			try
				if visible of w and (count of tabs of w) > 0 then return w
			end try
		end repeat
	end tell
	return missing value
end frontmostUsableWindow

on openOrFocus(targetURL)
	set wanted to normalise(targetURL)

	tell application "Safari"
		activate

		set exactWin to missing value
		set exactTab to missing value
		set prefixWin to missing value
		set prefixTab to missing value

		repeat with w in windows
			try
				repeat with t in tabs of w
					try
						set u to my normalise(URL of t as text)
						if u is wanted then
							set exactWin to w
							set exactTab to t
							exit repeat
						else if prefixWin is missing value and u starts with wanted then
							set prefixWin to w
							set prefixTab to t
						end if
					end try
				end repeat
			end try
			if exactWin is not missing value then exit repeat
		end repeat

		if exactWin is not missing value then
			set current tab of exactWin to exactTab
			set index of exactWin to 1
			return "focused " & wanted
		else if prefixWin is not missing value then
			set current tab of prefixWin to prefixTab
			set index of prefixWin to 1
			return "focused " & (URL of prefixTab as text)
		end if

		set usableWin to my frontmostUsableWindow()
		if usableWin is missing value then
			make new document with properties {URL:targetURL}
		else
			tell usableWin
				set newTab to make new tab with properties {URL:targetURL}
				set current tab to newTab
			end tell
			set index of usableWin to 1
		end if
		return "opened " & targetURL
	end tell
end openOrFocus
