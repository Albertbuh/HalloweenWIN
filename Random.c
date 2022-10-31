Random.Initialize:
	invoke	GetTickCount

	mov	[Random.dPrewNumber], eax

	ret

proc	Random.Get uses ecx edx,\
	dwMin,dwMax

	
	mov	eax, [Random.dPrewNumber]
	rol	eax, 7
	adc	eax, 23;B	
	mov	[Random.dPrewNumber], eax

	mov	ecx, [dwMax]
	sub	ecx, [dwMin]
	inc	ecx
	xor	edx,edx 
	div	ecx	
	add 	edx, [dwMin]
	add	eax, edx
	ret
endp