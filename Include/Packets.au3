#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.8.1
 Author:         Everyone

 Script Function:
	Packet Defines

#ce ----------------------------------------------------------------------------

; Script Start - Add your code below here

; Packet stuff
Global Const $PacketETALError = "[PACKET_ETAL_0001]" ; Etal Script Erorrs
Global Const $PacketETALTicket = "[PACKET_ETAL_0002]" ; Tickets
Global Const $PacketETALDClone = "[PACKET_ETAL_0003]" ; Diablo Close spawn
Global Const $PacketETALUserInfo = "[PACKET_ETAL_0004]" ; User information
Global Const $PacketETALDebug = "[PACKET_ETAL_0005]" ; Debug information
Global Const $PacketETALOutOfDate = "[PACKET_ETAL_0006]" ; New revision notifications
Global Const $PacketETALSojs = "[PACKET_ETAL_0007]"

Global Const $PacketETALLogin = "[PACKET_ETAL_7777]"
Global Const $PacketETALAnnouncement = "[PACKET_ETAL_1000]" ; Announcements

Global Const $PacketConnectionClosed = "[PACKET_ETAL_9999]" ; Connection being killed

Global Const $PacketDivider = "[PACKET_SPLIT]" ; Divider
Global Const $PacketEND = "[PACKET_END]" ; Defines the end of a packet