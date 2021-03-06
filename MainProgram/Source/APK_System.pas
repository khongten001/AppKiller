{-------------------------------------------------------------------------------

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.

-------------------------------------------------------------------------------}
unit APK_System;

{$INCLUDE APK_Defs.inc}

interface

uses
  Windows, ShellAPI,
  AuxTypes;

Function SetPrivilege(const PrivilegeName: String; Enable: Boolean): Boolean;

Function GetAccountName: WideString;

//------------------------------------------------------------------------------

const
{$IF not Declared(PROCESS_QUERY_LIMITED_INFORMATION)}
  PROCESS_QUERY_LIMITED_INFORMATION = $00001000;
{$IFEND}
  RPC_C_AUTHN_LEVEL_PKT_PRIVACY = 6;
  RPC_C_IMP_LEVEL_IMPERSONATE   = 3;

{$IF not Declared(PHICON)}
type
  PHICON = ^HICON;
{$IFEND}

{$MINENUMSIZE 4}
type
  EXTENDED_NAME_FORMAT = (
    NameUnknown          = 0,
    NameFullyQualifiedDN = 1,
    NameSamCompatible    = 2,
    NameDisplay          = 3,
    NameUniqueId         = 6,
    NameCanonical        = 7,
    NameUserPrincipal    = 8,
    NameCanonicalEx      = 9,
    NameServicePrincipal = 10,
    NameDnsDomain        = 12);

{$IF not Declared(GetProcessImageFileName)}
Function GetProcessImageFileNameA(hProcess: THandle; lpImageFileName: LPSTR; nSize: DWORD): DWORD; stdcall; external 'psapi.dll';
Function GetProcessImageFileNameW(hProcess: THandle; lpImageFileName: LPWSTR; nSize: DWORD): DWORD; stdcall; external 'psapi.dll';
Function GetProcessImageFileName(hProcess: THandle; lpImageFileName: LPTSTR; nSize: DWORD): DWORD; stdcall; external 'psapi.dll'
  name {$IFDEF Unicode}'GetProcessImageFileNameW'{$ELSE}'GetProcessImageFileNameA'{$ENDIF};
{$IFEND}

Function ExtractIconExA(lpszFile: LPCSTR; nIconIndex: Integer; phiconLarge: PHICON; phiconSmall: PHICON; nIcons: UINT): UINT; stdcall; external shell32;
Function ExtractIconExW(lpszFile: LPCWSTR; nIconIndex: Integer; phiconLarge: PHICON; phiconSmall: PHICON; nIcons: UINT): UINT; stdcall; external shell32;
Function ExtractIconEx(lpszFile: LPCTSTR; nIconIndex: Integer; phiconLarge: PHICON; phiconSmall: PHICON; nIcons: UINT): UINT; stdcall; external shell32
  name {$IFDEF Unicode}'ExtractIconExW'{$ELSE}'ExtractIconExA'{$ENDIF};

{$IF not Declared(GetUserNameEx)}
Function GetUserNameExW(NameFormat: EXTENDED_NAME_FORMAT; lpNameBuffer: PWideChar; lpnSize: PULONG): ByteBool; stdcall; external 'secur32.dll';
Function GetUserNameExA(NameFormat: EXTENDED_NAME_FORMAT; lpNameBuffer: PAnsiChar; lpnSize: PULONG): ByteBool; stdcall; external 'secur32.dll';
Function GetUserNameEx(NameFormat: EXTENDED_NAME_FORMAT; lpNameBuffer: PChar; lpnSize: PULONG): ByteBool; stdcall; external 'secur32.dll'
  name {$IFDEF Unicode} 'GetUserNameExW'{$ELSE} 'GetUserNameExA'{$ENDIF};
{$IFEND}

{$IFDEF 64bit}
Function GetWindowLongPtr(hWnd: HWND; nIndex: Integer): Pointer; stdcall; external user32;
Function SetWindowLongPtr(hWnd: HWND; nIndex: Integer; dwNewLong: Pointer): Pointer; stdcall; external user32;
{$ELSE}
Function GetWindowLongPtr(hWnd: HWND; nIndex: Integer): Pointer;
Function SetWindowLongPtr(hWnd: HWND; nIndex: Integer; dwNewLong: Pointer): Pointer;
{$ENDIF}

Function SendMessageTimeoutA(hWnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM; fuFlags: UINT; uTimeout: UINT; lpdwResult: PPtrUInt): LRESULT; stdcall; external user32;
Function SendMessageTimeoutW(hWnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM; fuFlags: UINT; uTimeout: UINT; lpdwResult: PPtrUInt): LRESULT; stdcall; external user32;
Function SendMessageTimeout(hWnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM; fuFlags: UINT; uTimeout: UINT; lpdwResult: PPtrUInt): LRESULT; stdcall; external user32
  name {$IFDEF Unicode} 'SendMessageTimeoutW'{$ELSE} 'SendMessageTimeoutA'{$ENDIF};


implementation

uses
  SysUtils;

{$IFDEF FPC_DisableWarns}
  {$DEFINE FPCDWM}
  {$DEFINE W4055:={$WARN 4055 OFF}} // Conversion between ordinals and pointers is not portable
  {$DEFINE W5057:={$WARN 5057 OFF}} // Local variable "$1" does not seem to be initialized
{$ENDIF}

type
  HANDLE = THandle;
  PTOKEN_PRIVILEGES = ^TOKEN_PRIVILEGES;

Function AdjustTokenPrivileges(
  TokenHandle:          HANDLE;
  DisableAllPrivileges: BOOL;
  NewState:             PTOKEN_PRIVILEGES;
  BufferLength:         DWORD;
  PreviousState:        PTOKEN_PRIVILEGES;
  ReturnLength:         PDWORD): BOOL; stdcall; external advapi32;

//==============================================================================

{$IFDEF FPCDWM}{$PUSH}W5057{$ENDIF}
Function SetPrivilege(const PrivilegeName: String; Enable: Boolean): Boolean;
var
  Token:            THandle;
  TokenPrivileges:  TTokenPrivileges;
begin
Result := False;
If OpenProcessToken(GetCurrentProcess,TOKEN_QUERY or TOKEN_ADJUST_PRIVILEGES,Token) then
try
  If LookupPrivilegeValue(nil,PChar(PrivilegeName),TokenPrivileges.Privileges[0].Luid) then
    begin
      TokenPrivileges.PrivilegeCount := 1;
      TokenPrivileges.Privileges[0].Attributes := Ord(Enable) * SE_PRIVILEGE_ENABLED;
      If AdjustTokenPrivileges(Token,False,@TokenPrivileges,0,nil,nil) then
        Result := GetLastError = ERROR_SUCCESS;
    end;
finally
  CloseHandle(Token);
end;
end;
{$IFDEF FPCDWM}{$POP}{$ENDIF}

//==============================================================================

Function GetAccountName: WideString;
var
  AccountNameLen: ULONG;
begin
AccountNameLen := 0;
GetUserNameExW(NameSamCompatible,nil,@AccountNameLen);
SetLength(Result,AccountNameLen);
If not GetUserNameExW(NameSamCompatible,PWideChar(Result),@AccountNameLen) then
  raise Exception.CreateFmt('Cannot obtain account name (0x%.8x).',[GetLastError]);
end;

//==============================================================================

{$IFNDEF 64bit}
Function GetWindowLongPtr(hWnd: HWND; nIndex: Integer): Pointer;
begin
{$IFDEF FPCDWM}{$PUSH}W4055{$ENDIF}
Result := Pointer(GetWindowLong(hWnd,nIndex));
{$IFDEF FPCDWM}{$POP}{$ENDIF}
end;

//------------------------------------------------------------------------------

Function SetWindowLongPtr(hWnd: HWND; nIndex: Integer; dwNewLong: Pointer): Pointer;
begin
{$IFDEF FPCDWM}{$PUSH}W4055{$ENDIF}
Result := Pointer(SetWindowLong(hWnd,nIndex,Integer(dwNewLong)));
{$IFDEF FPCDWM}{$POP}{$ENDIF}
end;
{$ENDIF}

end.
