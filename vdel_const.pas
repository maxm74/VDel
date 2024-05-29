unit VDel_Const;

{$mode delphi}

interface

uses
  Classes, SysUtils;

const
//    REG_Key ='Software\MaxM_BeppeG\VDel3\';
    REG_Key ='VDel';
    REG_cbConfirm ='Confirm';
    REG_cbRecursive ='Recursive';
    REG_cbRemoveDir ='RemoveDir';
    REG_cbFill ='Fill';
    REG_cbRename ='Rename';
    REG_cbAttr ='Attr';
    REG_cbDate ='Date';
    REG_cbTime ='Time';
    REG_cbResize ='Resize';
    REG_edFill ='Fill Char';
    REG_edRename ='Rename Char';
    REG_edAttr ='Attr Val';
    REG_edDate ='Date Val';
    REG_edTime ='Time Val';
    REG_edResize ='Resize Val';

    faOnlyFile  =$27;
    faAnyDir    =$1F;
    bufSize     =1024*1024;

    Config_Options='vdel.ini';

var
   ApplicationDir,
   ConfigDir,
   TempDir:String;

implementation

initialization
   ApplicationDir :=ExtractFilePath(ParamStr(0));
   ConfigDir :=GetAppConfigDir(False);
   TempDir :=GetTempDir(False)+'VDel'+DirectorySeparator;
   ForceDirectories(ConfigDir);
   ForceDirectories(TempDir);


end.

