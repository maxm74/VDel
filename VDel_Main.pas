unit VDel_Main;

{$MODE Delphi}

interface

//{$DEFINE TEST}
//{$DEFINE RTDEBUG}

uses
  Windows, LCLIntf, LCLType, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, Spin, ExtCtrls, Buttons, CheckLst, DateTimePicker;

type

  { TVDelMain }

  TVDelMain = class(TForm)
    btCancel: TButton;
    Button1: TButton;
    Button2: TButton;
    GO: TButton;
    clistFiles: TCheckListBox;
    gbOptions: TGroupBox;
    cbConfirm: TCheckBox;
    cbRecursive: TCheckBox;
    cbRemoveDir: TCheckBox;
    cbFill: TCheckBox;
    cbRename: TCheckBox;
    cbAttr: TCheckBox;
    cbDate: TCheckBox;
    cbTime: TCheckBox;
    cbResize: TCheckBox;
    edFill: TEdit;
    edRename: TEdit;
    edAttr: TSpinEdit;
    edDate: TDateTimePicker;
    edTime: TDateTimePicker;
    edResize: TSpinEdit;
    Label2: TLabel;
    Label1: TLabel;
    OpenDialog: TOpenDialog;
    pnMain: TPanel;
    lbMessage: TLabel;
    btFillChar: TSpeedButton;
    btRenameChar: TSpeedButton;
    lbFill: TLabel;
    lbRename: TLabel;
    btPredefOpt: TButton;
    btWriteOpt: TButton;
    SelectDirectoryDialog: TSelectDirectoryDialog;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btCancelClick(Sender: TObject);
    procedure btGoClick(Sender: TObject);
    procedure WriteOptionsClick(Sender: TObject);
    procedure btFillCharClick(Sender: TObject);
    procedure btRenameCharClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
    Error     :Integer;
    AllOk,
    IsDir,
    firstShow :Boolean;
    Buffer    :Pointer;

    procedure LoadOptions;

    procedure CancelDir(BaseDir:String; SelName :String; Recursive, RemoveDirs :Boolean);
    procedure RemoveDirct(AParentDir, ADir :String);
    procedure DelFile(ADir, FilName:String);
    procedure Display(St :String);
    function GetNewName(AParentDir, OldName :String; IsDir :Boolean):String;

  public
    { Public declarations }
  end;

var
  VDelMain: TVDelMain;

implementation

{$R *.lfm}

uses
{$IFDEF RTDEBUG}
    RTDebug,
{$endif}
    VDel_Const, IniFiles, MM_Form_CharsGrid, VDel_Confirm;


procedure TVDelMain.FormCreate(Sender: TObject);
var
   cI,
   i: Integer;


begin
     firstShow :=True;
     AllOk :=False;

     LoadOptions;

     (*
     if not(AllOk)
     then lbMessage.Caption :='Devi impostare le opzioni...';

     gbOptions.Visible := (ParamCount=0) or not(AllOk);
     *)
     for i:=1 to ParamCount do
     begin
       cI :=clistFiles.Items.Add(Paramstr(i));    //xParam :=Paramstr(i);
       clistFiles.Checked[cI] :=True;
     end;

     Position :=poScreenCenter;
end;

procedure TVDelMain.Button1Click(Sender: TObject);
var
   cI,
   i: Integer;

begin
  if OpenDialog.Execute then
  begin
    for i:=1 to OpenDialog.Files.Count do
    begin
         cI :=clistFiles.Items.Add(OpenDialog.Files[i-1]);
         clistFiles.Checked[cI] :=True;
    end;
  end;
end;

procedure TVDelMain.Button2Click(Sender: TObject);
var
   cI,
   i: Integer;

begin
  if SelectDirectoryDialog.Execute then
  begin
    for i:=1 to SelectDirectoryDialog.Files.Count do
    begin
         cI :=clistFiles.Items.Add(SelectDirectoryDialog.Files[i-1]);
         clistFiles.Checked[cI] :=True;
    end;
  end;
end;

procedure TVDelMain.btCancelClick(Sender: TObject);
begin
     Close;
end;


procedure TVDelMain.Display(St :String);
begin
     Self.lbMessage.Caption :=St;
     Application.ProcessMessages;
end;

function TVDelMain.GetNewName(AParentDir, OldName :String; IsDir :Boolean):String;
Var
   AlreadyExist :Boolean;
   i            :Integer;
   sostChar     :Char;
   tentativi    :Integer;

begin
     sostChar :=edRename.Text[1];
     tentativi :=0;
     repeat
           inc(tentativi);
           Result :='';
           if (tentativi>16)
           then Exit;

           for i:=1 to Length(OldName) do
           begin
                if OldName[i]='.'
                then Result :=Result + '.'
                else Result :=Result + sostChar;
            end;

           if IsDir
           then AlreadyExist :=DirectoryExists(AParentDir+'\'+Result)
           else AlreadyExist :=FileExists(AParentDir+'\'+Result);

           if AlreadyExist
           then sostChar :=Char($61 + Random(128));
     Until Not(AlreadyExist);
end;

{
 Se è settata l'opzione "-d" e la Directory ADir è Vuota viene rimossa.
}
Procedure TVDelMain.RemoveDirct(AParentDir, ADir :String);
Var
   Test    :TSearchRec;
   newName :String;

begin
     if DirectoryExists(AParentDir+'\'+ADir) then
     begin
          Error :=FindFirst(AParentDir+'\'+ADir+'\*.*', faAnyFile, Test);
          while (Error=0) and (Test.Name[1]='.') do Error :=FindNext(Test);
          FindClose(Test);
          if (Error<>0) Then
          begin
               Display('RemoveDirectory...');

               if cbRename.Checked
               then begin
                         newName :=GetNewName(AParentDir, ADir, True);
                         if (newName<>'')
                         then MoveFile(PChar(AParentDir+'\'+ADir), PChar(AParentDir+'\'+newName));
                         RemoveDirectory(PChar(AParentDir+'\'+newName));
                    end
               else RemoveDirectory(PChar(AParentDir+'\'+ADir));
           end;
      end;
end;

{
 Cancellazione del File e cambio dei propri parametri
 (Size, Attr, Name, etc..) in base alle opzioni della
 selezione corrente.
}
Procedure TVDelMain.DelFile(ADir, FilName:String);
Var
   fHandle      :Integer;
   nWr          :Integer;
   nRemain      :Int64;
   OldAttr      :Cardinal;
   Date1        :TDateTime;
   fullFileName,
   newName      :String;

begin
     fullFileName :=ADir+'\'+FilName;

        if cbAttr.Checked
        then if (FileSetAttr(fullFilename, edAttr.Value)<>0)
             then Exit;

        OldAttr :=FileGetAttr(fullFilename);
        if (FileSetAttr(fullFilename, faArchive)<>0)
        then Exit;

        if cbDate.Checked or cbTime.Checked
        then begin
                  Date1 :=FileDateToDateTime(FileAge(fullFilename));
                  if cbDate.Checked
                  then ReplaceDate(Date1, edDate.DateTime);
                  if cbTime.Checked
                  then ReplaceTime(date1, edTime.DateTime);
                  if (FileSetDate(fullFilename, DateTimeToFiledate(Date1))<>0)
                  then Exit;
           end;

        fHandle :=FileOpen(fullFileName, fmOpenReadWrite or fmShareExclusive);
        if (fHandle=-1)
        then Exit;

        FileSeek(fHandle, 0, 0);

        if Self.cbResize.Checked
        then begin
                  SetEndOfFile(fHandle);
                  nRemain :=edResize.Value;
             end
        else begin
                  nRemain := Int64(FileSeek(fHandle, Int64(0), 2));
                  FileSeek(fHandle, 0, 0);
             end;

        if Self.cbFill.Checked
        then begin
                  Display('Unrec-Del '+FilName+' ');

                  repeat
                        if nRemain>=bufSize
                        then nWr :=FileWrite(fHandle, Buffer^, bufSize)
                        else nWr :=FileWrite(fHandle, Buffer^, nRemain);

                        Dec(nRemain, nWr);
                  Until (nRemain<=0);
            end;

        FileClose(fHandle);

        FileSetAttr(fullfilename, OldAttr);

        if Self.cbRename.Checked
        then begin
                  newName :=GetNewName(ADir, filName, False);
                  if (newname<>'')
                  then MoveFile(PChar(fullfilename), PChar(ADir+'\'+newName));
                  DeleteFile(ADir+'\'+newName);
             end
        else DeleteFile(fullfilename);
end;

{
 Cancellazione dei file selezionati nella directory BaseDir.
 Se è settata l'opzione "-r" la procedura ricerca le eventuali
 Sub-Dir di BaseDir e richiama se stessa in modo ricorsivo
 finchè non si ritorna alla BaseDir e non ci sono più file che
 corrispondono alla selezione nè altre Sub-Dir.
}
procedure TVDelMain.CancelDir(BaseDir:String; SelName :String; Recursive, RemoveDirs :Boolean);
Var
   SFile,
   SDir  :TSearchRec;

begin
     Display('Deleting Dir '+BaseDir+'\'+SelName);

     Error :=FindFirst(BaseDir+'\'+Selname, faOnlyFile, Sfile);
     While (Error=0) Do
     begin
          if (SFile.Name[1]<>'.') and
             not(Sfile.Attr in[faDirectory..faAnyDir])
          then DelFile(BaseDir, SFile.Name);

          Error :=FindNext(SFile);
     end;
     FindClose(SFile);
     if Recursive then
     begin
          Error :=FindFirst(BaseDir+'\*.*', faAnyDir, SDir);
          While (Error=0) Do
          begin
               if (SDir.Name[1]<>'.') and
                  (SDir.Attr in[faDirectory..faAnyDir])
               then begin
                         CancelDir(BaseDir+'\'+Sdir.Name, SelName, Recursive, RemoveDirs);
                         if RemoveDirs
                         then RemoveDirct(BaseDir, Sdir.Name);
                    end;

               Error :=FindNext(SDir);
           end;
          FindClose(SDir);
      end;
end;



procedure TVDelMain.btGoClick(Sender: TObject);
Var
   i :Integer;
   xDir,
   xFile,
   xParam  :String;
   Recursive,
   RemoveDirs :Boolean;

begin
{$IFDEF RTDEBUG}
     for i:=1 to ParamCount do
     begin
          xParam :=xParam+' '+ParamStr(i);
     end;
     RTAssert(0, true, 'Param='+xParam, '', 0);
{$endif}

     if (clistFiles.Count=0)
     then exit;

     if Self.cbFill.Checked
     then begin
               GetMem(Buffer, bufSize);
               FillChar(Buffer^, bufSize, Char(edFill.Text[1]));
          end;

     RemoveDirs :=Self.cbRemoveDir.Checked;

     for i:=0 to clistFiles.Count-1 do
     if clistFiles.Checked[i] then
     begin
          xParam :=clistFiles.Items[i];

        (*  SE è un file   singolo esistente allora recursive =false
             è un folder singolo esistente recursive =true
             è un wild recursive =true
          IN OGNI CASO FAR DARE CONFERMA ALL' UTENTE
        *)
          if DirectoryExists(xParam)
          then begin
                    xDir :=xParam;
                    xFile :='*.*';
                    IsDir := (Length(xDir)>3);
                    Recursive :=True;
               end
          else begin
                    xDir :=ExtractFilePath(xParam);
                    xFile :=ExtractFileName(xParam);
                    IsDir :=False;
                    Recursive := (Pos('*', xFile)>0) or (Pos('?', xFile)>0);
               end;

          if (xDir<>'') then
          begin
               if (xDir[Length(xDir)]='\')
               then SetLength(xDir, Length(xDir)-1);

(*
{$IFDEF RTDEBUG}
    RTAssert(0, IsDir, 'IsDir, xDir='+xDir+' | xFile='+xFile,
                       'NoDir, xDir='+xDir+' | xFile='+xFile, 0);
{$endif}
*)

{$IFNDEF TEST}
              if (not(Self.cbConfirm.Checked)) or
                 (VDELConfirm.Execute('Confirm Delete : '+#13#10+
                                      xDir+' -> '+xFile, Recursive, RemoveDirs)=mrOk)
              then begin
                        CancelDir(xDir, xFile, Recursive, RemoveDirs);
                        if IsDir
                        then RemoveDirct(ExtractFilePath(xParam), ExtractFileName(xParam));
{$ENDIF}           end;
          end;
     end;
     
     if Self.cbFill.Checked
     then FreeMem(Buffer);

     Close;
end;

procedure TVDelMain.WriteOptionsClick(Sender: TObject);
Var
   xReg :TIniFile;

begin
     xReg :=TIniFile.Create(ConfigDir+Config_Options);
     try
        AllOk :=False;

        xReg.WriteBool(REG_Key, REG_cbConfirm, cbConfirm.Checked);
        xReg.WriteBool(REG_Key, REG_cbRecursive, cbRecursive.Checked);
        xReg.WriteBool(REG_Key, REG_cbRemoveDir, cbRemoveDir.Checked);
        xReg.WriteBool(REG_Key, REG_cbFill, cbFill.Checked);
        xReg.WriteBool(REG_Key, REG_cbRename, cbRename.Checked);
        xReg.WriteBool(REG_Key, REG_cbAttr, cbAttr.Checked);
        xReg.WriteBool(REG_Key, REG_cbDate, cbDate.Checked);
        xReg.WriteBool(REG_Key, REG_cbTime, cbTime.Checked);
        xReg.WriteBool(REG_Key, REG_cbResize, cbResize.Checked);
        xReg.WriteInteger(REG_Key, REG_edFill, Byte(edFill.Text[1]));
        xReg.WriteInteger(REG_Key, REG_edRename, Byte(edRename.Text[1]));
        xReg.WriteInteger(REG_Key, REG_edAttr, edAttr.Value);
        xReg.WriteDate(REG_Key, REG_edDate, edDate.Date);
        xReg.WriteTime(REG_Key, REG_edTime, edTime.Time);
        xReg.WriteInteger(REG_Key, REG_edResize, edResize.Value);

        AllOk :=True;
     finally
        xReg.Free;
     end;
end;

procedure TVDelMain.LoadOptions;
Var
   xReg :TIniFile;

begin
     xReg :=TIniFile.Create(ConfigDir+Config_Options);
     try
        AllOk :=False;

        cbConfirm.Checked := xReg.ReadBool(REG_Key, REG_cbConfirm, True);
        cbRecursive.Checked := xReg.ReadBool(REG_Key, REG_cbRecursive, True);
        cbRemoveDir.Checked := xReg.ReadBool(REG_Key, REG_cbRemoveDir, True);
        cbFill.Checked := xReg.ReadBool(REG_Key, REG_cbFill, True);
        cbRename.Checked := xReg.ReadBool(REG_Key, REG_cbRename, True);
        cbAttr.Checked := xReg.ReadBool(REG_Key, REG_cbAttr, False);
        cbDate.Checked := xReg.ReadBool(REG_Key, REG_cbDate, False);
        cbTime.Checked := xReg.ReadBool(REG_Key, REG_cbTime, False);
        cbResize.Checked := xReg.ReadBool(REG_Key, REG_cbResize, False);
        edFill.Text :=  Char(xReg.ReadInteger(REG_Key, REG_edFill, $56));
        edRename.Text := Char(xReg.ReadInteger(REG_Key, REG_edRename, $56));
        edAttr.Value := xReg.ReadInteger(REG_Key, REG_edAttr, 0);
        edDate.Date := xReg.ReadDate(REG_Key, REG_edDate, 0);
        edTime.Time := xReg.ReadTime(REG_Key, REG_edTime, 0);
        edResize.Value := xReg.ReadInteger(REG_Key, REG_edResize, 0);

        lbFill.Caption :=':  '+IntToHex(Byte(edFill.Text[1]), 2);
        lbRename.Caption :=':  '+IntToHex(Byte(edRename.Text[1]), 2);

        AllOk :=True;
     finally
        xReg.Free;
     end;
end;


procedure TVDelMain.btFillCharClick(Sender: TObject);
var
   selChar: Char;

begin
     selChar :=edFill.Text[1];

     if FormCharsGridShow(selChar)
     then edFill.Text :=selChar;

     lbFill.Caption :=':  '+IntToHex(Byte(edFill.Text[1]), 2);
end;

procedure TVDelMain.btRenameCharClick(Sender: TObject);
var
   selChar: Char;

begin
     selChar :=edRename.Text[1];

     if FormCharsGridShow(selChar)
     then edRename.Text :=selChar;

     lbRename.Caption :=':  '+IntToHex(Byte(edRename.Text[1]), 2);
end;

procedure TVDelMain.FormShow(Sender: TObject);
begin
(*     if firstShow and not(Self.gbOptions.Visible) then
     begin
          firstShow :=False;
          btGoClick(Nil);
     end;
*)
end;

end.
