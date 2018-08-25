#region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Outfile=Client.exe
#AutoIt3Wrapper_Change2CUI=y
#endregion ;**** Directives created by AutoIt3Wrapper_GUI ****
If _Singleton("ETAL Connection Wizard", 1) = 0 Then
	MsgBox(0, "Warning", "An occurence of the ETAL Connection Wizard is already running", 5)
	Exit
EndIf
#cs ----------------------------------------------------------------------------

	AutoIt Version: 3.3.8.1

	Authors:
	Caleb41610, Diabolic, CamelZero

	Script Function:
	Add features to the D2NT/ETAL core.
	Interact with other users via tcp.
	Send usage reports and other statistical data

#ce ----------------------------------------------------------------------------

; Script Start - :)
OnAutoItExitRegister("_Exit")
Opt("GUIOnEventMode", 0)
Opt("TCPTimeout", 0)

#include <GUIConstantsEx.au3>
#include <GUIButton.au3>
#include <ButtonConstants.au3>
#include <StaticConstants.au3>
#include <EditConstants.au3>
#include <GuiEdit.au3>
#include <WindowsConstants.au3>
#include <Inet.au3>
#include <Array.au3>
#include <Misc.au3>
#include "Include/CopyData.au3"
#include "Include/Packets.au3"

; GUI stuff
Global $GUI
Global $MENU, $SETUP, $RUNPROFILE, $NoProfiles, $LOGOUT ; Menu/Menu
Global $Edit1, $Button1, $Button2, $Button3 ; GUI
Global $REPORT, $ERROR, $SOJDCLONE, $GAME ; Menu/Report
Global $VISIT, $WIKI, $SITE, $ARREATSUMMIT, $JSP ; Menu/Tools
Global $PROFILENAMES = _LoadProfiles()
Global $PROFILEMENU[UBound($PROFILENAMES) + 1]
Global $WikiUrl = "http://www.projectetal.com/wiki/index.php/Main_Page"
Global $SiteUrl = "http://www.projectetal.com/forums/index.php"
Global $ArreatUrl = "http://classic.battle.net/diablo2exp/"
Global $JspUrl = "http://forums.d2jsp.org/index.php"
Global $Image = "And_the_Heavens_shall_tremble.jpg"

; Etal/au3 stuff
;Global $MyUserName, $MyNickName,
Global $MyRevision
Global $NTAU_TITLE = "ETAL Connection Wizard"
Global Const $Au3Config = "Au3ExConfig.ini"
Global Const $GameFile = "GameList.ini"
Global $ReportError = False
Global $ReportSojDclone = False
Global $ReportGame = False

; Tcp stuff
TCPStartup()
Global $ConnectedIP, $ReconnectTimeout, $IsConnected, $Buffer
Global $ServerAddress = 'etaloptin.no-ip.org'
Global $ServerIP = TCPNameToIP($ServerAddress)
Global $ServerPort = 1337
Global $ConnectedSocket = -1
Global $PacketSize = 1000
Global $LoginTimeout = 7000
Global $loginTimer = -1
Global $LoggingIn = 0

_LoadGUI()
_Main()

Func _Main()
	While 1
		$gMsg = GUIGetMsg()
		Select
			Case $gMsg = $GUI_EVENT_CLOSE
				Exit

;Start GUI controls
			Case $gMsg = $Button1
				_Setup(1) ; 0 = initial startup (if no ini, does full setup), 1 = force full setup
			Case $gMsg = $Button2
				Local $WHO = InputBox("Which Profile", "Please enter the name of the profile to start", "")
				If $WHO <> "" Then
					_Append("Starting profile " + $WHO)
					_RunProfile($WHO)
				EndIf
				;Case $gMsg = $Button3 ; Not implemented yet

; End GUI control Start Menu control
			Case $gMsg = $ERROR
				If $ReportError = True Then
					$ReportError = False
					If $ReportError = False Then
						_Append("Error reporting turned off.")
					Else
						_Append("Failed to turned off error reporting.")
					EndIf
				Else
					$ReportError = True
					If $ReportError = True Then
						_Append("Game requests turned on.")
					Else
						_Append("Failed to turn on error reporting.")
					EndIf
				EndIf
			Case $gMsg = $SOJDCLONE
				If $ReportSojDclone = True Then
					$ReportSojDclone = False
					If $ReportSojDclone = False Then
						_Append("Soj/Dclone reporting turned off.")
					Else
						_Append("Failed to turned off Soj/Dclone reporting.")
					EndIf
				Else
					$ReportSojDclone = True
					If $ReportSojDclone = True Then
						_Append("Soj/Dclone reporting turned on.")
					Else
						_Append("Failed to turn on Soj/Dclone reporting.")
					EndIf
				EndIf
			Case $gMsg = $GAME
				If $ReportGame = True Then
					$ReportGame = False
					If $ReportGame = False Then
						_Append("Game requests turned off.")
					Else
						_Append("Failed to turn off game requests.")
					EndIf
				Else
					$ReportGame = True
					If $ReportGame = True Then
						_Append("Game requests turned on.")
					Else
						_Append("Failed to turned on game requests.")
					EndIf
				EndIf
			Case $gMsg = $SETUP
				If $ConnectedSocket = -1 Then
					_Setup(1)
				EndIf
			Case $gMsg = $RUNPROFILE
				Local $Check = InputBox("Profile", "Please input the name of the profile", "", "*")

				If $Check = "" Then
					Switch @error
						Case 0
							_Append("Running profile [" + $Check + "]")
							_RunProfile($Check)
					EndSwitch
				EndIf
			Case $gMsg = $LOGOUT
				If $ConnectedSocket <> -1 Then
					TCPCloseSocket($ConnectedSocket)
					$ConnectedSocket = -1
					_Append("You have been logged out.")
				EndIf
			Case $gMsg = $WIKI
				_OpenPage($WikiUrl)
			Case $gMsg = $SITE
				_OpenPage($SiteUrl)
			Case $gMsg = $ARREATSUMMIT
				_OpenPage($ArreatUrl)
			Case $gMsg = $JSP
				_OpenPage($JspUrl)
; End Menu control
		EndSelect

		For $X = 0 To UBound($PROFILENAMES) - 1
			If $gMsg = $PROFILEMENU[$X] Then
				_RunProfile($PROFILENAMES[$X])
			EndIf
		Next

		; 1 = sent login
		; 2 = waiting for confirmation
		; 3 = success
		; 4 = fail
		If $LoggingIn = 1 Then
			SplashTextOn("ProjectEtal.com", "Logging in...", 200, 200, @DesktopWidth / 2 - 100, @DesktopHeight / 2 - 100)
			$LoggingIn = 2
		Else
			If $LoggingIn = 3 Then
				$LoggingIn = 0
				SplashOff()
				_Append("You have been logged in.")
				_UpdateInfo()
			Else
				If $LoggingIn = 4 Then
					SplashOff()
					$LoggingIn = 0
					_Login()
				EndIf
			EndIf
		EndIf

		If $LoggingIn = 2 Then
			If TimerDiff($loginTimer) >= $LoginTimeout Then
				$LoggingIn = 4
			EndIf
		EndIf

		If $ConnectedSocket <> -1 Then
			_CheckNewPackets()
		EndIf
	WEnd
EndFunc   ;==>_Main

#cs ----------------------------------------------------------------------------
	GUI/Setup functions
#ce ----------------------------------------------------------------------------
Func _LoadGUI()
	#region ### START Koda GUI section ### Form=
	$GUI = GUICreate($NTAU_TITLE, 487, 492, @DesktopWidth / 2 - 391 / 2, @DesktopHeight / 2 - 152 / 2)
	$MENU = GUICtrlCreateMenu("Menu")
	$SETUP = GUICtrlCreateMenuItem("Setup", $MENU, 1)
	$RUNPROFILE = GUICtrlCreateMenu("Run Profile", $MENU, 0)
	$LOGOUT = GUICtrlCreateMenuItem("Logout", $MENU, 1)
	$REPORT = GUICtrlCreateMenu("Report")
	$ERROR = GUICtrlCreateMenuItem("Enable/Disable error reporting", $REPORT, 1)
	$SOJDCLONE = GUICtrlCreateMenuItem("Enable/Disable Soj/Dclone reporting", $REPORT, 1)
	$GAME = GUICtrlCreateMenuItem("Enable/Disable game requests", $REPORT, 1)
	$VISIT = GUICtrlCreateMenu("Sites")
	$WIKI = GUICtrlCreateMenuItem("Visit the Wiki", $VISIT, 1)
	$SITE = GUICtrlCreateMenuItem("Visit Project Etal", $VISIT, 1)
	$ARREATSUMMIT = GUICtrlCreateMenuItem("Visit the Arreat Summit", $VISIT, 1)
	$JSP = GUICtrlCreateMenuItem("Visit Jsp", $VISIT, 1)
	$Pic1 = GUICtrlCreatePic(@ScriptDir & "/Include/" & $Image, 0, 0, 484, 308)
	GUICtrlSetState(-1, $GUI_DISABLE)
	$Edit1 = GUICtrlCreateEdit("", 0, 310, 486, 161, BitOR($ES_AUTOVSCROLL, $ES_READONLY, $WS_VSCROLL))
	GUICtrlSetData(-1, StringFormat("Welcome to the Etal Connection Wizard...\r\nFrom here you can:\r\n     Connect to the servers at Etal\r\n     Run the manager\r\n     Start a profile\r\n    Visit the wiki, etal site, arreat summit, or jsp\r\n"))
	GUICtrlSetFont(-1, 8, 400, 2, "Comic Sans MS")
	GUICtrlSetColor(-1, 0x0000FF)
	GUICtrlSetBkColor(-1, 0x000000)
	$Button1 = GUICtrlCreateButton("Connect", 8, 8, 83, 25, $BS_DEFPUSHBUTTON)
	GUICtrlSetFont(-1, 8, 800, 2, "MS Sans Serif")
	GUICtrlSetTip(-1, "Connect to the servers at etal for broadcasting and error reporting")
	GUICtrlSetCursor (-1, 0)
	$Button2 = GUICtrlCreateButton("Run Profile", 96, 8, 83, 25, $BS_DEFPUSHBUTTON)
	GUICtrlSetFont(-1, 8, 800, 2, "MS Sans Serif")
	GUICtrlSetTip(-1, "Starts a profile from the manager")
	GUICtrlSetCursor (-1, 0)
	$Button3 = GUICtrlCreateButton("Create Profile", 184, 8, 83, 25, $BS_DEFPUSHBUTTON)
	GUICtrlSetFont(-1, 8, 800, 2, "MS Sans Serif")
	GUICtrlSetTip(-1, "Creates a profile on the manager or edits existsing")
	GUICtrlSetCursor (-1, 0)
	If Not FileExists(@ScriptDir & "/" & 'D2NT Manager.cfg') Then
		$NoProfiles = GUICtrlCreateMenuItem("No Profiles Loaded", $RUNPROFILE)
		GUICtrlSetState($NoProfiles, $GUI_DISABLE)
	EndIf
	For $pfnum = 0 To UBound($PROFILENAMES) - 1
		$PROFILEMENU[$pfnum] = GUICtrlCreateMenuItem($PROFILENAMES[$pfnum], $RUNPROFILE, $pfnum)
	Next
	GUISetOnEvent($GUI_EVENT_CLOSE, "_Exit")
	GUIRegisterMsg(0x004A, "ReceiveWMCopyData")
	_Append("Au3 Extension Loaded")
	Local $optin = IniRead($Au3Config, "Connection", "Connect", 0)
	If $optin Then
		_Append("Mode: Offline (Run setup if you want to opt-in to connect)")
	EndIf
	GUISetState(@SW_SHOW)
	#endregion ### END Koda GUI section ###
EndFunc   ;==>_LoadGUI

Func _Setup($type)
	Local $ConfigExists = FileExists(@ScriptDir & "/" & $Au3Config)
	Switch $type
		Case 0
			If $ConfigExists Then
				Local $isConnecting = IniRead(@ScriptDir & "/" & $Au3Config, "Connection", "Connect", 0)
				If $isConnecting = 1 Then
					Local $try = _Login()
					If $try = False Then
						_Append("Could not connect to server or already connected")
						_Setup(1)
					EndIf
				EndIf
			Else
				_Setup(1)
			EndIf
			Return
		Case 1
			Local $isOptingIn = _AskOptIn()
			If $isOptingIn = True Then
				IniWrite(@ScriptDir & "/" & $Au3Config, "Connection", "Connect", 1)
				_UpdateRevision()
				Local $try = _Login()
				If $try = False Then
					_Append("Could not connect to server")
				EndIf
			EndIf
	EndSwitch
EndFunc   ;==>_Setup

Func _AskOptIn()
	Local $tog = MsgBox(36, "Setup", "Would you like to help Project Etal by connecting to our servers?  You can use the extension either way, " & _
			"but there are some perks only available when opting-in, such as Revision updates and Dclone notifications." & @CRLF & @CRLF & _
			"Yes, I would like to opt-in and send statistics and error reports." & @CRLF & _
			"No, I would not like to opt-in.")
	If $tog = 6 Then
		IniWrite($Au3Config, "Connection", "Connect", 1)
		Return True
	Else
		IniWrite($Au3Config, "Connection", "Connect", 0)
		If $ConnectedSocket <> -1 Then
			Local $dc = MsgBox(36, "Setup", "You have opted out, but you are still connected.  Would you like to disconnect now?")
			If $dc = 6 Then
				TCPCloseSocket($ConnectedSocket)
				$ConnectedSocket = -1
				_Append("Disconnected.")
			EndIf
		EndIf
		Return False
	EndIf
EndFunc   ;==>_AskOptIn


#cs ----------------------------------------------------------------------------
	TCP/Data functions
#ce ----------------------------------------------------------------------------
Func _OpenPage($URL)
	Local $fd = FileOpen(@TempDir & "url.url", 2)
	If $fd = -1 Then
		MsgBox(0, "Error", "Failed to open page: " & @CRLF & @CRLF & $URL)
	Else
		FileWriteLine($fd, "[InternetShortcut]")
		FileWriteLine($fd, "URL=" & $URL)
		FileClose($fd)
		Run(@ComSpec & " /c " & Chr(34) & @TempDir & "url.url" & Chr(34))
	EndIf
EndFunc   ;==>_OpenPage

Func _CheckNewPackets()
	Local $RecvPacket = TCPRecv($ConnectedSocket, $PacketSize) ; Attempt to receive data
	If $RecvPacket <> "" Then ; If we got data...
		$Buffer &= $RecvPacket ; Add it to the packet buffer.
	EndIf
	If StringInStr($Buffer, "[PACKET_ETAL_") And Not StringInStr($Buffer, $PacketEND) Then
		Local $LoopTimer = TimerInit()
		Do
			$RecvPacket = TCPRecv($ConnectedSocket, $PacketSize) ; Attempt to receive data
			If $RecvPacket <> "" Then ; If we got data...
				$Buffer &= $RecvPacket ; Add it to the packet buffer.
			EndIf
		Until $RecvPacket = "" Or TimerDiff($LoopTimer) >= 500
	EndIf
	If StringInStr($Buffer, $PacketEND) Then ; If we received the end of a packet, then we will process it.
		Local $RawPackets = $Buffer ; Transfer all the data we have to a new variable.
		Local $FirstPacketLength = StringInStr($RawPackets, $PacketEND) - 30 ; Get the length of the packet, and subtract the length of the prefix/suffix.
		Local $PacketType = StringLeft($RawPackets, 18) ; Copy the first 18 characters, since that is where the packet type is put.
		Local $CompletePacket = StringMid($RawPackets, 19, $FirstPacketLength + 11) ; Extract the packet.
		Local $PacketsLeftover = StringTrimLeft($RawPackets, $FirstPacketLength + 41) ; Trim what we are using, so we only have what is left over. (any incomplete packets)
		$Buffer = $PacketsLeftover ; Transfer any leftover packets back to the buffer.
		_ProcessFullPacket($CompletePacket, $PacketType)
	EndIf
EndFunc   ;==>_CheckNewPackets

Func _ProcessFullPacket($CompletePacket, $PacketType)
	Switch $PacketType
		Case $PacketETALDClone
			Local $clonesplit = StringSplit($CompletePacket, $PacketDivider, 3)
			TrayTip("Diablo Clone Spawned", "Realm: " & $clonesplit[0] & @CRLF & "IP: " & $clonesplit[1], 16, 1)
			_Append("Diablo Clone Spawned on " & $clonesplit[0] & ", IP " & $clonesplit[1])
		Case $PacketETALSojs
			Local $clonesplit = StringSplit($CompletePacket, $PacketDivider, 3)
			TrayTip("Sojs sold to merchants", "Realm: " & $clonesplit[0] & @CRLF & "IP: " & $clonesplit[1], 16, 1)
			_Append("Sojs sold to merchants on " & $clonesplit[0] & ", IP " & $clonesplit[1])
		Case $PacketConnectionClosed
			_Append("Connection lost.")
		Case $PacketETALOutOfDate
			If ($CompletePacket > $MyRevision) Then
				TrayTip("New ETAL revision available", "Revision " & $CompletePacket, 16, 1)
				_Append("New ETAL revision available:  Revision " & $CompletePacket)
			Else
				_Append("ETAL Revision " & $MyRevision & " is up to date.")
			EndIf
		Case $PacketETALAnnouncement
			_Append("Announcement: " & $CompletePacket)
			TrayTip("Announcement", $CompletePacket, 16, 1)
		Case $PacketETALLogin
			$loginTimer = -1
			If $CompletePacket = 'success' Then
				$LoggingIn = 3
			Else
				If $CompletePacket = 'fail' Then
					_Append("Username or Password incorrect.")
					$LoggingIn = 4
					$ConnectedSocket = -1
				EndIf
			EndIf
			; Add reconnect attempts
	EndSwitch
EndFunc   ;==>_ProcessFullPacket

Func _Login()
	Local $connect = IniRead(@ScriptDir & "/" & $Au3Config, "Connection", "Connect", 0)
	If $connect = 0 Or $ConnectedSocket <> -1 Then
		Return True
	EndIf

	Local $childGUI = GUICreate("Login to ProjectEtal.com", 200, 250, @DesktopWidth / 2 - 100, @DesktopHeight / 2 - 125, "", "", $GUI)

	; Username
	GUICtrlCreateLabel("Username", 5, 5, 190, 20)
	Local $User = IniRead(@ScriptDir & "/" & $Au3Config, "Login", "Username", "")
	Local $Username = GUICtrlCreateInput($User, 5, 27, 190, 20)

	; Pass
	GUICtrlCreateLabel("Password", 5, 49, 190, 20)
	Local $Pass = IniRead(@ScriptDir & "/" & $Au3Config, "Login", "Password", "")
	Local $Password = GUICtrlCreateInput("", 5, 71, 190, 20)

	Local $Login = GUICtrlCreateButton("Login", 5, 100, 190, 30)
	Local $Register = GUICtrlCreateButton("Register", 5, 130, 190, 30)
	Local $Cancel = GUICtrlCreateButton("Don't connect", 5, 160, 190, 30)

	GUISetState(@SW_SHOW, $childGUI)

	Local $NTBotGame = FileOpen(@ScriptDir & "/" & "scripts/NTBot/NTBotGame.ntj", 0)
	Local $Line = FileReadLine($NTBotGame, 3)
	Local $Rev = StringMid($Line, 12, 2)
	IniWrite($Au3Config, "Settings", "Revision", $Rev)

	While 1
		$cgMsg = GUIGetMsg()
		Switch $cgMsg
			Case $Login
				$ConnectedSocket = TCPConnect($ServerIP, $ServerPort)
				If @error Then
					Return False
				EndIf
				Local $ReadUserName = GUICtrlRead($Username)
				Local $ReadPassword = GUICtrlRead($Password)
				IniWrite(@ScriptDir & "/" & $Au3Config, "Login", "Username", $ReadUserName)
				IniWrite(@ScriptDir & "/" & $Au3Config, "Login", "Nickname", $ReadUserName)
				IniWrite(@ScriptDir & "/" & $Au3Config, "Login", "Password", $ReadPassword)
				GUIDelete($childGUI)
				$LoggingIn = 1
				$LoginTimer = TimerInit()
				TCPSend($ConnectedSocket, $PacketETALLogin & $ReadUserName & $PacketDivider & $ReadPassword & $PacketEND)
				Return True
			Case $Register
				_OpenPage("http://www.projectetal.com/forums/index.php?login/")
			Case $Cancel
				IniWrite($Au3Config, "Connection", "Connect", 0)
				GUIDelete($childGUI)
				_Append("Mode: Offline (Run setup if you want to opt-in to connect)")
				Return True
		EndSwitch
	WEnd
EndFunc   ;==>_Login

Func _LogOut()
	TCPCloseSocket($ConnectedSocket)
	_Append("You have been logged out.")
EndFunc   ;==>_LogOut

Func _UpdateRevision()
	Local $NTBotGame = FileOpen(@ScriptDir & "/" & "scripts/NTBot/NTBotGame.ntj", 0)
	Local $Line = FileReadLine($NTBotGame, 3)
	Local $Rev = StringMid($Line, 12, 2)
	If $Rev = "" Then
		$Rev = 0
	EndIf
	IniWrite(@ScriptDir & "/" & $Au3Config, "Settings", "Revision", $Rev)
EndFunc   ;==>_UpdateRevision

Func _UpdateInfo()
	Local $Revision = IniRead(@ScriptDir & "/" & $Au3Config, "Settings", "Revision", 0)
	Local $User = IniRead(@ScriptDir & "/" & $Au3Config, "Login", "Username", "")
	Local $Nick = IniRead(@ScriptDir & "/" & $Au3Config, "Login", "Nickname", "")
	Local $DataString = _GetIP() & $PacketDivider & $User & $PacketDivider & $Nick & $PacketDivider & $Revision
	TCPSend($ConnectedSocket, $PacketETALUserInfo & $DataString & $PacketEND)
EndFunc   ;==>_UpdateInfo

#cs ----------------------------------------------------------------------------
	WM_COPYDATA and d2 interaction functions
#ce ----------------------------------------------------------------------------
Func ReceiveWMCopyData($hWnd, $msgID, $wParam, $lParam)
	$copyData = DllStructCreate("ulong_ptr;dword;ptr", $lParam)

	$dwData = DllStructGetData($copyData, 1)
	$cbData = DllStructGetData($copyData, 2)
	$lpData = DllStructGetData($copyData, 3)

	$content = DllStructGetData(DllStructCreate("wchar[" & $cbData & "]", $lpData), 1)
	$alldatanomodify = $content
	$split = StringSplit($content, ":")
	$account = $split[1]
	$content = StringTrimLeft($content, StringLen($split[1]) + 1)
	$spliter = StringSplit($content, "/")
	$acc = $spliter[0]
	$pass = $spliter[1]

	Switch $dwData
		Case $NTAu3_SendKey
			_Append($account & "Sending " & $content)
			_SendMinimized($wParam, $content)
		Case $NTAu3_KEY_LEFT
			$coords = StringSplit($content, ",")
			_Append($account & "Clicking [" & $coords[1] & "," & $coords[2] & "]")
			_MouseClickMinimized($wParam, $dwData, Int($coords[1]), Int($coords[2]))
		Case $NTAu3_KEY_RIGHT
			$coords = StringSplit($content, ",")
			_Append($account & "Right-Clicking [" & $coords[1] & "," & $coords[2] & "]")
			_MouseClickMinimized($wParam, $dwData, Int($coords[1]), Int($coords[2]))
		Case $NTAu3_SEND_ERROR
			TCPSend($ConnectedSocket, $PacketETALError & $alldatanomodify & $PacketEND)
		Case $NTAu3_SEND_DEBUG
			TCPSend($ConnectedSocket, $PacketETALDebug & $alldatanomodify & $PacketEND)
		Case $NTAu3_SEND_DCLONE
			Local $splitcloneinfo = StringSplit($alldatanomodify, "|", 3)
			TCPSend($ConnectedSocket, $PacketETALDClone & $splitcloneinfo[0] & $PacketDivider & $splitcloneinfo[1] & $PacketEND)
		Case $NTAu3_SEND_SOJS
			Local $splitcloneinfo = StringSplit($alldatanomodify, "|", 3)
			TCPSend($ConnectedSocket, $PacketETALSojs & $splitcloneinfo[0] & $PacketDivider & $splitcloneinfo[1] & $PacketEND)
		Case $NTAu3_RUNPROFILE ; 11
			_Append($account & "Running " & $content)
			SelectProfile($acc)
			ClickRun()
			EnterPassword($pass)
		Case $NTAu3_STOPPROFILE ; 12
			_Append($account & "Stopping " & $content)
			SelectProfile($content)
			ClickStop()
		Case $NTAu3_MKDIR ; 21
			_Append($account & "mkdir " & $content)
			DirCreate($content)
		Case $NTAu3_WINTITLE
			WinSetTitle($wParam, "", $alldatanomodify)
			_Append("Debug: " & "Window title: " & $alldatanomodify)
		Case $NTAu3_MOVE_WINDOW
			_Append($account & "Moving Window to " & $content)
			$coords = StringSplit($content, ",")
			MoveWindow($wParam, Int($coords[1]), Int($coords[2]))
		Case $NTAu3_MOVE_WINDOW_ANCHOR
			_Append($account & "Anchoring Window to " & $content)
			MoveWindowToAnchor($wParam, Int($content))
	EndSwitch
EndFunc   ;==>ReceiveWMCopyDataa

Func _MouseClickMinimized($Handle, $Button = 0, $X = "", $Y = "", $Clicks = 1)
	Local $MK_LBUTTON = 0x0001
	Local $WM_LBUTTONDOWN = 0x0201
	Local $WM_LBUTTONUP = 0x0202
	Local $MK_RBUTTON = 0x0002
	Local $WM_RBUTTONDOWN = 0x0204
	Local $WM_RBUTTONUP = 0x0205
	Local $WM_MOUSEMOVE = 0x0200
	Local $i = 0
	Select
		Case $Button = 1
			$Button = $MK_RBUTTON
			$ButtonDown = $WM_RBUTTONDOWN
			$ButtonUp = $WM_RBUTTONUP
		Case $Button = 0
			$Button = $MK_LBUTTON
			$ButtonDown = $WM_LBUTTONDOWN
			$ButtonUp = $WM_LBUTTONUP
		Case Else
			Exit
	EndSelect
	If $X = "" Or $Y = "" Then
		Exit
	EndIf
	For $i = 1 To $Clicks
		DllCall("user32.dll", "int", "SendMessage", _
				"hwnd", $Handle, _
				"int", $WM_MOUSEMOVE, _
				"int", 0, _
				"long", _MakeLong($X, $Y))
		DllCall("user32.dll", "int", "SendMessage", _
				"hwnd", $Handle, _
				"int", $ButtonDown, _
				"int", $Button, _
				"long", _MakeLong($X, $Y))
		DllCall("user32.dll", "int", "SendMessage", _
				"hwnd", $Handle, _
				"int", $ButtonUp, _
				"int", $Button, _
				"long", _MakeLong($X, $Y))
	Next
EndFunc   ;==>_MouseClickMinimized

Func _MouseMoveMinimized($Handle, $X = "", $Y = "")
	Local $WM_MOUSEMOVE = 0x0200
	Local $i = 0

	If $X = "" Or $Y = "" Then
		Exit
	EndIf

	DllCall("user32.dll", "int", "SendMessage", _
			"hwnd", $Handle, _
			"int", $WM_MOUSEMOVE, _
			"int", 0, _
			"long", _MakeLong($X, $Y))
EndFunc   ;==>_MouseMoveMinimized

Func _SendMinimized($Handle, $keys)
	ControlSend($Handle, "", "", $keys)
EndFunc   ;==>_SendMinimized


#cs ----------------------------------------------------------------------------
	D2NT/ETAL Profile functions
#ce ----------------------------------------------------------------------------
Func ClickRun()
	ControlClick("ETAL Manager", "", "[CLASSNN:Button1]")
EndFunc   ;==>ClickRun

Func ClickStop()
	ControlClick("ETAL Manager", "", "[CLASSNN:Button2]")
EndFunc   ;==>ClickStop

Func _LoadProfiles()
	If Not FileExists(@ScriptDir & "/" & 'D2NT Manager.cfg') Then
		Return False
	EndIf
	Local $D2NTConfigFile = FileOpen('D2NT Manager.cfg', 16)
	Local $D2NTConfigData = FileRead($D2NTConfigFile)
	$D2NTConfigData = StringReplace(BinaryToString($D2NTConfigData), Chr(0), "")
	FileClose($D2NTConfigFile)

	Local $D2NTConfigDataArray = StringSplit($D2NTConfigData, ".ntj", 3)
	For $i = 0 To UBound($D2NTConfigDataArray) - 1
		$D2NTConfigDataArray[$i] = StringLeft($D2NTConfigDataArray[$i], StringInStr($D2NTConfigDataArray[$i], ":\") - 2)
	Next

	Return $D2NTConfigDataArray
EndFunc   ;==>_LoadProfiles

Func EnterPassword($passw)
	If WinExists("Account Password") Then
		ControlFocus("Account Password", "", "[CLASSNN:Edit1]")
		$passPosted = ControlSend("Account Password", "", "[CLASSNN:Edit1]", $passw)

		If $passPosted = 1 Then
			ControlFocus("Account Password", "", "[CLASSNN:Button1]")
			ControlClick("Account Password", "", "[CLASSNN:Button1]", "left")
		Else
			_Append("Failed to enter password")
		EndIf
	Else
		_Append("Failed to locate the Password Window")
	EndIf
EndFunc   ;==>EnterPassword

Func _RunProfile($profile)
	If Not WinExists("ETAL Manager 3.165") Then
		If Not FileExists(@ScriptDir & '/' & 'ETAL Manager.exe') Then
			MsgBox(0, "Error", "Could not find manager." & @CRLF & "Make sure Au3Extension is in the correct directory." & @CRLF & @CRLF & "Check and restart", 3)
			Exit
		EndIf
	EndIf

	;Local $profile = InputBox("Run Profile", "Please enter the profile to start", "")
	Local $Password = InputBox("Password", "Please enter the password for this account", "", "*")

	If $profile <> "" Then
		If $Password <> "" Then
			If Not WinExists("ETAL Manager 3.165") Then
				If Not _LaunchManager() Then
					MsgBox(0, "Error", "Could not launch manager" & @CRLF & "Make sure Au3Extension is in the correct directory." & @CRLF & @CRLF & "Check and restart", 3)
					Exit
				EndIf
			EndIf

			While Not WinExists("ETAL Manager 3.165")
				Sleep(333)
			WEnd

			SelectProfile($profile)
			ClickRun()

			Sleep(333)

			EnterPassword($Password)
		Else
			_Append("Failed to enter password")
		EndIf
	EndIf
EndFunc   ;==>_RunProfile

Func SelectProfile($profileName)
	ControlFocus("ETAL Manager", "", "[CLASSNN:SysListView321]")
	ControlSend("ETAL Manager", "", "[CLASSNN:SysListView321]", "{UP}")

	$selected = Int(ControlListView("ETAL Manager", "", "[CLASSNN:SysListView321]", "GetSelected"))
	$nextSelection = 1
	$numProfiles = ControlListView("ETAL Manager", "", "[CLASSNN:SysListView321]", "GetItemCount")
	For $i = 0 To $numProfiles
		$text = ControlListView("ETAL Manager", "", "[CLASSNN:SysListView321]", "GetText", $i, 0)
		If $text = $profileName Then
			$nextSelection = $i
			;ControlListView("ETAL Manager", "", "[CLASSNN:SysListView321]", "Select", $i)
			;Break ;^ This does not actually update selection for D2NT ^
		EndIf
	Next
	$send = "{UP}"
	$step = -1
	If $nextSelection > $selected Then
		$send = "{DOWN}"
		$step = 1
	EndIf
	For $i = ($selected + $step) To $nextSelection Step $step
		ControlSend("ETAL Manager", "", "[CLASSNN:SysListView321]", $send)
	Next
EndFunc   ;==>SelectProfile

Func _LaunchManager()
	If FileExists(@ScriptDir & '/' & 'ETAL Manager.exe') Then
		If WinExists("ETAL Manager 3.165") Then
			_Append("Found ETAL Manager")
		Else
			_Append("Launching ETAL Manager")
			Run(@ScriptDir & "/" & "ETAL Manager.exe", @ScriptDir & "/")
		EndIf
		_Append("---------------------------------")
	Else
		_Append("Could not find ETAL Manager.exe")
		_Append("---------------------------------")
	EndIf
EndFunc   ;==>_LaunchManager
#cs ----------------------------------------------------------------------------
	Some small internal functions
#ce ----------------------------------------------------------------------------

Func _Timestamp()
	Local $TimeStamp = "[" & @HOUR & ":" & @MIN & ":" & @SEC & "]"
	Return $TimeStamp
EndFunc   ;==>_Timestamp

Func _Append($EditText)
	_GUICtrlEdit_AppendText($Edit1, _Timestamp() & " > " & $EditText & @CRLF)
EndFunc   ;==>_Append

Func _MakeLong($LoWord, $HiWord)
	Return BitOR($HiWord * 0x10000, BitAND($LoWord, 0xFFFF))
EndFunc   ;==>_MakeLong

Func _Exit()
	If $ConnectedSocket <> -1 Then
		TCPSend($ConnectedSocket, $PacketConnectionClosed & $PacketEND)
	EndIf
	TCPCloseSocket($ConnectedSocket)
	TCPShutdown()
	Exit
EndFunc   ;==>_Exit

Func _SocketToIP($SHOCKET) ; IP of the connecting client.
	Local $WS2_32 = DllOpen("Ws2_32.dll")
	Local $sockaddr = DllStructCreate("short;ushort;uint;char[8]")
	Local $aRet = DllCall($WS2_32, "int", "getpeername", "int", $SHOCKET, "ptr", DllStructGetPtr($sockaddr), "int*", DllStructGetSize($sockaddr))
	If Not @error And $aRet[0] = 0 Then
		$aRet = DllCall($WS2_32, "str", "inet_ntoa", "int", DllStructGetData($sockaddr, 3))
		If Not @error Then $aRet = $aRet[0]
	Else
		$aRet = 0
	EndIf
	$sockaddr = 0
	Return $aRet
EndFunc   ;==>_SocketToIP

Func MoveWindowToAnchor($handle, $anchor)
	; -  -  - ;
	; 8  1  2 ;
	; 7  0  3 ;  Anchor positions
	; 6  5  4 ;
	; -  -  - ;
	Dim $desktopHeight = @DesktopHeight - GetTaskBarHeight()
	Dim $pos = WinGetPos($handle); $pos[2] == width, $pos[3] == height
	Dim $x1 = 0
	Dim $x2 = Int((@DesktopWidth - $pos[2]) / 2)
	Dim $x3 = @DesktopWidth - $pos[2]
	Dim $y1 = 0
	Dim $y2 = Int(($desktopHeight - $pos[3]) / 2)
	Dim $y3 = $desktopHeight - $pos[3]
	Dim $x, $y

	If $anchor >= 6 Then
		$x = $x1
	ElseIf $anchor = 5 Or $anchor <= 1 Then
		$x = $x2
	Else
		$x = $x3
	EndIf
	If $anchor <= 6 And $anchor >= 4 Then
		$y = $y3
	ElseIf $anchor = 7 Or $anchor = 0 Or $anchor = 3 Then
		$y = $y2
	Else
		$y = $y1
	EndIf

	MoveWindow($handle, $x, $y)
EndFunc   ;==>MoveWindowToPosition

Func MoveWindow($handle, $x, $y)
	WinMove($handle, "", $x, $y)
EndFunc   ;==>MoveWindow

Func GetTaskBarHeight()
	Dim $pos = WinGetPos("[CLASS:Shell_TrayWnd; W:" & @DesktopWidth & "]")
	Return $pos[3]
EndFunc