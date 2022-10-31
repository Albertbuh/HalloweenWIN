format	PE GUI 4.0
entry	Start

include 'win32a.inc'


ms=1000
curTID=0
bkgTID=1
ghostsoundTID=2
textTID=3
LMODE=12
section '.data' data readable writeable

_class	TCHAR	'FASMWIN32',0
_title	TCHAR	'HALLOWEENWIN',0
_error	TCHAR	'Startup failed', 0
wc	WNDCLASS  0, WindowProc,0,0,NULL,NULL,NULL,COLOR_WINDOWTEXT,NULL, _class

msg	MSG
ps	PAINTSTRUCT

hIcon	dd	?
hCursor dd	?
hBitmap dd	?
hdc	dd	?
hMemDC	dd	?

Random.dPrewNumber	dd ?

SCREENX dd	?
SCREENY dd	?
CursorID	dd	CURSORG
cAdd		dd	1
curPos		POINT



pumpkinSound	db 'play sounds\laugh.mp3 ',0
pumpkinSound2	db 'play sounds\highlaugh.mp3',0
ravenSound	  db 'play sounds\vorona.mp3',0
ghostSound	  db 'play sounds\ghost.mp3', 0

bkgSound	db 'play sounds\bkgmusic.mp3',0

textvisibleX	dd	0
ClearRect	RECT


pumpkinTrigerArea     RECT    525,400, 650,550
pumpkinTrigerArea2     RECT  650,400,775,550
ravenTrigerArea       RECT    550,150, 700,350
section '.code' code readable executable

Start:
    ;========= fill WNDCLASS struct ===================
	invoke	GetModuleHandle, 0
	mov	[wc.hInstance], eax
	invoke	LoadIcon, eax, ICONS	;name of icon_group resource
	mov	[wc.hIcon], eax
	invoke	LoadCursor, [wc.hInstance], CURSORG
	mov	[wc.hCursor], eax
	invoke	SetCursor, eax
	invoke	RegisterClass, wc
	test	eax, eax
	jz	error

;Set Screen SIZE
      ;  invoke  GetSystemMetrics, SM_CXSCREEN
	mov	[SCREENX], 800
       ; invoke  GetSystemMetrics, SM_CYSCREEN
	mov    [SCREENY], 600


; WIN CREATION
	invoke	 CreateWindowEx, 0, _class, _title, WS_VISIBLE+WS_SYSMENU,\;+WS_OVERLAPPEDWINDOW,\
			0,0, [SCREENX],[SCREENY],\
			NULL,NULL,[wc.hInstance],NULL
	test		 eax,eax
	jz		 error

  msg_loop:
	invoke	GetMessage,msg,0,0,0
	cmp	eax, 1
	jb	end_loop
	jne	msg_loop
       ; invoke  TranslateMessage,msg
	invoke	DispatchMessage,msg
	jmp	msg_loop

error:
	invoke MessageBox,NULL, _error,NULL,MB_OK+MB_ICONERROR

end_loop:
	invoke	ExitProcess,[msg.wParam]

proc	WindowProc uses ebx esi edi,  hwnd, wmsg, wparam, lparam
	 mov		eax, [wmsg]
	 cmp		eax, WM_CREATE
	 je		.wm_create
	 cmp		eax, WM_KEYDOWN
	 je		.wm_destroy
	 cmp		eax, WM_LBUTTONDOWN
	 je		.wm_lbuttondown
	 cmp		eax, WM_PAINT
	 je		.wm_paint
	 cmp		eax, WM_DESTROY
	 je		.wm_destroy
.defwndproc:
	 invoke DefWindowProc, [hwnd], [wmsg], [wparam], [lparam]
	 jmp	.finish

.wm_create:
	  Call	Random.Initialize
; SEND	OUR MP3 TO MCI(media control interface)
	  invoke	mciSendString, bkgSound,0,0,0

       ;   invoke	 SendMessage, [hwnd],WM_SYSCOMMAND,SC_MAXIMIZE,0

;CREATE DOUBLE BUFFER
	  invoke	GetDC, [hwnd]	    ; get device context handle
	  mov		[hdc], eax
	  invoke	CreateCompatibleDC, [hdc] ;create double buffer
	  mov		[hMemDC], eax

;SET TIMERS
	  invoke	SetTimer,  [hwnd], curTID, 100,CursorTimerProc
	  invoke	SetTimer, [hwnd], bkgTID, 130*ms, BKGTimer
	  invoke	SetTimer, [hwnd], ghostsoundTID, 20*ms, GhostTimer
	  invoke	SetTimer, [hwnd], textTID, 30, TextTimer
	  jmp		.finish

.wm_paint:
	invoke	BeginPaint, [hwnd], ps
	mov	[hdc], eax

;DRAW BKG
	invoke	      LoadBitmap, [wc.hInstance], BKG
	mov	      [hBitmap], eax
	invoke	SelectObject, [hMemDC], [hBitmap]
	invoke	BitBlt, [hdc], 0,0,[SCREENX],[SCREENY],[hMemDC],0,0,SRCCOPY
	invoke	DeleteObject, [hBitmap]

;DRAW	TEXT_MASK
	invoke	LoadBitmap, [wc.hInstance], HALLOWEENMASK
	mov	[hBitmap], eax
	invoke	SelectObject, [hMemDC], [hBitmap]
	invoke	BitBlt, [hdc], 0,0,[textvisibleX],[SCREENY],[hMemDC],0,0,SRCAND
	invoke	DeleteObject, [hBitmap]
;DRAW	TEXT
	invoke	LoadBitmap, [wc.hInstance], HALLOWEEN
	mov	[hBitmap], eax
	invoke	SelectObject, [hMemDC], [hBitmap]
	invoke	BitBlt, [hdc], 0,0,[textvisibleX],[SCREENY],[hMemDC],0,0,SRCPAINT
	invoke	DeleteObject, [hBitmap]

      ;  invoke  DrawText, [hdc], _title, -1,pumpkinTrigerArea,DT_CENTER
	invoke	EndPaint, [hwnd], ps
	jmp	.finish

.wm_lbuttondown:
	invoke	GetCursorPos, curPos
	mov	eax,	      [curPos.x]
	mov	edx,	      [curPos.y]

;PLAY SOUND ACCORDINT TO LEFT MOUSE CLICK
	stdcall CreateSoundTrigger, pumpkinTrigerArea,pumpkinSound
	stdcall CreateSoundTrigger, ravenTrigerArea,ravenSound
	stdcall CreateSoundTrigger, pumpkinTrigerArea2, pumpkinSound2
	jmp	.finish
.wm_destroy:
	invoke	DeleteDC, [hMemDC]
	invoke	PostQuitMessage,0
	xor	eax,eax

.finish:
	ret
endp

proc	CreateSoundTrigger uses eax edx edi,\
			   pTriggerArea, sound

	mov	edi, [pTriggerArea] ;EDI <- RECT STRUCT
	cmp	eax, [edi]  ;LEFT
	jbe	 @f
	cmp	 edx, [edi+4] ;TOP
	jbe	 @f
	cmp	 eax, [edi+8] ;RIGHT
	jae	 @f
	cmp	 edx, [edi+12] ;BOTTOM
	jae	 @f

; SEND	OUR MP3 TO MCI(media control interface)
	invoke	 mciSendString, [sound], NULL,0,NULL
@@:
	ret
endp

proc	TextTimer, hwnd,wmsg,wparam,lparam

	cmp	[textvisibleX], 390
	jbe	@f
	invoke	KillTimer,[hwnd],3
	jmp	.end
@@:
	mov	eax, [textvisibleX]
	sub	eax,3
	mov	[ClearRect.left],eax
	mov	[ClearRect.top],0
	add	eax,4
	mov	[ClearRect.right], eax
	mov	[ClearRect.bottom],300
;SEND MESSAGE TO REDRAW NECESSARY RECT
	invoke	InvalidateRect, [hwnd],ClearRect, TRUE
       ; invoke  InvalidateRect, [hwnd], pumpkinTrigerArea2, TRUE
	add	[textvisibleX],4
.end:
	ret
endp

proc	GhostTimer
	stdcall 	Random.Get,0,10
	cmp		eax, 5
	jbe		@f

; SEND	OUR MP3 TO MCI(media control interface)
	invoke	mciSendString, ghostSound,0,0,0
@@:
	ret
endp

proc	BKGTimer

; SEND	OUR MP3 TO MCI(media control interface)
	invoke	      mciSendString, bkgSound,0,0,0
	ret
endp

;CHECK IF CURSOR IN TRIGGER AREA
proc	CurInRect uses edi,\
	pTriggerArea
	mov	eax,	      [curPos.x]
	mov	edx,	      [curPos.y]

	mov	edi, [pTriggerArea] ;EDI <- RECT STRUCT
	cmp	eax, [edi]  ;LEFT
	jbe	 .end
	cmp	 edx, [edi+4] ;TOP
	jbe	 .end
	cmp	 eax, [edi+8] ;RIGHT
	jae	 .end
	cmp	 edx, [edi+12] ;BOTTOM
	jae	 .end
	mov	 eax, LMODE
.end:
	ret
endp

proc	CurMode
	invoke	GetCursorPos, curPos
;CHECK IF CURSOR IN TRIGGER AREA
	stdcall CurInRect, pumpkinTrigerArea
	cmp	eax, LMODE
	je	.on_light_mode
	stdcall CurInRect, pumpkinTrigerArea2
	cmp	eax, LMODE
	je     .on_light_mode
	stdcall CurInRect, ravenTrigerArea
	cmp	eax, LMODE
	je     .on_light_mode

       cmp	[CursorID], CURSORG+3
       jbe	.end
       mov	[CursorID], CURSORG
       jmp	.end
.on_light_mode:
       cmp	[CursorID], CURSORG+4
       jae	.end
       mov	[CursorID], CURSORG+4
.end:
	ret
endp

proc	CursorTimerProc

	stdcall CurMode   ;Set CursorID value

;ANIMATE CURSOR WITH LIGHTNING
.light_mode:
	cmp	[CursorID], CURSORG+4
	jb	.normal_mode
	ja	@f
	mov	[cAdd], 1
@@:
	cmp	[CursorID],CURSORG+7
	jne	@f
	mov	[cAdd], -1
@@:
	mov	eax, [cAdd]
	add	[CursorID], eax
	invoke	LoadCursor, [wc.hInstance], [CursorID]
	invoke	   SetCursor, eax
	jmp	.end

;ANIMATE CURSOR WITHOUT LIGHTNING
.normal_mode:
	cmp	[CursorID], CURSORG
	jne	@f
	mov	[cAdd], 1
@@:
	cmp	[CursorID],CURSORG+3
	jne	@f
	mov	[cAdd], -1
@@:
	mov	eax, [cAdd]
	add	[CursorID], eax
	invoke	LoadCursor, [wc.hInstance], [CursorID]
	invoke	   SetCursor, eax
.end:
	ret
endp
	include 'random.c'

section '.idata' import data readable writeable

library kernel32, 'KERNEL32.DLL',\
	gdi32,	  'GDI32.DLL',\
	user32,   'USER32.DLL',\
	winmm,'WINMM.DLL'	;,strmiids,'Strmiids.DLL'

include  'api\kernel32.inc'
include  'api\gdi32.inc'
include  'api\user32.inc'

import winmm,\
mciSendString,'mciSendStringA'

section '.rsrc'  resource data readable
BKG=10
CURSOR=20
CURSORG=30
HALLOWEEN=40
HALLOWEENMASK=41
ICONS=70
directory	RT_BITMAP, bitmaps,\
		RT_CURSOR, cursors,\
		RT_GROUP_CURSOR,group_cursors,\
		RT_ICON, icons,\
		RT_GROUP_ICON, group_icons

resource	bitmaps,\
		BKG, LANG_NEUTRAL, background,\
		HALLOWEEN,LANG_NEUTRAL, halloween,\
		HALLOWEENMASK,LANG_NEUTRAL,mask
resource	icons,\
		ICONS+1, LANG_NEUTRAL, bat_128,\
		ICONS+2, LANG_NEUTRAL, bat_64,\
		ICONS+3, LANG_NEUTRAL, bat_32,\
		ICONS+4, LANG_NEUTRAL, bat_16
resource	group_icons,\
		ICONS, LANG_NEUTRAL, main_icon
resource	cursors,\
		CURSOR,LANG_NEUTRAL,   ghost1,\
		CURSOR+1,LANG_NEUTRAL, ghost2,\
		CURSOR+2,LANG_NEUTRAL, ghost3,\
		CURSOR+3,LANG_NEUTRAL, ghost4,\
		CURSOR+4,LANG_NEUTRAL, ghostl1,\
		CURSOR+5,LANG_NEUTRAL, ghostl2,\
		CURSOR+6,LANG_NEUTRAL, ghostl3,\
		CURSOR+7,LANG_NEUTRAL, ghostl4
resource	group_cursors,\
		CURSORG, LANG_NEUTRAL,	 g1,\
		CURSORG+1, LANG_NEUTRAL, g2,\
		CURSORG+2, LANG_NEUTRAL, g3,\
		CURSORG+3, LANG_NEUTRAL, g4,\
		CURSORG+4, LANG_NEUTRAL, gl1,\
		CURSORG+5, LANG_NEUTRAL, gl2,\
		CURSORG+6, LANG_NEUTRAL, gl3,\
		CURSORG+7, LANG_NEUTRAL, gl4



bitmap	background, 'background3.bmp'
bitmap	halloween, 'Halloween.bmp'
bitmap	mask,	   'HalloweenMask.bmp'

icon	main_icon, bat_128, 'icons/bat128.ico',\
		   bat_64, 'icons/bat64.ico',\
		   bat_32, 'icons/bat32.ico',\
		   bat_16, 'icons/bat16.ico'

cursor	g1, ghost1, 'cursors/GhostUp1.cur'
cursor	g2, ghost2, 'cursors/GhostUp2.cur'
cursor	g3, ghost3, 'cursors/GhostUp3.cur'
cursor	g4, ghost4, 'cursors/GhostUp4.cur'

cursor	gl1, ghostl1, 'cursors/GhostUpl1.cur'
cursor	gl2, ghostl2, 'cursors/GhostUpl2.cur'
cursor	gl3, ghostl3, 'cursors/GhostUpl3.cur'
cursor	gl4, ghostl4, 'cursors/GhostUpl4.cur'





