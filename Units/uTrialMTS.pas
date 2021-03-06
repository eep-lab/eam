﻿{
  EAM - Stimulus Control Application
  Copyright (C) 2007-2015 The EAM authors team.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
}
unit uTrialMTS;

interface

uses Windows, IdGlobalProtocols, Dialogs,//adicionadas
     Classes, Types, SysUtils, Controls, Graphics, ExtCtrls, StrUtils, IdGlobal, Forms,
     uKey, uTrial, uCounterManager, uCounter, uConstants,
     uLibrary;                   //adicionadas

type
  TSupportKey = Record
    Key    : TKey;
    Csq    : Byte;
    Usb    : ShortInt;
    Msg    : String;
    Nxt    : String;
    Res    : String;
    IET    : String;
    TO_    : Integer;
  end;

  TMTS = Class(TTrial)
  protected
    FTrialInterval: Integer;
    //FComparisonFocus : integer;
    FDataBkGndI: TCounter;
    FDataBkGndS: String;
    FFlagModCmps: Boolean;
    FFlagCsq2Fired: Boolean;
    //FClockSwitchON : Boolean;
    FDelayed: Boolean;
    FCanPassTrial: Boolean;
    FHeader1: String;
    FHeader2: String;
    FDataSMsg: String;
    FDataCMsg: String;
    FLatMod: Cardinal;
    FDurMod: Cardinal;
    FLatCmp: Cardinal;
    FDurCmp: Cardinal;
    Ft: Cardinal;
    Ft2: Cardinal;
    FDataCsq: Byte;
    FDataUsb: ShortInt;
    FTimerDelay: TTimer;
    //FTimerClock: TTimer;
    FClockThread: TClockThread;
    FTimerCsq: TTimer;
    FFirstResp : Boolean;
    FFlagResp: Boolean;
    FKPlus: TSupportKey;
    FKMinus: TSupportKey;
    FSupportS: TSupportKey;
    FNumKeyC: Integer;
    FVetSupportC: Array of TSupportKey;
    procedure BeginCorrection (Sender : TObject);
    procedure EndCorrection (Sender : TObject);
    procedure SConsequence(Sender: TObject);     //consequência do modelo
    procedure Consequence(Sender: TObject);      //para a passagem de tentativa e ativação de interfaces
    procedure Consequence2(Sender: TObject);     //para a ativação de interfaces e interrupção de clocks
    procedure Response(Sender: TObject);
    procedure Hit(Sender: TObject);
    procedure Miss(Sender: TObject);
    procedure None(Sender: TObject);
    procedure TimerDelayTimer(Sender: TObject);
    procedure TimerCsqTimer(Sender: TObject);
    procedure TimerClockTimer(Sender: TObject);
    procedure Dispenser(Csq: Byte; Usb: ShortInt);
    procedure StartTrial(Sender: TObject);
    procedure EndTrial(Sender: TObject);
    procedure ShowKeyC;
    procedure SetTimerCsq;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyUp(var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(var Key: Char); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure WriteData(Sender: TObject); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Play(Manager : TCounterManager; TestMode: Boolean; Correction : Boolean); override;
    procedure DispenserPlusCall; override;
  end;

implementation

uses uCfgSes;

constructor TMTS.Create(AOwner: TComponent);
begin
  Inherited Create(AOwner);

  FHeader1:= #9 + 'Pos.Mod.' + #9 +
             'Res.Mod.' + #9 +
             'Lat.Mod.' + #9 + #9 +
             'Dur.Mod.' + #9 + #9 +
             'Tmp.Mod.' + #9 + #9 +
             'Atraso  ' + #9 + #9;

  FHeader2:= 'Pos.Cmp.' + #9 +
             'Res.Cmp.' + #9 +
             'Lat.Cmp.' + #9 + #9 +
             'Dur.Cmp.' + #9 + #9 +
             'Tmp.Cmp.' + #9 + #9 +
             'Disp.   ' + #9 +
             'UDsp.   ' + #9 +
             'Res.Frq.';

  FHeader:= FHeader1 + #9 + FHeader2;

  FHeaderTicks:= 'Tempo_ms' + #9 +
                 'Stm.Tipo' + #9 +
                 'FileName' + #9 +
                 'Left....' + #9 +
                 'Top.....';

  FDataBkGndI := TCounter.Create;

  FTimerDelay:= TTimer.Create(Self);
  With FTimerDelay do begin
    Enabled:= False;
    Interval:= 1000;
    OnTimer:= TimerDelayTimer;
  end;

  {FTimerClock:= TTimer.Create(Self);
  With FTimerClock do begin
    Enabled:= False;
    Interval:= 100;
    OnTimer:= TimerClockTimer;
  end;}

  FTimerCsq:= TTimer.Create(Self);
  With FTimerCsq do begin
    Enabled:= False;
    Interval:= 1;
    OnTimer:= TimerCsqTimer;
  end;
  FFlagCsq2Fired := False;
 // FComparisonFocus := -1;
  //FClockSwitchON := True;
end;

destructor TMTS.Destroy;
begin
  FDataBkGndI.Free;
  inherited Destroy;
end;

procedure TMTS.Dispenser(Csq: Byte; Usb: ShortInt);
begin
  FRS232.Dispenser(Usb);
  FPLP.OutPortOn (Csq);
end;

procedure TMTS.DispenserPlusCall;
begin
  Dispenser(FKPlus.Csq, FKPlus.Usb);
end;

procedure TMTS.Play(Manager : TCounterManager; TestMode: Boolean; Correction : Boolean);
var s1, sName, sLoop, sColor: String; R: TRect; a1: Integer;
begin
  FHootMedia:= FCfgTrial.SList.Values[_HootMedia];
  FManager := Manager;
  Randomize;
  FNextTrial:= '-1';
  FFlagResp:= False;
  FFlagModCmps:= True;
  if Correction then FIsCorrection := True
  else FIsCorrection := False;

  Color:= StrToIntDef(FCfgTrial.SList.Values[_BkGnd], 0);
  FCanPassTrial := StrToBoolDef(FCfgTrial.SList.Values[_AutoNxt], True);
  if FCanPassTrial = False then
    begin
      FTrialInterval := StrToIntDef(FCfgTrial.SList.Values[_CustomNxtValue], 10000);
      SetTimerCsq;
    end;

  FDelayed:= StrToBoolDef(FCfgTrial.SList.Values[_Delayed], False);
  FTimerDelay.Interval:= StrToIntDef(FCfgTrial.SList.Values[_Delay], 0);

  If TestMode then Cursor:= 0
  else Cursor:= StrToIntDef(FCfgTrial.SList.Values[_Cursor], 0);

  With FSupportS do begin
    Key:= TKey.Create(Self);
    Key.Cursor:= Self.Cursor;
    Key.Parent:= Self;
    Key.OnConsequence:= SConsequence;
    Key.OnResponse:= Response;

    s1:= FCfgTrial.SList.Values[_Samp + _cBnd];
    R.Top:= StrToIntDef(Copy(s1, 0, pos(#32, s1)-1), 0);
    Delete(s1, 1, pos(#32, s1)); If Length(s1)>0 then While s1[1]=#32 do Delete(s1, 1, 1);
    R.Left:= StrToIntDef(Copy(s1, 0, pos(#32, s1)-1), 0);
    Delete(s1, 1, pos(#32, s1)); If Length(s1)>0 then While s1[1]=#32 do Delete(s1, 1, 1);
    R.Right:= StrToIntDef(Copy(s1, 0, pos(#32, s1)-1), 0);
    Delete(s1, 1, pos(#32, s1)); If Length(s1)>0 then While s1[1]=#32 do Delete(s1, 1, 1);
    R.Bottom:= StrToIntDef(s1, 0);
    Key.SetBounds(R.Left, R.Top, R.Right, R.Bottom);

    s1:= FCfgTrial.SList.Values[_Samp + _cStm] + #32;
    //showmessage(FCfgTrial.SList.Values[_HootMedia] + Copy(s1, 0, pos(#32, s1)-1));
    sName := HootMedia + Copy(s1, 0, pos(#32, s1)-1);
    Delete(s1, 1, pos(#32, s1)); If Length(s1)>0 then While s1[1]=#32 do Delete(s1, 1, 1);
    sLoop := Copy(s1, 0, pos(#32, s1)-1);
    Delete(s1, 1, pos(#32, s1)); If Length(s1)>0 then While s1[1]=#32 do Delete(s1, 1, 1);
    sColor := Copy(s1, 0, pos(#32, s1)-1);
    Key.Color := StrToIntDef(sColor, clRed);
    Key.HowManyLoops:= StrToIntDef(sLoop, 0);
    Key.FullPath:= sName;
    //Key.FileName:= FCfgTrial.SList.Values['HootMedia'] + FCfgTrial.SList.Values['SStm'];

    Key.SchMan.Kind:= FCfgTrial.SList.Values[_Samp + _cSch];

    Msg:= FCfgTrial.SList.Values[_Samp + _cMsg];
  end;

  FNumKeyC:= StrToIntDef(FCfgTrial.SList.Values[_NumComp], 0);

  SetLength(FVetSupportC, FNumKeyC);
  For a1:= 0 to FNumKeyC-1 do begin
    With FVetSupportC[a1] do begin
      Key:= TKey.Create(Self);
      Key.Tag:= a1;
      Key.Visible:= False;
      Key.Cursor:= Self.Cursor;
      Key.Parent:= Self;
      Key.OnConsequence:= Consequence;
      Key.OnConsequence2:= Consequence2;
      Key.OnResponse:= Response;

      s1:= FCfgTrial.SList.Values[_Comp+IntToStr(a1+1)+_cBnd];
      R.Top:= StrToIntDef(Copy(s1, 0, pos(#32, s1)-1), 0);
      Delete(s1, 1, pos(#32, s1)); If Length(s1)>0 then While s1[1]=#32 do Delete(s1, 1, 1);
      R.Left:= StrToIntDef(Copy(s1, 0, pos(#32, s1)-1), 0);
      Delete(s1, 1, pos(#32, s1)); If Length(s1)>0 then While s1[1]=#32 do Delete(s1, 1, 1);
      R.Right:= StrToIntDef(Copy(s1, 0, pos(#32, s1)-1), 0);
      Delete(s1, 1, pos(#32, s1)); If Length(s1)>0 then While s1[1]=#32 do Delete(s1, 1, 1);
      R.Bottom:= StrToIntDef(s1, 0);
      Key.SetBounds(R.Left, R.Top, R.Right, R.Bottom);

      s1:= FCfgTrial.SList.Values[_Comp+IntToStr(a1+1)+_cStm] + #32;
      sName := HootMedia + Copy(s1, 0, pos(#32, s1)-1);
      Delete(s1, 1, pos(#32, s1)); If Length(s1)>0 then While s1[1]=#32 do Delete(s1, 1, 1);
      sLoop := Copy(s1, 0, pos(#32, s1)-1);
      Delete(s1, 1, pos(#32, s1)); If Length(s1)>0 then While s1[1]=#32 do Delete(s1, 1, 1);
      sColor := Copy(s1, 0, pos(#32, s1)-1);
      Key.Color := StrToIntDef(sColor, clRed);
      Key.HowManyLoops:= StrToIntDef(sLoop, 0);
      Key.FullPath:= sName;

      //Key.FileName:= FCfgTrial.SList.Values['HootMedia'] + FCfgTrial.SList.Values['C'+IntToStr(a1+1)+'Stm'];

      Key.SchMan.Kind:= FCfgTrial.SList.Values[_Comp+IntToStr(a1+1)+_cSch];
      Csq:= StrToIntDef(FCfgTrial.SList.Values[_Comp+IntToStr(a1+1)+_cCsq], 0);
      Usb := FRS232.GetUsbCsqFromValue (FCfgTrial.SList.Values[_Comp+IntToStr(a1+1)+_cUsb]);
      TO_ := StrToIntDef(FCfgTrial.SList.Values[_Comp+IntToStr(a1+1)+_cTO], 0);
      IET := FCfgTrial.SList.Values[_Comp+IntToStr(a1+1)+_cIET];
      Msg:= FCfgTrial.SList.Values[_Comp+IntToStr(a1+1)+_cMsg];
      Res:= FCfgTrial.SList.Values[_Comp+IntToStr(a1+1)+_cRes];
      Nxt:= FCfgTrial.SList.Values[_Comp+IntToStr(a1+1)+_cNxt];
      Application.ProcessMessages;
    end;
  end;

  with FKPlus do begin
    Csq:= StrToIntDef(FCfgTrial.SList.Values[_Kplus + _cCsq], 0);
    Usb:= StrToIntDef(FCfgTrial.SList.Values[_Kplus + _cUsb], 0);
    Msg:= FCfgTrial.SList.Values[_Kplus + _cMsg];
    Res:= FCfgTrial.SList.Values[_Kplus + _cRes];
    Nxt:= FCfgTrial.SList.Values[_Kplus + _cNxt];
    IET := FCfgTrial.SList.Values[_Kplus + _cIET];
    TO_:= StrToIntDef(FCfgTrial.SList.Values[_Kplus + _cTO],0);
  end;

  with FKMinus do begin
    Csq:= StrToIntDef(FCfgTrial.SList.Values[_Kminus + _cCsq], 0);
    Usb:= StrToIntDef(FCfgTrial.SList.Values[_Kminus + _cUsb], 0);
    Msg:= FCfgTrial.SList.Values[_Kminus + _cMsg];
    Res:= FCfgTrial.SList.Values[_Kminus + _cRes];
    Nxt:= FCfgTrial.SList.Values[_Kminus + _cNxt];
    IET := FCfgTrial.SList.Values[_Kminus + _cIET];
    TO_:= StrToIntDef(FCfgTrial.SList.Values[_Kminus + _cTO],0);
  end;

  StartTrial(Self);
end;

procedure TMTS.Response(Sender: TObject);
begin
  //ShowMessage(Sender.ClassName);
  if FFlagResp then
    begin
      if FFlagModCmps = True then
        begin
          FDataTicks:=
            FDataTicks +
            FormatFloat('####,####',GetTickCount - Ft) + #9 +
            'M1' + #9 +
            ExtractFileName(TKey(Sender).FullPath) + #9 +
            IntToStr(TKey(Sender).LastResponsePoint[0] + TKey(Sender).Left) + #9 +
            IntToStr(TKey(Sender).LastResponsePoint[1] + TKey(Sender).Top) + #13#10 + #9 + #9;
          if FFirstResp = False then
            begin
              FLatMod := GetTickCount;
              FFirstResp := True;
            end else;
        end
      else
        begin
          FDataTicks:=
            FDataTicks +
            FormatFloat('####,####',GetTickCount - Ft) + #9 +
            'C' + IntToStr(TKey(Sender).Tag + 1)+ #9 +
            ExtractFileName(TKey(Sender).FullPath) + #9 +
            IntToStr(TKey(Sender).LastResponsePoint[0] + TKey(Sender).Left) + #9 +
            IntToStr(TKey(Sender).LastResponsePoint[1] + TKey(Sender).Top) + #13#10 + #9 + #9;
          if FFirstResp = False then
            begin
              FLatCmp := GetTickCount;
              FFirstResp := True;
            end else;
        end;
      TKey(Sender).IncCounterResponse;
      if Assigned (FManager.OnStmResponse)then FManager.OnStmResponse (Sender);
      if Assigned(OnStmResponse) then FOnStmResponse (Sender);
    end;
end;

procedure TMTS.TimerDelayTimer(Sender: TObject);
begin
  FTimerDelay.Enabled:= False;
  ShowKeyC;
end;

procedure TMTS.TimerClockTimer(Sender: TObject);
var a1: Integer;
begin
  if FSupportS.Key.Visible then FSupportS.Key.SchMan.Clock;
  if not FFlagModCmps then
    for a1:= 0 to FNumKeyC-1 do
      if FVetSupportC[a1].Key.Visible then
        FVetSupportC[a1].Key.SchMan.Clock;
end;

procedure TMTS.TimerCsqTimer(Sender: TObject);
begin
  //FTimerClock.Enabled:= False;
  FTimerCsq.Enabled:= False;
  FCanPassTrial := True;
  EndTrial(Sender);
end;

procedure TMTS.WriteData(Sender: TObject);
var Pos_Mod, Resp_Mod,
    Lat_Mod, Dur_ModResponse, Dur_Mod, Atraso,
    Res_Mask, Lat_Mask, Dur_CmpResponse, Dur_Cmp,
    Disp, uDisp,
    PosComps, Res_Frq: String;
    a1: Integer;
begin
  If FSupportS.Msg = '' then FSupportS.Msg:= '--------';
  Pos_Mod:= LeftStr(FSupportS.Msg+#32#32#32#32#32#32#32#32, 8);

  If FDataSMsg = '' then FDataSMsg:= '--------';
  Resp_Mod := LeftStr(FDataSMsg+#32#32#32#32#32#32#32#32, 8);
 {begin}
 {Latência do Modelo, Duração de Resposta ao Modelo e Tempo de Exposição do Modelo}
  if FLatMod = 0 then
    begin
      Lat_Mod := '0' + #9 + 'ms';
      Dur_ModResponse := '0' + #9 + 'ms';
    end
  else
    begin
      Lat_Mod:= FormatFloat('####,####',FLatMod - Ft) + #9 + 'ms';
      Dur_ModResponse := FormatFloat('####,####',FDurMod - FLatMod) + #9 + 'ms';
    end;

  Dur_Mod := FormatFloat('####,####',FDurMod - Ft) + #9 + 'ms';

 {end}

  Atraso := FCfgTrial.SList.Values['Delay'] + #9 + 'ms' + #9;

  for a1:= 0 to FNumKeyC-1 do
    begin
      If FVetSupportC[a1].Msg = '' then FVetSupportC[a1].Msg:= '-';
      PosComps:= PosComps + FVetSupportC[a1].Msg + #32;
    end;

  If FDataCMsg = '' then FDataCMsg:= '--------';
  Res_Mask:= LeftStr(FDataCMsg+#32#32#32#32#32#32#32#32, 8);

 {begin}
 {Latência Comparação, Duração de Resposta a Comparação e Tempo de Exposição da Comparação}
  if FLatCmp = 0 then
    begin
      Lat_Mask:= '0' + #9 + 'ms';
      Dur_CmpResponse := '0' + #9 + 'ms';
    end
  else
    begin
      Lat_Mask:= FormatFloat('#####,###',FLatCmp - Ft2) + #9 + 'ms';
      Dur_CmpResponse := FormatFloat('#####,###',FDurCmp - FLatCmp) + #9 + 'ms';
    end;

  Dur_Cmp := FormatFloat('####,####',FDurCmp - Ft2) + #9 + 'ms';
 {end}

  Disp:= RightStr(IntToBin(FDataCsq)+#0, 8);
  uDisp := IntToStr(FDataUsb);

  for a1 := 0 to ComponentCount - 1 do
    begin
      if Components[a1] is TKey then
        begin
          Res_Frq := Res_Frq + 'C' + IntToStr ((TKey(Components[a1]).Tag + 1)) + '=' +
                                   IntToStr (TKey(Components[a1]).ResponseCount) + #9;
        end;
    end;
  Res_Frq := Res_Frq + 'BK='+ IntToStr(FDataBkGndI.Counter);

  FData:= Pos_Mod   + #9 +
          Resp_Mod  + #9 +
          Lat_Mod   + #9 +  //#9
          Dur_ModResponse   + #9 +
          Dur_Mod   + #9 +
          Atraso    + #9 +  //#9 #9
          PosComps  + #9 +
          Res_Mask  + #9 +
          Lat_Mask  + #9 +  //#9
          Dur_CmpResponse + #9 +
          Dur_Cmp + #9 +
          Disp      + #9 +
          uDisp     + #9 +
          Res_Frq;
          //   + #9 +
          //FDataBkGndS;        //Obsoleto

  FManager.OnConsequence(Sender);
  if Assigned(OnConsequence) then FOnConsequence (Sender);
end;

procedure TMTS.EndCorrection(Sender: TObject);
begin
  if Assigned (OnEndCorrection) then FOnEndCorrection (Sender);
end;

procedure TMTS.EndTrial(Sender: TObject);
begin
 // if FLatMod = 0 then FLatMod:= GetTickCount;
 // if Ft2 = 0 then FLatCmp:= 0 else FLatCmp := GetTickCount;
  FClockThread.FinishThreadExecution;
  WriteData(Sender);
  if FCanPassTrial then
    if Assigned(OnEndTrial) then FOnEndTrial(Sender);
end;

procedure TMTS.Hit(Sender: TObject);
begin
  if Assigned(OnHit) then FOnHit(Sender);
end;

procedure TMTS.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown (Key, Shift);

  if Key = 27 then    {esc}
    FFlagResp:= False;

  if Key = 107 {+} then begin
    if FFlagModCmps then begin
      FFlagModCmps:= False;
      FSupportS.Key.Visible:= False;

      FDataSMsg:= FKPlus.Msg;

      ShowKeyC;
    end else begin
      FDataCMsg:= FKPlus.Msg;
      FDataCsq:= FKPlus.Csq;
      FDataUsb := FKPlus.Usb;
      FResult:= FKPlus.Res;
      FIETConsequence:= FKPlus.IET;
      FTimeOut := FKPlus.TO_;
      Dispenser(FKPlus.Csq, FKPlus.Usb);
    end;
  end;

  if Key = 109{-} then begin
    if FFlagModCmps then begin
      FFlagModCmps:= False;
      FSupportS.Key.Visible:= False;

      FDataSMsg:= FKMinus.Msg;

      ShowKeyC;
    end else begin
      FDataCMsg:= FKMinus.Msg;
      FDataCsq:= FKMinus.Csq;
      FDataUsb := FKMinus.Usb;
      FResult:= FKMinus.Res;
      FTimeOut:= FKMinus.TO_;
      FIETConsequence:= FKMinus.IET;
      Dispenser(FKMinus.Csq, FKMinus.Usb);
    end;
  end;

  If (ssCtrl in Shift) and (Key = 13) {Enter} then
      begin
        if FFlagModCmps then FDataSMsg:= 'Cancel'
        else FDataCMsg:= 'Cancel';
        EndTrial(Self);
      end;
end;

procedure TMTS.KeyPress(var Key: Char);
begin
  inherited KeyPress(Key);

end;

procedure TMTS.KeyUp(var Key: Word; Shift: TShiftState);
begin
  inherited KeyUp (Key, Shift);
  If Key = 27 then
    FFlagResp:= True;
end;

procedure TMTS.Miss(Sender: TObject);
begin
  if Assigned(OnMiss) then FOnMiss (Sender);
end;

procedure TMTS.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  FDataTicks:= FDataTicks +
             FormatFloat('####,####',GetTickCount - Ft) + #9 +
             '-' + #9 +
             '-' + #9 +
             IntToStr(X) + #9 + IntToStr(Y) + #13#10 + #9 + #9;
  FDataBkGndI.Plus(1);
  //FDataBkGndS := FDataBkGndS + IntToStr(X)+ ',' + IntToStr(Y) + #9;      //obsoleto
  FManager.OnBkGndResponse(FDataBkGndI);
  if Assigned(OnBkGndResponse) then FOnBkGndResponse(Self);
end;

procedure TMTS.None(Sender: TObject);
begin
  if Assigned(OnNone) then FOnMiss (Sender);
end;

procedure TMTS.SetTimerCsq;
begin
  FTimerCsq.Interval := FTrialInterval;
end;

procedure TMTS.ShowKeyC;
var a1: Integer;
begin
  FFlagModCmps:= False;
  for a1:= 0 to FNumKeyC - 1 do
    begin
      FVetSupportC[a1].Key.Play;
      FVetSupportC[a1].Key.Visible:= True;
    end;
  FFirstResp := False;
  FFlagResp := True;
  Ft2 := GetTickCount;
  //FTimerClock.Enabled := True;
end;

procedure TMTS.StartTrial(Sender: TObject);
begin
  if FCanPassTrial then FTimerCsq.Enabled:= False else FTimerCsq.Enabled:= True;
  if FIsCorrection then
    begin
      BeginCorrection (Sender);
    end;
  FSupportS.Key.Play;
  FFlagResp:= True;
  FFirstResp := False;
  FLatMod:= 0;
  FDurMod := 0;
  Ft2 := 0;
  FLatCmp:= 0;
  FDurCmp := 0;
  FClockThread := TClockThread.Create(False);
  FClockThread.OnTimer := TimerClockTimer;
  Ft := GetTickCount;
  //FTimerClock.Enabled:= True;
end;

procedure TMTS.SConsequence(Sender: TObject);
begin
  FDurMod := GetTickCount;

  FSupportS.Key.Stop;
  FSupportS.Key.Enabled:= False;
  FSupportS.Key.Visible:= not FDelayed;

  FDataSMsg:= FSupportS.Msg;
  FFlagResp := False;
  //FTimerClock.Enabled := False;

  if FTimerDelay.Interval > 0 then FTimerDelay.Enabled:= True
  else ShowKeyC;
end;

procedure TMTS.BeginCorrection(Sender: TObject);
begin
  if Assigned (OnBeginCorrection) then FOnBeginCorrection (Sender);
end;

procedure TMTS.Consequence(Sender: TObject);
begin
  If FFlagResp then begin
    FFlagResp := False;
    FDurCmp := GetTickCount;
    //Self.Enabled := False;

    if (FVetSupportC[TKey(Sender).Tag].Res = T_HIT) or
       (FVetSupportC[TKey(Sender).Tag].Res = T_MISS)  then
      begin
        if FVetSupportC[TKey(Sender).Tag].Res = T_HIT then FResult := 'HIT';

        if FVetSupportC[TKey(Sender).Tag].Res = T_MISS then FResult := 'MISS';

      end
    else FResult := 'NONE';


   // FNextTrial:= FVetSupportC[TKey(Sender).Tag].Nxt;
    FDataCsq:= FVetSupportC[TKey(Sender).Tag].Csq;
    FDataUsb := FVetSupportC[TKey(Sender).Tag].Usb;
    FTimeOut := FVetSupportC[TKey(Sender).Tag].TO_;
    FIETConsequence:= FVetSupportC[TKey(Sender).Tag].IET;
    if FVetSupportC[TKey(Sender).Tag].Nxt = T_CRT then FNextTrial := T_CRT
    else FNextTrial := FVetSupportC[TKey(Sender).Tag].Nxt;

    if FVetSupportC[TKey(Sender).Tag].Msg = 'GONOGO' then
      begin       //GONOGO serve apenas para a diferenciação entre Go e NoGo nos esquemas RRRT
         if FFlagCsq2Fired then FDataCMsg := '1'
         else  FDataCMsg := '2';

         if (FFlagCsq2Fired = False) and (FVetSupportC[TKey(Sender).Tag].Res = T_HIT) then
           begin
             FResult := 'MISS';
           end;
         if (FFlagCsq2Fired = False) and (FVetSupportC[TKey(Sender).Tag].Res = T_MISS) then
           begin
             FDataCsq := 0;
             FDataUSB := 0;
             FTimeOut := 0;
             FResult := 'HIT';
           end;

         if FFlagCsq2Fired and (FVetSupportC[TKey(Sender).Tag].Res = T_HIT) then FTimeOut := 0;
         if FFlagCsq2Fired and (FVetSupportC[TKey(Sender).Tag].Res = T_MISS) then
           begin
             FDataCsq := 0;
             FDataUSB := 0;
           end;
      end
    else FDataCMsg:= FVetSupportC[TKey(Sender).Tag].Msg;

    Dispenser(FDataCsq, FDataUsb);
    if FResult = 'HIT' then  Hit(Sender);
    if FResult = 'MISS' then  Miss(Sender);
    if FResult = 'NONE' then  None(Sender);

    if FCanPassTrial then FTimerCsq.Enabled:= True else
      begin
        EndTrial(Sender);
        Ft := GetTickCount;
        FFlagResp:= True;
      end;
  end;
end;


procedure TMTS.Consequence2(Sender: TObject);
begin
  if FFlagCsq2Fired = False then FFlagCsq2Fired := True;
  FPLP.OutPortOn (FKPlus.Csq);
  FRS232.Dispenser(FKPlus.Usb);
end;

end.
