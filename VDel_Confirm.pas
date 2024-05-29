unit VDel_Confirm;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls;

type
  TVDELConfirm = class(TForm)
    cbUserSubDir: TCheckBox;
    btGo: TButton;
    btCancel2: TButton;
    mMessage: TMemo;
    cbUserRemoveDir: TCheckBox;
  private
    { Private declarations }
  public
      function Execute(Msg: String; var UserSubDir, UserRemoveDir :Boolean): TModalResult;
    { Public declarations }
  end;

var
  VDELConfirm: TVDELConfirm;

implementation

{$R *.lfm}

function TVDELConfirm.Execute(Msg: String; var UserSubDir, UserRemoveDir :Boolean): TModalResult;
begin
     cbUserSubDir.Checked :=UserSubDir;
     mMessage.Lines.Text :=Msg;
     Result :=ShowModal;
     UserSubDir :=cbUserSubDir.Checked;
     UserRemoveDir :=cbUserRemoveDir.Checked;
end;

end.
