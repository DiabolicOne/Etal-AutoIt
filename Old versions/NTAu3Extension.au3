#region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Outfile=Client.exe
#AutoIt3Wrapper_Change2CUI=y
#endregion ;**** Directives created by AutoIt3Wrapper_GUI ****
#cs ----------------------------------------------------------------------------
	
	AutoIt Version: 3.3.8.1
	
	Author:
	Caleb41610, CamelZero
	
	Credits:
	CamelZero, for the AutoIt3 Extension code and figuring out how to use WM_COPYDATA messages from Etal to other windows.  He brought this project to light and we wouldn't have any of it without him.
	
	Script Function:
	Send Statistics and Error reports to the Project Etal development team.
	
#ce ----------------------------------------------------------------------------

; Script Start - :)

#include <GUIConstantsEx.au3>
#include <GuiButton.au3>
#include <EditConstants.au3>
#include <GuiEdit.au3>
#include <WindowsConstants.au3>
#include <Inet.au3>
#include <Array.au3>
#include <Misc.au3>


If _Singleton("au3extension", 1) = 0 Then
	MsgBox(0, "Warning", "An occurence of Au3Extension is already running", 2)
	Exit
EndIf


Opt("GUIOnEventMode", 0)
Opt("TCPTimeout", 0)

; Au3Extension stuff
Global $NTAU_TITLE = "D2NT Au3ext"
Global $defaultLeft = 4
Global $defaultTop = 4

; DWDATA Constants
Global $NTAu3_KEY_LEFT = 0
Global $NTAu3_KEY_RIGHT = 1
Global $NTAu3_SendKey = 9
Global $NTAu3_RUNPROFILE = 11
Global $NTAu3_STOPPROFILE = 12
Global $NTAu3_MKDIR = 21
Global $NTAu3_NAMEGAMETITLE = 25
Global $NTAu3_MOVE_WINDOW = 30
Global $NTAu3_MOVE_WINDOW_ANCHOR = 31
Global $NTAu3_SEND_DCLONE = 70
Global $NTAu3_SEND_SOJS = 71
Global $NTAu3_SEND_ERROR = 98
Global $NTAu3_SEND_DEBUG = 99

; Tcp stuff
TCPStartup()
Global $ServerAddress = 'etaloptin.no-ip.org'
Global $ServerPort = 1337
Global $ServerIP = TCPNameToIP($ServerAddress)
Global $ConnectedSocket, $ConnectedIP, $ReconnectTimeout
Global $Buffer = ""
Global $PacketSize = 1000
Global $IsConnected

; User info stuff
Global $MyUserName, $MyNickName, $MyRevision

; Packet stuff
Global Const $PacketETALError = "[PACKET_ETAL_0001]" ; Etal Script Erorrs
Global Const $PacketETALTicket = "[PACKET_ETAL_0002]" ; Tickets
Global Const $PacketETALDClone = "[PACKET_ETAL_0003]" ; Diablo Close spawn
Global Const $PacketETALUserInfo = "[PACKET_ETAL_0004]" ; User information
Global Const $PacketETALDebug = "[PACKET_ETAL_0005]" ; Debug information
Global Const $PacketETALOutOfDate = "[PACKET_ETAL_0006]" ; New revision notifications
Global Const $PacketETALSojs = "[PACKET_ETAL_0007]"
Global Const $PacketETALAnnouncement = "[PACKET_ETAL_1000]" ; Announcements

Global Const $PacketConnectionClosed = "[PACKET_ETAL_9999]" ; Connection being killed
Global Const $PacketDivider = "[PACKET_SPLIT]" ; Divider
Global Const $PacketEND = "[PACKET_END]" ; Defines the end of a packet

; GUI stuff
Global $GUI = GUICreate($NTAU_TITLE, 350, 250, $defaultTop, $defaultLeft)
Global $EDIT = GUICtrlCreateEdit("", 5, 40, 340, 185, $ES_READONLY + $WS_VSCROLL)
Global $MENU = GUICtrlCreateMenu("Menu")
Global $SETUP = GUICtrlCreateMenu("Setup", $MENU, 0)
Global $RUNPROFILE = GUICtrlCreateButton("Run Profile", $MENU, 0)
GUICtrlSetFont($EDIT, 9, 800, 0, "MS Sans Serif")
GUISetOnEvent($GUI_EVENT_CLOSE, "Quit")
GUIRegisterMsg(0x004A, "ReceiveWMCopyData")
GUISetState(@SW_SHOW, $GUI)

; Config stuff
Global Const $Au3Config = "Au3ExConfig.ini"

; Start
_Main()

Func _Main()
	_Append("Welcome to Project Etal's Autoit3 Extension!")
	_Append("---------------------------------")
	_Setup()
	;_LaunchManager() ; removed for use of run profile button
	Local $SaidReady = False
	$ReconnectTimeout = 0
	$ReconnectTimer = TimerInit()
	$Reconnect = True

	While 1
		$gMsg = GUIGetMsg()
		Select
			Case $gMsg = $GUI_EVENT_CLOSE
				Exit
			Case $gMsg = $RUNPROFILE
				_RunProfile()
		EndSelect

		If ($Reconnect = True And TimerDiff($ReconnectTimer) >= $ReconnectTimeout) Then
			$ReconnectTimeout = Random(1200000, 3000000)
			$ReconnectTimer = TimerInit()
			_Append("Trying to connect, please wait...")
			If _Connect() = False Then
				$Reconnect = True
				_Append("Re-trying connection in about " & Round($ReconnectTimeout / 60000) & " minutes.")
			Else
				$Reconnect = False
				$ConnectedIP = _SocketToIP($ConnectedSocket)
			EndIf
		Else
			_CheckNewPackets()
		EndIf
		If ($SaidReady = False) Then
			$SaidReady = True
			_Append("Ready to rock!")
			_Append("---------------------------------")
		EndIf
	WEnd
EndFunc   ;==>_Main

Func _Connect()
	$ConnectedSocket = TCPConnect($ServerIP, $ServerPort)
	If @error Then
		_Append("Connection failed.")
		_Append("---------------------------------")
		Return False
	Else
		_Append("Connected!")
		_Append("---------------------------------")
		Local $UserInfo = _RetrieveUserInfo()
		TCPSend($ConnectedSocket, $PacketETALUserInfo & $UserInfo & $PacketEND)
		Return True
	EndIf
EndFunc   ;==>_Connect

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
			; Add reconnect attempts
	EndSwitch
EndFunc   ;==>_ProcessFullPacket

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

Func _RetrieveUserInfo()
	$MyUserName = IniRead($Au3Config, "Settings", "Username", "")
	$MyNickName = IniRead($Au3Config, "Settings", "Nickname", "")
	$MyRevision = IniRead($Au3Config, "Settings", "Revision", "")
	Local $DataString = _GetIP() & $PacketDivider & $MyUserName & $PacketDivider & $MyNickName & $PacketDivider & $MyRevision
	Return $DataString
EndFunc   ;==>_RetrieveUserInfo

Func _Setup()
	If FileExists(@ScriptDir & "/" & $Au3Config) Then
		Local $NTBotGame = FileOpen(@ScriptDir & "/" & "scripts/NTBot/NTBotGame.ntj", 0)
		Local $Line = FileReadLine($NTBotGame, 3)
		Local $Rev = StringMid($Line, 12, 2)
		If $Rev = "" Then
			$Rev = 0
		EndIf
		IniWrite($Au3Config, "Settings", "Revision", $Rev)
		Return
	Else
		Local $Name = InputBox("Setup", "" & _
				"Welcome to the Project Etal Au3 Extension Setup." & _
				@CRLF & @CRLF & "Please enter your Username.  If you " & _
				"haven't registered a Username at ProjectEtal.com, leave this blank.", "")

		If $Name = "" Then
			Local $URL = "http://www.projectetal.com/forums/index.php?login/"
			Local $fd = FileOpen(@TempDir & "url.url", 2)
			If $fd = -1 Then Exit
			FileWriteLine($fd, "[InternetShortcut]")
			FileWriteLine($fd, "URL=" & $URL)
			FileClose($fd)
			Run(@ComSpec & " /c " & Chr(34) & @TempDir & "url.url" & Chr(34))
			Sleep(1000)
			MsgBox(0, "Register", "Register an account, then re-run the Au3Extension.")
			Exit
		EndIf

		Local $Nick = InputBox("Setup", "" & _
				"Welcome to the Project Etal Au3 Extension Setup." & _
				@CRLF & @CRLF & "Please enter a Nickname.  This can be anything you " & _
				"would like.", "")

		Local $NTBotGame = FileOpen(@ScriptDir & "/" & "scripts/NTBot/NTBotGame.ntj", 0)
		Local $Line = FileReadLine($NTBotGame, 3)
		Local $Rev = StringMid($Line, 12, 2)
		If $Rev = "" Then
			$Rev = 0
		EndIf
		IniWrite($Au3Config, "Settings", "Username", $Name)
		IniWrite($Au3Config, "Settings", "Nickname", $Nick)
		IniWrite($Au3Config, "Settings", "Revision", $Rev)
	EndIf
EndFunc   ;==>_Setup

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
			Console($account, "Sending " & $content)
			_SendMinimized($wParam, $content)
		Case $NTAu3_KEY_LEFT
			$coords = StringSplit($content, ",")
			Console($account, "Clicking [" & $coords[1] & "," & $coords[2] & "]")
			_MouseClickMinimized($wParam, $dwData, Int($coords[1]), Int($coords[2]))
		Case $NTAu3_KEY_RIGHT
			$coords = StringSplit($content, ",")
			Console($account, "Right-Clicking [" & $coords[1] & "," & $coords[2] & "]")
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
			Console($account, "Running " & $content)
			SelectProfile($acc)
			ClickRun()
			EnterPassword($pass)
		Case $NTAu3_STOPPROFILE ; 12
			Console($account, "Stopping " & $content)
			SelectProfile($content)
			ClickStop()
		Case $NTAu3_MKDIR ; 21
			Console($account, "mkdir " & $content)
			DirCreate($content)
		Case $NTAu3_NAMEGAMETITLE
			WinSetTitle($wParam, "", $alldatanomodify)
			_Append("Debug: " & "Window title: " & $alldatanomodify)
		Case $NTAu3_MOVE_WINDOW
			Console($account, "Moving Window to " & $content)
			$coords = StringSplit($content, ",")
			MoveWindow($wParam, Int($coords[1]), Int($coords[2]))
		Case $NTAu3_MOVE_WINDOW_ANCHOR
			Console($account, "Anchoring Window to " & $content)
			MoveWindowToAnchor($wParam, Int($content))
	EndSwitch
EndFunc   ;==>ReceiveWMCopyData

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

Func _MakeLong($LoWord, $HiWord)
	Return BitOR($HiWord * 0x10000, BitAND($LoWord, 0xFFFF))
EndFunc   ;==>_MakeLong

Func _Timestamp()
	Local $TimeStamp = "[" & @HOUR & ":" & @MIN & ":" & @SEC & "]"
	Return $TimeStamp
EndFunc   ;==>_Timestamp

Func _Append($EditText)
	_GUICtrlEdit_AppendText($EDIT, _Timestamp() & " > " & $EditText & @CRLF)
EndFunc   ;==>_Append

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

Func Quit()
	If $ConnectedSocket <> -1 Then
		TCPSend($ConnectedSocket, $PacketConnectionClosed & $PacketEND)
	EndIf
	TCPCloseSocket($ConnectedSocket)
	TCPShutdown()
	Exit
EndFunc   ;==>Quit

Func Timestamp($account)
	$ampm = "AM"
	If (@HOUR / 12) >= 1 Then
		$ampm = "PM"
	EndIf
	$hour = Mod(@HOUR, 12)
	If $hour == 0 Then
		$hour = 12
	EndIf
	Return "[" & $hour & ":" & @MIN & ":" & @SEC & " " & $ampm & " " & $account & "] "
EndFunc   ;==>Timestamp

Func Console($account, $message)
	_Append($account & " " & $message)
EndFunc   ;==>Console

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

Func _RunProfile()
	Local $profile = InputBox("Run Profile", "Please enter the profile to start", "")
	Local $password = InputBox("Password", "Please enter the password for this account", "", "*")

	If $profile <> "" Then
		If $password <> "" Then
			If Not WinExists("ETAL Manager 3.165") Then
				_LaunchManager()
			EndIf

			While Not WinExists("ETAL Manager 3.165")
				Sleep(333)
			WEnd

			SelectProfile($profile)
			ClickRun()

			Sleep(333)

			EnterPassword($password)
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

Func ClickRun()
	ControlClick("ETAL Manager", "", "[CLASSNN:Button1]")
EndFunc   ;==>ClickRun

Func ClickStop()
	ControlClick("ETAL Manager", "", "[CLASSNN:Button2]")
EndFunc   ;==>ClickStop

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