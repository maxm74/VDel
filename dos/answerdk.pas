Unit AnswerDk;

interface
 Uses Dos;

function IsWild(S: String): Boolean;
function DriveValid(Drive: Char): Boolean;
function PathValid(Path: PathStr): Boolean;
function ValidFileName(FileName: PathStr): Boolean;
function FileExist(FileName: PathStr) :Boolean;
function IsDir(S: String): Boolean;
function CurrentDir(Drive: Char):DirStr;
function GetCurDrive: Char;
Function DrvTpy(Drv:Byte):Byte;

implementation

function IsWild(S: String): Boolean;
begin
  IsWild := (Pos('?',S) > 0) or (Pos('*',S) > 0);
end;

function DriveValid(Drive: Char): Boolean; assembler;
asm
	MOV	AH,19H          { Save the current drive in BL }
        INT	21H
        MOV	BL,AL
 	MOV	DL,Drive	{ Select the given drive }
        SUB	DL,'A'
        MOV	AH,0EH
        INT	21H
        MOV	AH,19H		{ Retrieve what DOS thinks is current }
        INT	21H
        MOV	CX,0		{ Assume false }
        CMP	AL,DL		{ Is the current drive the given drive? }
	JNE	@@1
        MOV	CX,1		{ It is, so the drive is valid }
	MOV	DL,BL		{ Restore the old drive }
        MOV	AH,0EH
        INT	21H
@@1:	XCHG	AX,CX		{ Put the return value into AX }
end;


function PathValid(Path: PathStr): Boolean;
var
  ExpPath: PathStr;
  F: File;
  SR: SearchRec;

begin
  ExpPath := FExpand(Path);
  if Length(ExpPath) <= 3 then PathValid := DriveValid(ExpPath[1])
  else
  begin
    if ExpPath[Length(ExpPath)] = '\' then Dec(ExpPath[0]);
    FindFirst(ExpPath, Directory, SR);
    PathValid := (DosError = 0) and (SR.Attr and Directory <> 0);
  end;
end;

function ValidFileName(FileName: PathStr): Boolean;
const
  IllegalChars = ';,=+<>|"[] \';
var
  Dir: DirStr;
  Name: NameStr;
  Ext: ExtStr;

{ Contains returns true if S1 contains any characters in S2 }
function Contains(S1, S2: String): Boolean; near; assembler;
asm
	PUSH	DS
        CLD
        LDS	SI,S1
        LES	DI,S2
        MOV	DX,DI
        XOR	AH,AH
        LODSB
        MOV	BX,AX
        OR      BX,BX
        JZ      @@2
        MOV	AL,ES:[DI]
        XCHG	AX,CX
@@1:	PUSH	CX
	MOV	DI,DX
	LODSB
        REPNE	SCASB
        POP	CX
        JE	@@3
	DEC	BX
        JNZ	@@1
@@2:	XOR	AL,AL
	JMP	@@4
@@3:	MOV	AL,1
@@4:	POP	DS
end;

begin
  ValidFileName := True;
  FSplit(FileName, Dir, Name, Ext);
  if not ((Dir = '') or PathValid(Dir)) or Contains(Name, IllegalChars) or
    Contains(Dir, IllegalChars) then ValidFileName := False;
end;

function FileExist(FileName: PathStr) :Boolean;
Var
   f :File;

begin
     FileExist :=False;
     if ValidFileName(FileName) Then
     begin
          Assign(f, FileName);
         {$I-}
              Reset(f);
              if IoResult=0 Then FileExist :=True;
              Close(f);
         {$I+}
     end;
end;

function IsDir(S: String): Boolean;
var
  SR: SearchRec;
begin
  FindFirst(S, Directory, SR);
  if DosError = 0 then
    IsDir := SR.Attr and Directory <> 0
  else IsDir := False;
end;

function CurrentDir(Drive: Char):DirStr;
Var
   Buf        : Array[0..64] of Char;
   Ofsx, Segx : Word;
   S          : DirStr;

begin
     Drive :=UpCase(Drive);
     S :=Drive+':\';
     Segx :=Seg(Buf);
     Ofsx :=Ofs(Buf);
     asm
        PUSH SI
        PUSH DS

        SUB Drive,64      { 1 = A ; 2 = B ... }
        MOV DL,Drive
        MOV SI,Ofsx
        MOV AX,Segx
        MOV DS,AX
        MOV AX,4700h
        INT 21h

        POP DS
        POP SI
      end;
     Ofsx :=0;
     While ( Ofsx<65 ) and ( Buf[Ofsx]<>#0 ) Do
     begin
          S:=S+Buf[Ofsx];
          Inc(Ofsx);
      end;
     CurrentDir :=S;
end;

function GetCurDrive: Char; assembler;
asm
   MOV	AH,19H
   INT	21H
   ADD	AL,'A'
end;

{--------------------- Funzioni Di Rilevamento-Diagnostica ------------------}
Function DrvTpy(Drv:Byte):Byte; assembler;
asm
   MOV AX,4408h         { Is Drive Removable? }
   MOV BL,Drv
   INT 21h
   JC @Err              { Quit With Error }
   MOV CL,AL            { CL = 0000xxxx }
   SHL CL,4             { CL = xxxx0000 }
   MOV AX,4409h         { Is Drive Local? }
   INT 21h
   JC @Err              { Quit With Error }
   AND DX,1000h         { Del di tutti i Bit Tranne il 12§ }
   SHL DX,4             { Bit 12 in CF    }
   RCR CL,1             { CL = cxxxx000 }
   MOV AX,440Eh         { Is a Double Letter Drive? }
   INT 21h
   JNC @2
    {------ Test if Is a RamDrive ------}
    CMP AX,1            { Invalid Function Req.? }
    JNZ @Err            { no: Quit With Error }
    CMP CL,08           { Local+Fixed?     }
    JNZ @Err
     PUSH DS            {yes}
     MOV AH,1Ch
     MOV DL,Drv
     INT 21h            { DS:BX Ä> FATID }
     MOV AL,[BX]        { AL = FATID }
     POP DS
     CMP AL,0F8h        { DOS Consider Hard-Disk? }
     JNZ @Err
     MOV CL,02          { Local+RamDrive }
     JMP @Ok
  @2:
   CMP AL,Drv
   JNZ @DifZer          { if Drive=Letter Ä> ddd=000 }
   MOV AL,0
  @DifZer:
          SHL AL,5             { Bit 3 in CF  &  AL = ddd00000 }
          JNC @Min8
           MOV AL,0E0h         { ddd=111 if >8 }
          @Min8:
                SHR AL,5       { AL =00000ddd }
                MOV DL,3
                @1:
                   SHR AL,1
                   RCR CL,1
                   DEC DL
                   JNZ @1
                        { CL = dddcxxxx }
   JMP @Ok
   @Err:
        MOV CL,0Fh
   @Ok :                 { Return = dddcxxxx }
        MOV AL,CL        {       ÚÄÄÁÄÙ³ÀÄÄÁÄÄ Floppy/Fixed/RamDrv/Invalid     }
                         { Double Num  ³          0      1    2      F         }
                         {             Local/Remote[0/1]                       }
end;

end.
