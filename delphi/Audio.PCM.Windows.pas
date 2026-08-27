unit Audio.PCM.Windows;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,
  Winapi.Windows,
  Winapi.Messages,
  Winapi.MMSystem;

type
  TPcmDataEvent = procedure(Sender: TObject; const Data: TBytes;
    IsVoice: Boolean) of object;

  TWindowsPcmAudio = class
  private type
    TInputBuffer = class
    public
      Header: TWaveHdr;
      Data: TBytes;
      constructor Create(ASize: Integer);
    end;

    TOutputBuffer = class
    public
      Header: TWaveHdr;
      Data: TBytes;
      constructor Create(const AData: TBytes);
    end;
  private
    FLock: TObject;
    FWindowHandle: HWND;
    FWaveIn: HWAVEIN;
    FWaveOut: HWAVEOUT;
    FInputActive: Boolean;
    FOutputActive: Boolean;
    FInputBuffers: TObjectList<TInputBuffer>;
    FOutputBuffers: TObjectList<TOutputBuffer>;
    FQueuedOutputBytes: Int64;
    FOnInputData: TPcmDataEvent;
    procedure CheckInputResult(const Operation: string; ResultCode: MMRESULT);
    procedure CheckOutputResult(const Operation: string; ResultCode: MMRESULT);
    procedure WndProc(var Msg: TMessage);
    procedure InputBufferReady(Header: PWaveHdr);
    procedure OutputBufferDone(WaveOut: HWAVEOUT; Header: PWaveHdr);
    procedure OpenInput;
    procedure OpenOutput;
    procedure CloseInput;
    procedure CloseOutput;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    procedure Play(const Data: TBytes);
    procedure ClearPlayback;
    function QueuedPlaybackMilliseconds: Cardinal;
    property OnInputData: TPcmDataEvent read FOnInputData write FOnInputData;
  end;

implementation

uses
  System.Math;

const
  CInputSampleRate = 16000;
  COutputSampleRate = 24000;
  CBitsPerSample = 16;
  CChannels = 1;
  CInputSampleCount = 4096;
  CInputBufferCount = 4;
  CVoiceRmsThreshold = 0.003;



{ TWindowsPcmAudio.TInputBuffer }

constructor TWindowsPcmAudio.TInputBuffer.Create(ASize: Integer);
begin
  inherited Create;
  SetLength(Data, ASize);
  FillChar(Header, SizeOf(Header), 0);
  Header.lpData := PAnsiChar(@Data[0]);
  Header.dwBufferLength := Length(Data);
end;

{ TWindowsPcmAudio.TOutputBuffer }

constructor TWindowsPcmAudio.TOutputBuffer.Create(const AData: TBytes);
begin
  inherited Create;
  Data := Copy(AData);
  FillChar(Header, SizeOf(Header), 0);
  Header.lpData := PAnsiChar(@Data[0]);
  Header.dwBufferLength := Length(Data);
  Header.dwUser := DWORD_PTR(Self);
end;

{ TWindowsPcmAudio }

constructor TWindowsPcmAudio.Create;
begin
  inherited Create;
  FLock := TObject.Create;
  FInputBuffers := TObjectList<TInputBuffer>.Create(True);
  FOutputBuffers := TObjectList<TOutputBuffer>.Create(True);
  FWindowHandle := AllocateHWnd(WndProc);
end;

destructor TWindowsPcmAudio.Destroy;
begin
  FOnInputData := nil;
  Stop;
  if FWindowHandle <> 0 then
    DeallocateHWnd(FWindowHandle);
  FOutputBuffers.Free;
  FInputBuffers.Free;
  FLock.Free;
  inherited;
end;

procedure TWindowsPcmAudio.WndProc(var Msg: TMessage);
begin
  case Msg.Msg of
    MM_WIM_DATA:
      try
        InputBufferReady(PWaveHdr(Msg.LParam));
      except
        // Prevent exceptions from escaping WndProc
      end;
    MM_WOM_DONE:
      try
        OutputBufferDone(HWAVEOUT(Msg.WParam), PWaveHdr(Msg.LParam));
      except
        // Prevent exceptions from escaping WndProc
      end;
  else
    Msg.Result := DefWindowProc(FWindowHandle, Msg.Msg, Msg.WParam, Msg.LParam);
  end;
end;

procedure TWindowsPcmAudio.CheckInputResult(const Operation: string;
  ResultCode: MMRESULT);
var
  ErrorText: array[0..255] of WideChar;
begin
  if ResultCode = MMSYSERR_NOERROR then
    Exit;
  ErrorText[0] := #0;
  waveInGetErrorTextW(ResultCode, ErrorText, Length(ErrorText));
  raise EOSError.CreateFmt('%s failed (%d): %s',
    [Operation, ResultCode, string(ErrorText)]);
end;

procedure TWindowsPcmAudio.CheckOutputResult(const Operation: string;
  ResultCode: MMRESULT);
var
  ErrorText: array[0..255] of WideChar;
begin
  if ResultCode = MMSYSERR_NOERROR then
    Exit;
  ErrorText[0] := #0;
  waveOutGetErrorTextW(ResultCode, ErrorText, Length(ErrorText));
  raise EOSError.CreateFmt('%s failed (%d): %s',
    [Operation, ResultCode, string(ErrorText)]);
end;

procedure TWindowsPcmAudio.OpenInput;
var
  Format: TWaveFormatEx;
  Buffer: TInputBuffer;
  Index: Integer;
begin
  FillChar(Format, SizeOf(Format), 0);
  Format.wFormatTag := WAVE_FORMAT_PCM;
  Format.nChannels := CChannels;
  Format.nSamplesPerSec := CInputSampleRate;
  Format.wBitsPerSample := CBitsPerSample;
  Format.nBlockAlign := Format.nChannels * Format.wBitsPerSample div 8;
  Format.nAvgBytesPerSec := Format.nSamplesPerSec * Format.nBlockAlign;

  CheckInputResult('waveInOpen', waveInOpen(@FWaveIn, WAVE_MAPPER, @Format,
    FWindowHandle, 0, CALLBACK_WINDOW));
  try
    for Index := 0 to CInputBufferCount - 1 do
    begin
      Buffer := TInputBuffer.Create(CInputSampleCount * Format.nBlockAlign);
      FInputBuffers.Add(Buffer);
      CheckInputResult('waveInPrepareHeader', waveInPrepareHeader(FWaveIn,
        @Buffer.Header, SizeOf(Buffer.Header)));
      CheckInputResult('waveInAddBuffer', waveInAddBuffer(FWaveIn,
        @Buffer.Header, SizeOf(Buffer.Header)));
    end;
    TMonitor.Enter(FLock);
    try
      FInputActive := True;
    finally
      TMonitor.Exit(FLock);
    end;
    CheckInputResult('waveInStart', waveInStart(FWaveIn));
  except
    CloseInput;
    raise;
  end;
end;

procedure TWindowsPcmAudio.OpenOutput;
var
  Format: TWaveFormatEx;
begin
  FillChar(Format, SizeOf(Format), 0);
  Format.wFormatTag := WAVE_FORMAT_PCM;
  Format.nChannels := CChannels;
  Format.nSamplesPerSec := COutputSampleRate;
  Format.wBitsPerSample := CBitsPerSample;
  Format.nBlockAlign := Format.nChannels * Format.wBitsPerSample div 8;
  Format.nAvgBytesPerSec := Format.nSamplesPerSec * Format.nBlockAlign;

  CheckOutputResult('waveOutOpen', waveOutOpen(@FWaveOut, WAVE_MAPPER, @Format,
    FWindowHandle, 0, CALLBACK_WINDOW));
  TMonitor.Enter(FLock);
  try
    FOutputActive := True;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TWindowsPcmAudio.CloseInput;
var
  WaveIn: HWAVEIN;
  Buffer: TInputBuffer;
begin
  TMonitor.Enter(FLock);
  try
    FInputActive := False;
    WaveIn := FWaveIn;
    FWaveIn := 0;
  finally
    TMonitor.Exit(FLock);
  end;

  if WaveIn = 0 then
    Exit;

  waveInStop(WaveIn);
  waveInReset(WaveIn);
  for Buffer in FInputBuffers do
    waveInUnprepareHeader(WaveIn, @Buffer.Header, SizeOf(Buffer.Header));
  waveInClose(WaveIn);
  FInputBuffers.Clear;
end;

procedure TWindowsPcmAudio.CloseOutput;
var
  WaveOut: HWAVEOUT;
  Buffer: TOutputBuffer;
begin
  TMonitor.Enter(FLock);
  try
    FOutputActive := False;
    WaveOut := FWaveOut;
    FWaveOut := 0;
  finally
    TMonitor.Exit(FLock);
  end;

  if WaveOut = 0 then
    Exit;

  waveOutReset(WaveOut);
  TMonitor.Enter(FLock);
  try
    for Buffer in FOutputBuffers do
      waveOutUnprepareHeader(WaveOut, @Buffer.Header, SizeOf(Buffer.Header));
    FOutputBuffers.Clear;
    FQueuedOutputBytes := 0;
  finally
    TMonitor.Exit(FLock);
  end;
  waveOutClose(WaveOut);
end;

procedure TWindowsPcmAudio.Start;
begin
  Stop;
  OpenOutput;
  try
    OpenInput;
  except
    CloseOutput;
    raise;
  end;
end;

procedure TWindowsPcmAudio.Stop;
begin
  CloseInput;
  CloseOutput;
end;

procedure TWindowsPcmAudio.InputBufferReady(Header: PWaveHdr);
var
  Captured: TBytes;
  IsActive: Boolean;
  IsVoice: Boolean;
  Sample: PSmallInt;
  SampleCount: Integer;
  Index: Integer;
  SumSquares: Double;
  RootMeanSquare: Double;
  Handler: TPcmDataEvent;
begin
  if (Header = nil) or (Header.dwBytesRecorded = 0) then
    Exit;

  SetLength(Captured, Header.dwBytesRecorded);
  Move(Header.lpData^, Captured[0], Header.dwBytesRecorded);

  SampleCount := Length(Captured) div SizeOf(SmallInt);
  SumSquares := 0;
  if SampleCount > 0 then
  begin
    Sample := PSmallInt(@Captured[0]);
    for Index := 0 to SampleCount - 1 do
    begin
      SumSquares := SumSquares + Sqr(Sample^ / 32768.0);
      Inc(Sample);
    end;
    RootMeanSquare := Sqrt(SumSquares / SampleCount);
  end
  else
    RootMeanSquare := 0;
  IsVoice := RootMeanSquare > CVoiceRmsThreshold;

  TMonitor.Enter(FLock);
  try
    IsActive := FInputActive and (FWaveIn <> 0);
    if IsActive then
    begin
      Header.dwBytesRecorded := 0;
      waveInAddBuffer(FWaveIn, Header, SizeOf(TWaveHdr));
    end;
    Handler := FOnInputData;
  finally
    TMonitor.Exit(FLock);
  end;

  if IsActive and Assigned(Handler) then
    Handler(Self, Captured, IsVoice);
end;

procedure TWindowsPcmAudio.Play(const Data: TBytes);
var
  Buffer: TOutputBuffer;
  WaveOut: HWAVEOUT;
  ResultCode: MMRESULT;
begin
  if Length(Data) = 0 then
    Exit;

  Buffer := TOutputBuffer.Create(Data);
  try
    TMonitor.Enter(FLock);
    try
      if not FOutputActive or (FWaveOut = 0) then
        Exit;
      WaveOut := FWaveOut;
      ResultCode := waveOutPrepareHeader(WaveOut, @Buffer.Header,
        SizeOf(Buffer.Header));
      CheckOutputResult('waveOutPrepareHeader', ResultCode);
      FOutputBuffers.Add(Buffer);
      Inc(FQueuedOutputBytes, Length(Buffer.Data));
    finally
      TMonitor.Exit(FLock);
    end;

    ResultCode := waveOutWrite(WaveOut, @Buffer.Header, SizeOf(Buffer.Header));
    if ResultCode <> MMSYSERR_NOERROR then
    begin
      TMonitor.Enter(FLock);
      try
        FOutputBuffers.Extract(Buffer);
        Dec(FQueuedOutputBytes, Length(Buffer.Data));
      finally
        TMonitor.Exit(FLock);
      end;
      waveOutUnprepareHeader(WaveOut, @Buffer.Header, SizeOf(Buffer.Header));
      CheckOutputResult('waveOutWrite', ResultCode);
    end;
    Buffer := nil;
  finally
    Buffer.Free;
  end;
end;

procedure TWindowsPcmAudio.OutputBufferDone(WaveOut: HWAVEOUT;
  Header: PWaveHdr);
var
  Buffer: TOutputBuffer;
begin
  if Header = nil then
    Exit;
  Buffer := TOutputBuffer(Pointer(Header.dwUser));
  if Buffer = nil then
    Exit;

  TMonitor.Enter(FLock);
  try
    if FOutputBuffers.IndexOf(Buffer) < 0 then
      Exit;
    FOutputBuffers.Extract(Buffer);
    Dec(FQueuedOutputBytes, Length(Buffer.Data));
    if FQueuedOutputBytes < 0 then
      FQueuedOutputBytes := 0;
  finally
    TMonitor.Exit(FLock);
  end;
  waveOutUnprepareHeader(WaveOut, Header, SizeOf(TWaveHdr));
  Buffer.Free;
end;

procedure TWindowsPcmAudio.ClearPlayback;
var
  WaveOut: HWAVEOUT;
begin
  TMonitor.Enter(FLock);
  try
    WaveOut := FWaveOut;
  finally
    TMonitor.Exit(FLock);
  end;
  if WaveOut <> 0 then
    waveOutReset(WaveOut);
end;

function TWindowsPcmAudio.QueuedPlaybackMilliseconds: Cardinal;
var
  ByteCount: Int64;
begin
  TMonitor.Enter(FLock);
  try
    ByteCount := FQueuedOutputBytes;
  finally
    TMonitor.Exit(FLock);
  end;
  Result := Cardinal((ByteCount * 1000) div
    (COutputSampleRate * CChannels * (CBitsPerSample div 8)));
end;

end.
