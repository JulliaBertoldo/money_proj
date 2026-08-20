unit u99Permissions;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Actions, System.Messaging, System.Permissions,
  FMX.DialogService, FMX.MediaLibrary.Actions, FMX.Media, FMX.ActnList,
  {$IFDEF ANDROID}
  Androidapi.Helpers,
  Androidapi.JNI.JavaTypes,
  Androidapi.JNI.Os,
  {$ENDIF}
  System.TypInfo;

type
  TCallbackProc = procedure(Sender: TObject) of Object;

  T99Permissions = class
  private
    CurrentRequest : string;
    pCamera, pReadStorage, pWriteStorage : string;
    pFineLocation, pCoarseLocation : string;

    procedure PermissionRequestResult(Sender: TObject;
      const APermissions: TClassicStringDynArray;
      const AGrantResults: TClassicPermissionStatusDynArray);

    procedure DisplayRationale(Sender: TObject;
      const APermissions: TClassicStringDynArray;
      const APostRationaleProc: TProc);

  public
    MyCallBack, MyCallBackError : TCallbackProc;
    MyCameraAction : TTakePhotoFromCameraAction;
    MyLibraryAction : TTakePhotoFromLibraryAction;

    constructor Create;
    procedure Camera(ActionPhoto: TTakePhotoFromCameraAction;
      ACallBackError: TCallbackProc = nil);
    procedure PhotoLibrary(ActionLibrary: TTakePhotoFromLibraryAction;
      ACallBackError: TCallbackProc = nil);
    procedure Location(ACallBack: TCallbackProc = nil;
      ACallBackError: TCallbackProc = nil);
  end;

implementation

constructor T99Permissions.Create;
begin
  {$IFDEF ANDROID}
  pCamera := JStringToString(TJManifest_permission.JavaClass.CAMERA);
  pCoarseLocation := JStringToString(TJManifest_permission.JavaClass.ACCESS_COARSE_LOCATION);
  pFineLocation := JStringToString(TJManifest_permission.JavaClass.ACCESS_FINE_LOCATION);

  // Armazenamento antigo (Abaixo do Android 13)
  pWriteStorage := JStringToString(TJManifest_permission.JavaClass.WRITE_EXTERNAL_STORAGE);

  // AJUSTE SEGURO PARA ANDROID 13+ (API 33)
  if TOSVersion.Check(13) then
    pReadStorage := 'android.permission.READ_MEDIA_IMAGES'
  else
    pReadStorage := JStringToString(TJManifest_permission.JavaClass.READ_EXTERNAL_STORAGE);
  {$ENDIF}
end;

procedure T99Permissions.PermissionRequestResult(Sender: TObject;
  const APermissions: TClassicStringDynArray;
  const AGrantResults: TClassicPermissionStatusDynArray);
var
  LResult: Boolean;
  I: Integer;
begin
  LResult := False;

  if Length(AGrantResults) > 0 then
  begin
    // Varre todas as permissões para ter certeza que as cruciais foram aceitas
    LResult := True;
    for I := 0 to High(AGrantResults) do
    begin
      // No Android 13+, ignoramos se o WRITE_EXTERNAL_STORAGE der negado, pois ele não é mais usado
      if (APermissions[I] = 'android.permission.WRITE_EXTERNAL_STORAGE') and TOSVersion.Check(13) then
        Continue;

      // Se qualquer outra permissão obrigatória foi negada, invalida o acesso
      if AGrantResults[I] <> TPermissionStatus.Granted then
      begin
        LResult := False;
        Break;
      end;
    end;
  end;

  // Se passou na validação, executa a ação correspondente
  if LResult then
  begin
    if CurrentRequest = 'CAMERA' then
    begin
      if Assigned(MyCameraAction) then MyCameraAction.Execute;
    end
    else if CurrentRequest = 'LIBRARY' then
    begin
      if Assigned(MyLibraryAction) then MyLibraryAction.Execute;
    end
    else if CurrentRequest = 'LOCATION' then
    begin
      if Assigned(MyCallBack) then MyCallBack(Self);
    end;
  end
  else
  begin
    if Assigned(MyCallBackError) then
      MyCallBackError(Self);
  end;
end;

procedure T99Permissions.Camera(ActionPhoto: TTakePhotoFromCameraAction;
  ACallBackError: TCallbackProc = nil);
begin
  MyCameraAction := ActionPhoto;
  MyCallBackError := ACallBackError;
  CurrentRequest := 'CAMERA';

  {$IFDEF ANDROID}
  // No Android 13+, não enviamos o pWriteStorage para não travar o fluxo do app
  if TOSVersion.Check(13) then
    PermissionsService.RequestPermissions([pCamera, pReadStorage], PermissionRequestResult, DisplayRationale)
  else
    PermissionsService.RequestPermissions([pCamera, pReadStorage, pWriteStorage], PermissionRequestResult, DisplayRationale);
  {$ELSE}
  ActionPhoto.Execute;
  {$ENDIF}
end;

procedure T99Permissions.PhotoLibrary(ActionLibrary: TTakePhotoFromLibraryAction;
  ACallBackError: TCallbackProc = nil);
begin
  MyLibraryAction := ActionLibrary;
  MyCallBackError := ACallBackError;
  CurrentRequest := 'LIBRARY';

  {$IFDEF ANDROID}
  PermissionsService.RequestPermissions([pReadStorage], PermissionRequestResult, DisplayRationale);
  {$ELSE}
  ActionLibrary.Execute;
  {$ENDIF}
end;

procedure T99Permissions.Location(ACallBack: TCallbackProc = nil;
  ACallBackError: TCallbackProc = nil);
begin
  MyCallBack := ACallBack;
  MyCallBackError := ACallBackError;
  CurrentRequest := 'LOCATION';

  {$IFDEF ANDROID}
  PermissionsService.RequestPermissions([pFineLocation, pCoarseLocation], PermissionRequestResult, DisplayRationale);
  {$ELSE}
  if Assigned(MyCallBack) then MyCallBack(Self);
  {$ENDIF}
end;

procedure T99Permissions.DisplayRationale(Sender: TObject;
  const APermissions: TClassicStringDynArray; const APostRationaleProc: TProc);
begin
  APostRationaleProc;
end;

end.

