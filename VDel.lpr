program VDel;

{$MODE Delphi}

uses
  Forms, datetimectrls, Interfaces,
  VDel_Main in 'VDel_Main.pas' {VDelMain},
  MM_Form_CharsGrid,
  VDel_Confirm in 'VDel_Confirm.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TVDelMain, VDelMain);
  Application.CreateForm(TVDELConfirm, VDELConfirm);
  Application.Run;
end.
