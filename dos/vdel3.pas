{**********************************}
{*                                *}
{*  Massimo Magnano   08-03-1996  *}
{*                                *}
{*  Very Del   Ver 3,0            *}
{*                                *}
{*  Programma per l'eliminazione  *}
{*  fisica (non recuperabile) di  *}
{*  Files.  Questo programma  fa  *}
{*  parte delle Utility in PCM3.  *}
{*                                *}
{**********************************}

{$F+,V-,X+,R-,I-,S-,Q-,T-,G+,B-,A+}
Program VDel;
Uses Crt, Dos, Drivers, AnswerDk;
Const
     Signature='  Very Del   Version 3,01   Massimo Magnano  08-03-1996,1999';
(*     EnNoBuy  :String='g%UR'#7'aQ/>œýê'#15'èùW'#19'tå3'#23+
                      ' áÎÏL<*‹'#8'Ù"v'#21'uÆÇÄ';
*)
     NoMoreFile=18;
     AnyDir    =$1F;
     OnlyFile  =$27;
     MaxWild   =60;
     opReqConf =$01;    {Richiesta conferma}
     opRecurse =$02;    {Ricorsione Sub-Dir}
     opDelDir  =$04;    {Cancella Dir Vuota}
     opFisicDel=$08;    {UnRecover Del File}
     opNewName =$10;    {Nuovo Nome x  File}
     opNewAttr =$20;    {Nuovo Attr x  File}
     opNewDate =$40;    {Nuova Data x  File}
     opNewSize =$80;    {Nuova Dim. x  File}
     Anim :array[0..3] of Char =('|', '/', 'Ä', '\');

Type
    PBuf =^Buf;
    Buf  =array[0..65534] of Char;
    Str12=String[12];
    WildRec =Record
                   OpzDesc  :Byte;
                   Filler   :Char;
                   NewName  :String[9];
                   NewAttr  :Byte;
                   NewDate  :LongInt;
                   NewSize  :Word;
                   Wild     :String[80];
               end;
    WildList=array[1..MaxWild] of WildRec;  {Lista Files e Opzioni}

Var
   AWild    :WildList;
   Path,
   St       :String[128];
   AName    :NameStr;
   AExt     :ExtStr;
   CurDel,
   nPar     :Byte;
   mSiz     :Word;
   Data     :PBuf;
   LineView :String[70];

{
 Visualizza la non commercializzazione di questo prodotto.
}

Function DecryptNoBuy(St:String):String;
Var
   Chx  :Char;
   i    :Byte;

begin
     For i:=1 to Length(St) Do
     begin
          Chx :=St[i];
          asm
             MOV AL,i
             XOR Chx,AL
             ROL Chx,4
          end;
          St[i] :=Chx
      end;
     DecryptNoBuy :=St;
end;

{
  L'Opzione Who Š settata nella selezione corrente?.
}
Function IsSet(Who:Byte):Boolean;
begin
     IsSet :=(AWild[CurDel].OpzDesc and Who=Who);
end;

{
  Chiede conferma per la genitrice (se opzione "-c" settata).
}
Function Confirm(WildStr:String) :Boolean;
Var
   ChConf   :Char;
   LineX    :Byte;

begin
     Confirm :=True;
     if IsSet(opReqConf) Then
     begin
          Write('  Delete ',WildStr,'  (S\N)'#10);
          LineX :=WhereX;
          Repeat
                Gotoxy(LineX, WhereY-1); Clreol;
                Readln(ChConf);
          Until ChConf in['S','s','N','n'];
          if ChConf in['N','n'] Then Confirm :=False;
      end;
end;

{
 Visualizza St nella Posizione corrente,
 memorizza in LineView per poterla ripristinare dopo la visualizzazione
 di un errore di I/O.
 Se ClearLine Š True viene cancellata la riga a partire dalla posizione
 corrente del cursore.
}
Procedure Display(St :String; ClearLine:Boolean);
begin
     if ClearLine Then
     begin
          Delete(LineView, WhereX, 255);
          Clreol; Write(St);
          LineView :=LineView+St;
      end
     else
     begin
          Delete(LineView, WhereX, Byte(St[0]));
          Insert(St, LineView, WhereX);
          Write(St);
      end;
end;

{
 Se Š settata l'opzione "-d" e la Directory ADir Š Vuota viene rimossa.
}
Procedure RemoveDirct(ADir :String);
Var
   Test :SearchRec;

begin
     if IsSet(opDelDir) and PathValid(ADir) Then
     begin
          FindFirst(ADir+'*.*', AnyFile, Test);
          While (DosError=0) and (Test.Name[1]='.') Do FindNext(Test);
          if DosError=NoMoreFile
          then begin
                    FindClose(Test);
                    Display('RemoveDirectory...', False);
                    Dec(ADir[0]);
                    RmDir(ADir);
                    Inc(ADir[0]);
               end
          else FindClose(Test);
      end;
end;

{
 Cancellazione del File e cambio dei propri parametri
 (Size, Attr, Name, etc..) in base alle opzioni della
 selezione corrente.
}
Procedure DelFile(ADir, FilName:String);
Var
   f       :File;
   nWr     :Word;
   nRemain :LongInt;
   OldAttr :Word;
   Date1,
   Date2   :DateTime;
   fTime   :LongInt;
   aCount  :Byte;

begin
     Assign(f, ADir+FilName);
     if (DosError=0) Then
     begin
          if IsSet(opNewAttr) Then SetFAttr(f, AWild[CurDel].NewAttr);
           if DosError<>0 Then Exit;
          GetFAttr(f, OldAttr);if DosError<>0 Then Exit;
          SetFAttr(f, Archive);if DosError<>0 Then Exit;
          Reset(f, 1);
          if IsSet(opNewDate) then
          begin
               UnPackTime(AWild[CurDel].NewDate, Date1);
               if (Date1.Month=14) and (Date1.Day=31) and (Date1.Year=2046)
               then {cambia Solo l'orario}
                   begin
                      if (Date1.Min=62) and (Date1.Sec=62) and (Date1.Hour=14)
                      then {cambia Solo la data}
                        fTime :=$210000 {1-1-1980,0:0.0}
                      else
                          begin
                             GetFTime(f, fTime); UnpackTime(fTime, Date2);
                             {--- Copia il nuovo orario ---}
                             Move(Date1.Hour, Date2.Hour, 6);
                             PackTime(Date2, fTime);
                           end;
                    end
               else if (Date1.Min=62) and (Date1.Sec=62) and (Date1.Hour=14)
                    then {cambia Solo la data}
                        begin
                           GetFTime(f, fTime); UnpackTime(fTime, Date2);
                           {--- Copia la nuova data ---}
                           Move(Date1, Date2, 6);
                           PackTime(Date2, fTime);
                         end
                    else fTime :=AWild[CurDel].NewDate;
               SetFTime(f, fTime);
           end;
           if DosError<>0 Then Exit;
          if IsSet(opFisicDel)
          then begin
                    Display('Unrec-Del '+FilName+' ', False);
                    Seek(f, 0);
                    if IsSet(opNewSize)
                    then begin
                            Truncate(f);
                            nRemain :=AWild[CurDel].NewSize
                          end
                    else nRemain :=FileSize(f);
                    nWr :=0;
                    aCount :=0;
                    if DosError<>0 Then Exit;
                    Repeat
                     Write(Anim[aCount]);
                     if nRemain>=mSiz then BlockWrite(f, Data^, mSiz, nWr)
                                      else BlockWrite(f, Data^, nRemain, nWr);
                     Dec(nRemain, nWr);
                     GotoXY(WhereX-1, WhereY);
                     inc(aCount);
                     if (aCount>3) then aCount :=0;
                    Until (nRemain<=0) or (DosError<>0);
                    if DosError<>0 Then Exit;
                    Close(f);
                    if IsSet(opNewName)
                     then Rename(f, ADir+AWild[CurDel].NewName);

                    if DosError<>0 Then Exit;
                    SetFAttr(f, OldAttr);
                    if DosError<>0 Then Exit;
               end
          else begin
                    Display('Logic-Del '+FilName, False);
                    Close(f);
                    if IsSet(opNewName)
                     then Rename(f, ADir+AWild[CurDel].NewName);
                end;
     end;
    if (DosError=0) Then Erase(f);
end;

{
 Cancellazione dei file selezionati nella directory BaseDir.
 Se Š settata l'opzione "-r" la procedura ricerca le eventuali
 Sub-Dir di BaseDir e richiama se stessa in modo ricorsivo
 finchŠ non si ritorna alla BaseDir e non ci sono pi— file che
 corrispondo alla selezione nŠ altre Sub-Dir.
}
Procedure CancelDir(BaseDir:String; SelName :Str12);
Var
   Sfile,
   Sdir  :SearchRec;
   LineX :Byte;

begin
     Display('Deleting Dir '+BaseDir+SelName+' ÄÄ>', False);
     LineX :=WhereX;
     FindFirst(BaseDir+SelName, OnlyFile, Sfile);
     While (DosError=0) Do
     begin
          if    (Sfile.Name[1]<>'.') and
             Not(Sfile.Attr in[Directory..AnyDir]) Then
          begin
               DelFile(BaseDir, Sfile.Name);
               Gotoxy(LineX, WhereY); ClrEol;
           end;
          FindNext(Sfile);
      end;
     if (DosError=NoMoreFile) and IsSet(opRecurse) Then
     begin
          FindFirst(BaseDir+'*.*', AnyDir, Sdir);
          While (DosError=0) Do
          begin
               if (Sdir.Name[1]<>'.') and
                  (Sdir.Attr in[Directory..AnyDir])Then
               begin
                    Gotoxy(1, WhereY); Display('', True);
                    CancelDir(BaseDir+Sdir.Name+'\', SelName);
                    Display('Deleting Dir '+BaseDir+SelName+' ÄÄ>', False);
                end;
               FindNext(Sdir);
           end;
      end;
     if (DosError=NoMoreFile) Then RemoveDirct(BaseDir);
     Gotoxy(1, WhereY); Display('', True);
end;

{
 Interrompe il programma con ExitCode=Val.
 Viene implementata sotto forma di Funzione che ritorna
 una stringa in modo da poter essere inserita in coda a
 una Write (come parametro "," e non aggiungendola alla
 stringa che si vuole visualizzare.
 Se Š usata con la Direttiva Pascal $X+ pu• essere
 chiamata come procedura.
}
Function Stop(Val:Word):String;
begin
     Stop :='';
     Halt(Val);
end;

{
 Visualizza la schermata dell'help (lista dei parametri)
 ed interrompe il programma con ExitCode chiamando Stop.
}
Procedure Help(ExitCode:Word);
begin
   Write(
    ' USAGE  :   VDel  [-|/Opzioni] File(s)...File(s) '+
                      '[-|/Opzioni] File(s)...File(s)'#13#10#10+
    '   opzioni : '#10);
   Writeln(
    '-?,-h             Questa Lista dei parametri.'+
    #13#10+
    '             -c                Richiesta conferma (per la genitrice).'+
    #13#10+
    '             -r                Ricorsione di tutte le SubDir.'+
    #13#10+
    '             -d                Rimuovi Directory se Vuota.');
   Writeln(
    '             -f[filler]        Cancellazione irrecuperabile riempi'+
    #13#10+
    '                                con filler ( DEFAULT=? ).'+
    #13#10+
    '             -n[NomeFIL]       Rinomina con NomeFIL ( DEFAULT=#VDel3##.### ).');
   Writeln(
    '             -a[Attr]          Assegna Nuovo Attr ( DEFAULT=0 ) al File.'+
    #13#10+
    '             -t[Date][\Time]   Assegna Date e\o Time ( DEFAULT=0 ) al File.'+
    #13#10+
    '                                Formato : GG-MM-AA\Hour.Min.Sec');
   Writeln(
    '             -s[DimByte]       Ridim. con DimByte ( DEFAULT=1 ) il File '+
    #13#10+
    '                                solo se Š attiva l''opzione -f.'
     , Stop(ExitCode));
end;

{
 Visualizza l'errore che si Š commesso
 nell'inserire i parametri.
}
Procedure ErrParam(ErrCode:Integer);
Const
     Par :array[0..4] of String[7]=('-? | -h','-c','-r','-d','-t');
Var
   ErrDesc : String[40];

begin
     Case ErrCode of
     $01:ErrDesc :='Parametro inesistente.';
     $12..$16:ErrDesc :='Formato parametro "'+Par[ErrCode-$12]+'" errato.';
     $9E:ErrDesc :='Filler non Valido.';
     $9F:ErrDesc :='Nuovo Nome non valido.';
     $A0:ErrDesc :='Nuovo Attributo non valido.';
     $A1:ErrDesc :='Nuova Data: Giorno errato.';
     $A2:ErrDesc :='Nuova Data: Mese   errato.';
     $A3:ErrDesc :='Nuova Data: Anno   errato.';
     $A4:ErrDesc :='Nuovo Orario: Ora     errata.';
     $A5:ErrDesc :='Nuovo Orario: Minuti  errati.';
     $A6:ErrDesc :='Nuovo Orario: Secondi errati.';
     $A7:ErrDesc :='Nuova Dimensione non valida.';
   end;
  Write('Parametri Errati (e',ErrCode,') : '+ErrDesc+
        #13#10+
        '         VDEL3 -?     per ottenere la lista dei parametri.'
        , Stop(100));
end;

{
 Funzione che gestice gli errori di I/O assegnandola a
 SysErrorFunc della Unit DRIVERS.
 E' possibile scegliere :
  ®R¯iprova l'operazione ;
  ®A¯nnulla l'operazione e continua con la prossima selezione ;
  ®S¯top  il programma .
}
function Io_Error(ErrorCode: Integer; Drive: Byte): Integer;
Var
   ErrSt    :String[36];
   LastAttr,
   LastX    :Byte;
   Color    :Word;

   Procedure ResetDiskSys; assembler;
   asm
      MOV AX,0
      INT 13h         {Reset Disk System}
   end;

begin
     Case ErrorCode of
      0     :ErrSt :=' Disk is write-protected in drive '+Char(65+Drive)+' ';
      1,3,5 :ErrSt :=' Critical disk error on drive '+Char(65+Drive)+' ';
      2     :ErrSt :=' Disk is not ready in drive '+Char(65+Drive)+' ';
      4     :ErrSt :=' Data integrity error on drive '+Char(65+Drive)+' ';
      6     :ErrSt :=' Seek error on drive '+Char(65+Drive)+' ';
      7     :ErrSt :=' Unknown media type in drive '+Char(65+Drive)+' ';
      8     :ErrSt :=' Sector not found on drive '+Char(65+Drive)+' ';
      9     :ErrSt :=' Printer out of paper ';
      10    :ErrSt :=' Write fault on drive '+Char(65+Drive)+' ';
      11    :ErrSt :=' Read fault on drive '+Char(65+Drive)+' ';
      12    :ErrSt :=' Hardware failure on drive '+Char(65+Drive)+' ';
      13    :ErrSt :=' Bad memory image of FAT detected ';
      14    :ErrSt :=' Device access error ';
      15    :ErrSt :=' Insert diskette in drive '+Char(65+Drive)+' ';
     end;
     LastAttr :=TextAttr; LastX :=WhereX;
     Color :=SysColorAttr;
     if LastMode in [0,2,7] Then Color :=SysMonoAttr;
     TextAttr :=Lo(Color); Gotoxy(1, WhereY); ClrEol;
     Write(ErrSt+'         ');
     TextAttr :=Hi(Color); Write('R');
     TextAttr :=Lo(Color); Write('iprova  ');
     TextAttr :=Hi(Color); Write('A');
     TextAttr :=Lo(Color); Write('nnulla  ');
     TextAttr :=Hi(Color); Write('S');
     TextAttr :=Lo(Color); Write('top');
     Repeat
           Case ReadKey of
           'r','R' : begin Io_Error :=0; Break; end;
           'a','A' : begin
                          Io_Error :=1;
                          ResetDiskSys; Break;
                      end;
           's','S' : begin
                          Io_Error :=1;
                          ResetDiskSys; Stop(1);
                      end;
           end;
           Sound(800); delay(60); NoSound;
     Until False;  {Uscita forzata all'interno con Break}
     TextAttr :=LastAttr; Gotoxy(1, WhereY);
     Display(LineView, True);    {che so' Furbo}
     Gotoxy(LastX, WhereY);
end;

{
 Decifra i parametri creando la lista delle selezioni;
 se incontra un "-?" chiama l'Help e si interrompe,
 se trova un parametro inisistente o errato chiama
 ErrParam e si interrompe.
 Restituisce il numero di selezioni (Max60) incontrate
 in NPar.
}
Procedure EsplicitaPar;
Const
     MaxDay:array[1..12] of Byte=(31,28,31,30,31,30,31,31,30,31,30,31);

Var
   Err         :Integer;
   PLen        :Byte;
   n           :Word;
   St          :String[80];
   St2, St3    :String[12];
   Date        :DateTime;
   AFileDetect :Boolean;
   DSel        :WildRec;

   function Small(Val1, Val2:Byte):Byte;
   begin
        if Val1=0 Then Small :=Val2;
        if Val2=0 Then Small :=Val1;
        if (Val1>0) and (Val1<=Val2) Then Small :=Val1;
        if (Val2>0) and (Val2<Val1) Then Small :=Val2;
   end;
   Function Eval(Sep1, Sep2:Char):Word;
   Var
      app :Word;

   begin
        St3 :=Copy(St2, 1, Small(Pos(Sep1,St2), Pos(Sep2,St2))-1);
        Val(St3, app, Err);
        Eval :=app;
        Delete(St2, Pos(St3, St2), Byte(St3[0])+1);
    end;

   {
    Calcolo giorno in pi— se anno bisestile
    (tiene conto dei fine Secolo).
   }
   Function Bises:Byte;
   begin
        Bises :=0;
        if (Date.Month=2) Then
        begin
             if (Date.Year>1582) Then
             begin
                if (Date.Year mod 100=0) Then  {fine Secolo}
                begin
                     if (Date.Year mod 400=0) Then Bises :=1;
                 end else if (Date.Year mod 4=0) Then Bises :=1;
              end else if (Date.Year mod 4=0) Then Bises :=1;
         end;
    end;

   procedure GetDateTime;
   begin
        St2 :=''; St3 :='';
        FillChar(Date, SizeOf(DateTime), 0);
        if Pos('\', St)=0 Then St2 :=Copy(St, 3, 255)
                          else St2 :=Copy(St, 3, Pos('\', St)-3);
        if St2<>'' Then
        begin
             St2 :=St2+'#';
             Date.Day :=Eval('-','/');
             if Err=0 Then
             begin
                  Date.Month :=Eval('-','/');
                  if (Err=0) Then
                  begin
                       if Not(Date.Month in[1..12]) Then Err :=$A2;

                       if Err=0 Then
                       begin
                            Date.Year :=Eval('#','#');
                            if (Err=0) and (Date.Year<100) Then
                             Inc(Date.Year, 1900);
                            if (Err<>0) or (St2<>'') Then Err :=$A3;
                            if (Err=0) and
                               (Date.Day>MaxDay[Date.Month]+Bises) Then
                                Err :=$A1;
                        end;
                   end else Err :=$A2;
              end else Err :=$A1;
         end else FillChar(Date, 6, $FF);
        if Err=0 Then
        begin
             if Pos('\', St)<>0 Then
             begin
                  St2 :=Copy(St, Pos('\', St)+1, 255);
                  if (St2='') and (Date.Year=$FFFF) Then Err :=$16;
                  if Err=0 Then
                  begin
                     St2 :=St2+'#';
                     Date.Hour :=Eval('.',':');
                     if (Err=0) and (Date.Hour>23) Then Err :=$A4;
                     if Err=0 Then
                     begin
                       Date.Min :=Eval('.',':');
                       if Date.Min>59 Then Err :=$A5;
                       if Err=0 Then
                       begin
                            Date.Sec :=Eval('#','#');
                            if (Err<>0) or
                               (Date.Sec>59) or (St2<>'') Then Err :=$A6;
                        end else Err :=$A5;
                      end else Err :=$A4;
                     if (Err=0) Then PackTime(Date, DSel.NewDate);
                   end;
              end else FillChar(Date.Hour, 6, $FF);
         end;
    end;

begin
    n :=1; nPar :=0; AFileDetect :=True;
    Repeat
          Err :=0;
          St :=ParamStr(n); PLen :=Byte(St[0]);
          if (St[1]='-') or (St[1]='/') Then    {Una Opzione}
          begin
               if AFileDetect and
                 (UpCase(St[2]) in['?','H','C','R','D',
                                   'F','N','A','T','S']) Then
               begin
                    FillChar(DSel, SizeOf(WildRec), 0);
                    AFileDetect :=False;
                end;
               With DSel Do
               Case UpCase(St[2]) of
               '?','H' :if PLen=2 Then Help(0) else Err :=$12;
               'C'     :if PLen=2 Then OpzDesc :=OpzDesc+opReqConf
                                  else Err :=$13;
               'R'     :if PLen=2 Then OpzDesc :=OpzDesc+opRecurse
                                  else Err :=$14;
               'D'     :if PLen=2 Then OpzDesc :=OpzDesc+opDelDir
                                  else Err :=$15;
               'F'     :begin
                             if PLen-2=1 Then Filler :=St[3]
                              else if PLen-2=0 Then Filler :='?'
                                               else Err :=$9E;
                             OpzDesc :=OpzDesc+opFisicDel;
                         end;
               'N'     :begin
                             if PLen-2=0 Then NewName :='#VDel3##.###'
                              else
                             begin
                                  St :=Copy(St, 3, Plen-2);
                                  if (St<>'') and (Byte(St[0])<13) and
                                   (Pos(':', St)=0) and ValidFileName(St)
                                   Then NewName :=St
                                   else Err :=$9F;
                              end;
                              OpzDesc :=OpzDesc+opNewName;
                         end;
               'A'     :begin
                             if PLen-2=0 Then NewAttr :=0
                              else
                             begin
                                  St :=Copy(St, 3, Plen-2);
                                  Val(St, NewAttr, Err);
                                  if Err<>0 Then Err :=$A0;
                              end;
                             OpzDesc :=OpzDesc+opNewAttr;
                         end;
               'T'     :if PLen-2=0 Then NewDate :=$210000 {1-1-1980,0:0.0}
                                    else GetDateTime;
               'S'     :begin
                             if PLen-2=0 Then NewSize :=1
                              else
                             begin
                                  St :=Copy(St, 3, Plen-2);
                                  Val(St, NewSize, Err);
                                  if Err<>0 Then Err :=$A7;
                              end;
                             OpzDesc :=OpzDesc+opNewSize;
                         end;
                else Err :=$01;
               end;
               if Err<>0 Then ErrParam(Err);
           end
          else      {Un File}
          begin
               Inc(nPar);
               AFileDetect :=True;
               AWild[nPar] :=DSel;
               AWild[nPar].Wild :=St;
           end;
          inc(n);
    Until (St='') or (n>ParamCount) or (nPar>MaxWild);
end;

(*
Procedure Integrity;
Const
     NoExe :array[0..1] of Char=('*','*');
Var
   f        :File;
   CheckSum :array[0..84] of Word;
   Chk, i, k:Word;
   Control  :LongInt;


begin
     Chk :=0;
     Assign(f, ParamStr(0));
     Reset(f, 1);
     GetFTime(f, Control);
     if Control=$1F8B9000 Then    {11-12-95 18:00.00}
     begin
          Control :=FileSize(f);
          if Control=21674 Then   {21504+170}
          begin
               if MemAvail>Control-170 Then
               begin
                    GetMem(Data, Control);
                    Seek(f, Control-170);
                    BlockRead(f, CheckSum, 170);
                    for i:=0 to 84 Do Inc(Chk, CheckSum[i]);
                    Chk :=0;
                    Seek(f, 0);
                    BlockRead(f, Data^, Control-170);
                    k :=0; Control :=0;
                    Repeat
                          for i :=0 to 255 Do
                           Inc(Chk, Byte(Data^[k*256+i]));
                          inc(k);
                    Until (k>84) or (Chk<>CheckSum[k-1]);
                    if Chk<>CheckSum[k-1] Then Control :=$FF;
                end;
               FreeMem(Data, Control);
           end else Control :=0;
      end else Control :=$FF;
    if Control<>0 Then
    begin
         Seek(f, 0); BlockWrite(f, NoExe, 2); Close(f);
         Writeln('DANGER : Programma non integro o infettato !!!', Stop($FF));
     end else Close(f);
end;
*)

begin
   (*  Integrity; *)
     TextAttr :=$07;
     Writeln;
     Write('********* ',Signature,' *********');
(*     Write('******************** ',DecryptNoBuy(EnNoBuy),' ********************');
*)
     Writeln;
     if ParamCount=0 then Help(0)
                     else EsplicitaPar;

     InitSysError; SysErrorFunc :=Io_Error;
     for CurDel:=1 to nPar Do
     begin
          FSplit(AWild[CurDel].Wild, Path, AName, AExt);
          if (Path='') Then Path :=CurrentDir(GetCurDrive);
          if Path[Byte(Path[0])]<>'\' Then Path :=Path+'\';
          if AName='' Then AName :='*';
          if AExt=''  Then AExt  :='.*';
          if ValidFileName(Path+AName+AExt) Then
          begin
               if Confirm(Path+AName+AExt) Then
               begin
                    mSiz :=65535;
                    if MaxAvail<65535 Then mSiz :=MaxAvail-10;
                    GetMem(Data, mSiz);
                    if Data<>Nil Then
                    begin
                         FillChar(Data^, mSiz, AWild[CurDel].Filler);
                         CancelDir(Path, AName+AExt);
                         FreeMem(Data, mSiz);
                     end
                    else Writeln('Error : Insufficient Memory', Stop(3));
                end;
           end
          else Writeln('Error : Ivalid File Name !!!');
      end;

     DoneSysError;
end.
