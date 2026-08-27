unit Gemini.Live.Client;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  System.SysUtils,
  System.Win.WinRT,
  Winapi.Windows,
  Winapi.Foundation,
  Winapi.Networking.Sockets,
  Winapi.Storage.Streams,
  Audio.PCM.Windows;

type
  TGeminiLiveState = (Disconnected, Connecting, Active, Stopping, Error);
  TTestStatus = (tsEmpty, tsInTest, tsTestEnded);

  TQuestionData = record
    HasActiveQuestion: Boolean;
    QuestionNumber: Integer;
    TotalQuestions: Integer;
    QuestionText: string;
    Options: TArray<string>;
    SelectedAnswer: string;
  end;

  TAnswerRecordedData = record
    QuestionNumber: Integer;
    SelectedOption: string;
    IsCorrect: Boolean;
    CorrectAnswer: string;
    AnsweredCount: Integer;
    TotalQuestions: Integer;
  end;

  TResultsSummaryData = record
    TotalQuestions: Integer;
    AnsweredCount: Integer;
    CorrectCount: Integer;
    IncorrectCount: Integer;
    UnansweredCount: Integer;
    ScorePercentage: Integer;
    SummaryMessage: string;
  end;

  TTestReportImageData = record
    SessionId: string;
    ScorePercentage: Integer;
    Status: string; // 'passed' | 'failed'
    SummaryMessage: string;
    ImageBase64: string;
  end;

  TGeminiLiveStateEvent = procedure(Sender: TObject;
    State: TGeminiLiveState) of object;
  TGeminiLiveTestStatusEvent = procedure(Sender: TObject;
    Status: TTestStatus; const StatusText: string) of object;
  TGeminiLiveErrorEvent = procedure(Sender: TObject;
    const ErrorMessage: string) of object;
  TGeminiLiveTextEvent = procedure(Sender: TObject;
    const Text: string) of object;
  TGeminiLiveQuestionEvent = procedure(Sender: TObject;
    const Question: TQuestionData) of object;
  TGeminiLiveAnswerRecordedEvent = procedure(Sender: TObject;
    const AnswerData: TAnswerRecordedData) of object;
  TGeminiLiveResultsEvent = procedure(Sender: TObject;
    const Results: TResultsSummaryData) of object;
  TGeminiLiveReportImageEvent = procedure(Sender: TObject;
    const ReportImage: TTestReportImageData) of object;

  TGeminiLiveClient = class;

  TWebSocketMessageHandler = class(TInspectableObject,
    TypedEventHandler_2__IMessageWebSocket__IMessageWebSocketMessageReceivedEventArgs)
  private
    FOwner: TGeminiLiveClient;
  public
    constructor Create(AOwner: TGeminiLiveClient);
    procedure Detach;
    procedure Invoke(Sender: IMessageWebSocket;
      Args: IMessageWebSocketMessageReceivedEventArgs); safecall;
  end;

  TWebSocketClosedHandler = class(TInspectableObject,
    TypedEventHandler_2__IWebSocket__IWebSocketClosedEventArgs)
  private
    FOwner: TGeminiLiveClient;
  public
    constructor Create(AOwner: TGeminiLiveClient);
    procedure Detach;
    procedure Invoke(Sender: IWebSocket;
      Args: IWebSocketClosedEventArgs); safecall;
  end;

  TGeminiLiveClient = class
  private const
    CInactivityTimeoutMs = 30000;
    CMaximumQueuedMessages = 32;
  private
    FServerUrl: string;
    FContext: string;
    FState: TGeminiLiveState;
    FStateLock: TObject;
    FQueueLock: TObject;
    FActivityLock: TObject;
    FStopEvent: TEvent;
    FSendEvent: TEvent;
    FReadyEvent: TEvent;
    FSendQueue: TQueue<string>;
    FWorker: TThread;
    FAudio: TWindowsPcmAudio;
    FMessageWebSocket: IMessageWebSocket;
    FWebSocket: IWebSocket;
    FWriter: IDataWriter;
    FConnectAction: IAsyncAction;
    FMessageHandlerObject: TWebSocketMessageHandler;
    FClosedHandlerObject: TWebSocketClosedHandler;
    FMessageHandler:
      TypedEventHandler_2__IMessageWebSocket__IMessageWebSocketMessageReceivedEventArgs;
    FClosedHandler:
      TypedEventHandler_2__IWebSocket__IWebSocketClosedEventArgs;
    FMessageToken: EventRegistrationToken;
    FClosedToken: EventRegistrationToken;
    FSocketConnected: Boolean;
    FInactivityDeadline: UInt64;
    FShuttingDown: Boolean;
    FLanguage: string;
    FOnStateChanged: TGeminiLiveStateEvent;
    FOnError: TGeminiLiveErrorEvent;
    FOnTextReceived: TGeminiLiveTextEvent;
    FTestStatus: TTestStatus;
    FOnTestStatusChanged: TGeminiLiveTestStatusEvent;
    FOnQuestionReceived: TGeminiLiveQuestionEvent;
    FOnAnswerRecorded: TGeminiLiveAnswerRecordedEvent;
    FOnResultsReceived: TGeminiLiveResultsEvent;
    FOnTestReportImage: TGeminiLiveReportImageEvent;
    function GetState: TGeminiLiveState;
    procedure SetState(NewState: TGeminiLiveState);
    procedure NotifyState(NewState: TGeminiLiveState);
    procedure NotifyError(const ErrorMessage: string);
    procedure Fail(const ErrorMessage: string);
    function BuildConnectionUrl: string;
    procedure WorkerExecute;
    procedure ConnectWebSocket;
    procedure CleanupWebSocket;
    procedure WaitForAsync(const AsyncOperation: IInterface);
    procedure SendMessage(const MessageText: string);
    procedure EnqueueMessage(const MessageText: string);
    function TryDequeueMessage(out MessageText: string): Boolean;
    procedure ClearSendQueue;
    procedure MarkActivity(AdditionalMilliseconds: Cardinal = 0);
    function InactivityExpired: Boolean;
    procedure AudioInput(Sender: TObject; const Data: TBytes;
      IsVoice: Boolean);
    procedure HandleMessage(const MessageText: string);
    procedure HandleWebSocketClosed(Code: Word; const Reason: string);
  public
    constructor Create(const AServerUrl: string);
    destructor Destroy; override;
    procedure Start(const AContext: string = ''; const ALanguage: string = '');
    procedure Stop;
    procedure RecordAnswer(const SelectedOption: string; QuestionNumber: Integer = 0);
    procedure RequestNextQuestion;
    procedure RequestExplanation(QuestionNumber: Integer = 0);
    procedure RequestResults;
    procedure RequestEndTest;
    property State: TGeminiLiveState read GetState;
    property ServerUrl: string read FServerUrl write FServerUrl;
    property Language: string read FLanguage write FLanguage;
    property TestStatus: TTestStatus read FTestStatus;
    property OnStateChanged: TGeminiLiveStateEvent read FOnStateChanged
      write FOnStateChanged;
    property OnTestStatusChanged: TGeminiLiveTestStatusEvent
      read FOnTestStatusChanged write FOnTestStatusChanged;
    property OnError: TGeminiLiveErrorEvent read FOnError write FOnError;
    property OnTextReceived: TGeminiLiveTextEvent read FOnTextReceived
      write FOnTextReceived;
    property OnQuestionReceived: TGeminiLiveQuestionEvent
      read FOnQuestionReceived write FOnQuestionReceived;
    property OnAnswerRecorded: TGeminiLiveAnswerRecordedEvent
      read FOnAnswerRecorded write FOnAnswerRecorded;
    property OnResultsReceived: TGeminiLiveResultsEvent
      read FOnResultsReceived write FOnResultsReceived;
    property OnTestReportImage: TGeminiLiveReportImageEvent
      read FOnTestReportImage write FOnTestReportImage;
  end;

function GeminiLiveStateText(State: TGeminiLiveState): string;
function TestStatusDisplay(Status: TTestStatus): string;

implementation

uses
  System.JSON,
  System.NetEncoding,
  Winapi.ActiveX,
  Winapi.CommonTypes,
  Winapi.WinRT;

function GeminiLiveStateText(State: TGeminiLiveState): string;
begin
  case State of
    TGeminiLiveState.Disconnected: Result := 'Desconectado';
    TGeminiLiveState.Connecting: Result := 'Conectando ao Gemini Live...';
    TGeminiLiveState.Active: Result := 'Ativo - pode falar';
    TGeminiLiveState.Stopping: Result := 'Encerrando...';
    TGeminiLiveState.Error: Result := 'Erro na comunicação';
  else
    Result := '';
  end;
end;

function TestStatusDisplay(Status: TTestStatus): string;
begin
  case Status of
    TTestStatus.tsEmpty: Result := 'Empty (no test yet)';
    TTestStatus.tsInTest: Result := 'In test';
    TTestStatus.tsTestEnded: Result := 'Test ended';
  else
    Result := 'Empty (no test yet)';
  end;
end;

{ TWebSocketMessageHandler }

constructor TWebSocketMessageHandler.Create(AOwner: TGeminiLiveClient);
begin
  inherited Create;
  FOwner := AOwner;
end;

procedure TWebSocketMessageHandler.Detach;
begin
  FOwner := nil;
end;

procedure TWebSocketMessageHandler.Invoke(Sender: IMessageWebSocket;
  Args: IMessageWebSocketMessageReceivedEventArgs);
var
  Reader: IDataReader;
  MessageText: string;
begin
  if (FOwner = nil) or (Args = nil) then
    Exit;
  try
    Reader := Args.GetDataReader;
    Reader.UnicodeEncoding_ := UnicodeEncoding.Utf8;
    MessageText := TWindowsString.HStringToString(
      Reader.ReadString(Reader.UnconsumedBufferLength));
    if FOwner <> nil then
      FOwner.HandleMessage(MessageText);
  except
    on E: Exception do
      if FOwner <> nil then
        FOwner.Fail('Falha ao receber dados do servidor: ' + E.Message);
  end;
end;

{ TWebSocketClosedHandler }

constructor TWebSocketClosedHandler.Create(AOwner: TGeminiLiveClient);
begin
  inherited Create;
  FOwner := AOwner;
end;

procedure TWebSocketClosedHandler.Detach;
begin
  FOwner := nil;
end;

procedure TWebSocketClosedHandler.Invoke(Sender: IWebSocket;
  Args: IWebSocketClosedEventArgs);
var
  Code: Word;
  Reason: string;
begin
  if FOwner = nil then
    Exit;
  Code := 1006;
  Reason := '';
  if Args <> nil then
  begin
    Code := Args.Code;
    Reason := TWindowsString.HStringToString(Args.Reason);
  end;
  if FOwner <> nil then
    FOwner.HandleWebSocketClosed(Code, Reason);
end;

{ TGeminiLiveClient }

constructor TGeminiLiveClient.Create(const AServerUrl: string);
begin
  inherited Create;
  FServerUrl := AServerUrl;
  FLanguage := 'en-US';
  FState := TGeminiLiveState.Disconnected;
  FTestStatus := TTestStatus.tsEmpty;
  FStateLock := TObject.Create;
  FQueueLock := TObject.Create;
  FActivityLock := TObject.Create;
  FStopEvent := TEvent.Create(nil, True, False, '');
  FSendEvent := TEvent.Create(nil, True, False, '');
  FReadyEvent := TEvent.Create(nil, True, False, '');
  FSendQueue := TQueue<string>.Create;
  FAudio := TWindowsPcmAudio.Create;
  FAudio.OnInputData := AudioInput;
end;

destructor TGeminiLiveClient.Destroy;
begin
  FShuttingDown := True;
  FOnStateChanged := nil;
  FOnTestStatusChanged := nil;
  FOnError := nil;
  FOnTextReceived := nil;
  Stop;
  FAudio.OnInputData := nil;
  FAudio.Free;
  FSendQueue.Free;
  FReadyEvent.Free;
  FSendEvent.Free;
  FStopEvent.Free;
  FActivityLock.Free;
  FQueueLock.Free;
  FStateLock.Free;
  inherited;
end;

function TGeminiLiveClient.GetState: TGeminiLiveState;
begin
  TMonitor.Enter(FStateLock);
  try
    Result := FState;
  finally
    TMonitor.Exit(FStateLock);
  end;
end;

procedure TGeminiLiveClient.SetState(NewState: TGeminiLiveState);
var
  Changed: Boolean;
begin
  TMonitor.Enter(FStateLock);
  try
    Changed := FState <> NewState;
    FState := NewState;
  finally
    TMonitor.Exit(FStateLock);
  end;
  if Changed then
    NotifyState(NewState);
end;

procedure TGeminiLiveClient.NotifyState(NewState: TGeminiLiveState);
var
  Handler: TGeminiLiveStateEvent;
begin
  if FShuttingDown then
    Exit;
  Handler := FOnStateChanged;
  if not Assigned(Handler) then
    Exit;
  if GetCurrentThreadID = MainThreadID then
    Handler(Self, NewState)
  else
    TThread.Queue(nil,
      procedure
      begin
        Handler(Self, NewState);
      end);
end;

procedure TGeminiLiveClient.NotifyError(const ErrorMessage: string);
var
  Handler: TGeminiLiveErrorEvent;
begin
  if FShuttingDown then
    Exit;
  Handler := FOnError;
  if not Assigned(Handler) then
    Exit;
  if GetCurrentThreadID = MainThreadID then
    Handler(Self, ErrorMessage)
  else
    TThread.Queue(nil,
      procedure
      begin
        Handler(Self, ErrorMessage);
      end);
end;

procedure TGeminiLiveClient.Fail(const ErrorMessage: string);
begin
  if FStopEvent.WaitFor(0) = wrSignaled then
    Exit;
  SetState(TGeminiLiveState.Error);
  NotifyError(ErrorMessage);
  FStopEvent.SetEvent;
  FSendEvent.SetEvent;
  FReadyEvent.SetEvent;
end;

function TGeminiLiveClient.BuildConnectionUrl: string;
var
  Separator: Char;
begin
  Result := FServerUrl;
  if Result.Contains('?') then
    Separator := '&'
  else
    Separator := '?';

  if FLanguage <> '' then
  begin
    Result := Result + Separator + 'lang=' + TNetEncoding.URL.Encode(FLanguage);
    Separator := '&';
  end;

  if FContext <> '' then
  begin
    Result := Result + Separator + 'context=' + TNetEncoding.URL.Encode(FContext);
  end;
end;

procedure TGeminiLiveClient.Start(const AContext: string; const ALanguage: string);
begin
  if FWorker <> nil then
    Stop;
  FContext := AContext;
  if ALanguage <> '' then
    FLanguage := ALanguage
  else if FLanguage = '' then
    FLanguage := 'en-US';
  ClearSendQueue;
  FStopEvent.ResetEvent;
  FSendEvent.ResetEvent;
  FReadyEvent.ResetEvent;
  MarkActivity;
  SetState(TGeminiLiveState.Connecting);
  FWorker := TThread.CreateAnonymousThread(WorkerExecute);
  FWorker.FreeOnTerminate := False;
  FWorker.Start;
end;

procedure TGeminiLiveClient.Stop;
var
  ConnectAction: IAsyncAction;
  AsyncInfo: IAsyncInfo;
begin
  if FWorker = nil then
  begin
    if not FShuttingDown then
      SetState(TGeminiLiveState.Disconnected);
    Exit;
  end;

  if State <> TGeminiLiveState.Error then
    SetState(TGeminiLiveState.Stopping);
  FStopEvent.SetEvent;
  FSendEvent.SetEvent;
  FReadyEvent.SetEvent;

  TMonitor.Enter(FStateLock);
  try
    ConnectAction := FConnectAction;
  finally
    TMonitor.Exit(FStateLock);
  end;
  if ConnectAction <> nil then
    try
      if Supports(ConnectAction, IAsyncInfo, AsyncInfo) then
        AsyncInfo.Cancel;
    except
      // The connection may have completed between reading and cancelling it.
    end;

  FWorker.WaitFor;
  FreeAndNil(FWorker);
  ClearSendQueue;
  if not FShuttingDown then
    if State = TGeminiLiveState.Disconnected then
      NotifyState(TGeminiLiveState.Disconnected)
    else
      SetState(TGeminiLiveState.Disconnected);
end;

procedure TGeminiLiveClient.WorkerExecute;
var
  MessageText: string;
  InitResult: HRESULT;
  ComInitialized: Boolean;
begin
  ComInitialized := False;
  try
    InitResult := CoInitializeEx(nil, COINIT_MULTITHREADED);
    ComInitialized := Succeeded(InitResult);
    if not ComInitialized and (InitResult <> RPC_E_CHANGED_MODE) then
      raise EOSError.CreateFmt('CoInitializeEx failed: 0x%.8x', [InitResult]);

    ConnectWebSocket;
    if FStopEvent.WaitFor(0) <> wrSignaled then
    begin
      if FReadyEvent.WaitFor(15000) <> wrSignaled then
        Fail('O servidor não confirmou a sessão Gemini Live em 15 segundos.');
    end;
    if FStopEvent.WaitFor(0) <> wrSignaled then
    begin
      FAudio.Start;
      if FStopEvent.WaitFor(0) = wrSignaled then
        FAudio.Stop
      else
      begin
        MarkActivity;
        SetState(TGeminiLiveState.Active);
      end;

      while FStopEvent.WaitFor(0) <> wrSignaled do
      begin
        while TryDequeueMessage(MessageText) do
        begin
          SendMessage(MessageText);
          if FStopEvent.WaitFor(0) = wrSignaled then
            Break;
        end;

        if InactivityExpired then
        begin
          SetState(TGeminiLiveState.Stopping);
          FStopEvent.SetEvent;
          Break;
        end;
        FSendEvent.WaitFor(50);
      end;
    end;
  except
    on E: Exception do
      Fail(E.Message);
  end;
  try
    FAudio.Stop;
  except
    // Continue closing the network session even if an audio device fails.
  end;
  CleanupWebSocket;
  if ComInitialized then
    CoUninitialize;
  if State <> TGeminiLiveState.Error then
    SetState(TGeminiLiveState.Disconnected);
end;

procedure TGeminiLiveClient.ConnectWebSocket;
var
  ConnectionUrl: TWindowsString;
  Uri: IUriRuntimeClass;
  Action: IAsyncAction;
begin
  FMessageWebSocket := TMessageWebSocket.Create;
  FMessageWebSocket.Control.MessageType := SocketMessageType.Utf8;
  FMessageWebSocket.Control.MaxMessageSize := 4 * 1024 * 1024;

  FMessageHandlerObject := TWebSocketMessageHandler.Create(Self);
  FClosedHandlerObject := TWebSocketClosedHandler.Create(Self);
  FMessageHandler := FMessageHandlerObject;
  FClosedHandler := FClosedHandlerObject;
  FMessageToken := FMessageWebSocket.add_MessageReceived(FMessageHandler);
  if not Supports(FMessageWebSocket, IWebSocket, FWebSocket) then
    raise Exception.Create('The Windows WebSocket interface is unavailable.');
  FClosedToken := FWebSocket.add_Closed(FClosedHandler);

  ConnectionUrl := TWindowsString.Create(BuildConnectionUrl);
  Uri := TUri.CreateUri(ConnectionUrl);
  Action := FWebSocket.ConnectAsync(Uri);
  TMonitor.Enter(FStateLock);
  try
    FConnectAction := Action;
  finally
    TMonitor.Exit(FStateLock);
  end;
  try
    WaitForAsync(Action);
  finally
    TMonitor.Enter(FStateLock);
    try
      FConnectAction := nil;
    finally
      TMonitor.Exit(FStateLock);
    end;
  end;

  if FStopEvent.WaitFor(0) = wrSignaled then
    Exit;
  TMonitor.Enter(FStateLock);
  try
    if FStopEvent.WaitFor(0) <> wrSignaled then
      FSocketConnected := True;
  finally
    TMonitor.Exit(FStateLock);
  end;
  FWriter := TDataWriter.CreateDataWriter(FWebSocket.OutputStream);
  FWriter.UnicodeEncoding_ := UnicodeEncoding.Utf8;
end;

procedure TGeminiLiveClient.CleanupWebSocket;
var
  CloseReason: TWindowsString;
  ShouldClose: Boolean;
begin
  if FMessageHandlerObject <> nil then
    FMessageHandlerObject.Detach;
  if FClosedHandlerObject <> nil then
    FClosedHandlerObject.Detach;

  TMonitor.Enter(FStateLock);
  try
    ShouldClose := FSocketConnected;
    FSocketConnected := False;
  finally
    TMonitor.Exit(FStateLock);
  end;

  FWriter := nil;

  if ShouldClose and (FWebSocket <> nil) then
    try
      CloseReason := TWindowsString.Create('Client session ended');
      FWebSocket.Close(1000, CloseReason);
    except
    end;
  FClosedHandler := nil;
  FMessageHandler := nil;
  FClosedHandlerObject := nil;
  FMessageHandlerObject := nil;
  FWebSocket := nil;
  FMessageWebSocket := nil;
end;

procedure TGeminiLiveClient.WaitForAsync(const AsyncOperation: IInterface);
var
  AsyncInfo: IAsyncInfo;
begin
  if not Supports(AsyncOperation, IAsyncInfo, AsyncInfo) then
    raise Exception.Create('The Windows asynchronous operation is invalid.');

  while not (AsyncInfo.Status in [AsyncStatus.Completed, AsyncStatus.Canceled,
    AsyncStatus.Error]) do
  begin
    if FStopEvent.WaitFor(10) = wrSignaled then
      AsyncInfo.Cancel;
  end;

  case AsyncInfo.Status of
    AsyncStatus.Completed:
      Exit;
    AsyncStatus.Canceled:
      if FStopEvent.WaitFor(0) <> wrSignaled then
        raise Exception.Create('The Windows asynchronous operation was cancelled.');
    AsyncStatus.Error:
      raise EOSError.CreateFmt('Windows WebSocket error: 0x%.8x',
        [AsyncInfo.ErrorCode]);
  end;
end;

procedure TGeminiLiveClient.SendMessage(const MessageText: string);
var
  Operation: IAsyncOperation_1__Cardinal;
  WindowsText: TWindowsString;
begin
  if (FWriter = nil) or (FStopEvent.WaitFor(0) = wrSignaled) then
    Exit;
  WindowsText := TWindowsString.Create(MessageText);
  FWriter.WriteString(WindowsText);
  Operation := FWriter.StoreAsync;
  WaitForAsync(Operation);
end;

procedure TGeminiLiveClient.EnqueueMessage(const MessageText: string);
begin
  TMonitor.Enter(FQueueLock);
  try
    while FSendQueue.Count >= CMaximumQueuedMessages do
      FSendQueue.Dequeue;
    FSendQueue.Enqueue(MessageText);
    FSendEvent.SetEvent;
  finally
    TMonitor.Exit(FQueueLock);
  end;
end;

function TGeminiLiveClient.TryDequeueMessage(
  out MessageText: string): Boolean;
begin
  TMonitor.Enter(FQueueLock);
  try
    Result := FSendQueue.Count > 0;
    if Result then
      MessageText := FSendQueue.Dequeue
    else
    begin
      MessageText := '';
      FSendEvent.ResetEvent;
    end;
  finally
    TMonitor.Exit(FQueueLock);
  end;
end;

procedure TGeminiLiveClient.ClearSendQueue;
begin
  TMonitor.Enter(FQueueLock);
  try
    FSendQueue.Clear;
    FSendEvent.ResetEvent;
  finally
    TMonitor.Exit(FQueueLock);
  end;
end;

procedure TGeminiLiveClient.MarkActivity(AdditionalMilliseconds: Cardinal);
begin
  TMonitor.Enter(FActivityLock);
  try
    FInactivityDeadline := GetTickCount64 + CInactivityTimeoutMs +
      AdditionalMilliseconds;
  finally
    TMonitor.Exit(FActivityLock);
  end;
end;

function TGeminiLiveClient.InactivityExpired: Boolean;
var
  Deadline: UInt64;
begin
  TMonitor.Enter(FActivityLock);
  try
    Deadline := FInactivityDeadline;
  finally
    TMonitor.Exit(FActivityLock);
  end;
  Result := (Deadline <> 0) and (GetTickCount64 >= Deadline);
end;

procedure TGeminiLiveClient.AudioInput(Sender: TObject; const Data: TBytes;
  IsVoice: Boolean);
var
  EncodedAudio: string;
  AudioMessage: TJSONObject;
begin
  if (State <> TGeminiLiveState.Active) or
    (FStopEvent.WaitFor(0) = wrSignaled) then
    Exit;

  // Skip sending microphone input while Gemini is currently speaking (playing audio)
  // to prevent acoustic echo feedback and self-interruption.
  if FAudio.QueuedPlaybackMilliseconds > 0 then
    Exit;

  if IsVoice then
    MarkActivity;

  EncodedAudio := TNetEncoding.Base64.EncodeBytesToString(Data);
  EncodedAudio := StringReplace(EncodedAudio, #13, '', [rfReplaceAll]);
  EncodedAudio := StringReplace(EncodedAudio, #10, '', [rfReplaceAll]);

  AudioMessage := TJSONObject.Create;
  try
    AudioMessage.AddPair('audio', EncodedAudio);
    EnqueueMessage(AudioMessage.ToJSON);
  finally
    AudioMessage.Free;
  end;
end;

procedure TGeminiLiveClient.HandleMessage(const MessageText: string);
var
  Json: TJSONValue;
  JsonObject: TJSONObject;
  AudioValue: TJSONValue;
  TextValue: TJSONValue;
  ErrorValue: TJSONValue;
  InterruptedValue: TJSONValue;
  ReadyValue: TJSONValue;
  TestStatusValue: TJSONValue;
  AudioData: TBytes;
  ReceivedText: string;
  RawStatusStr: string;
  NormStatusStr: string;
  CurrentTestStatus: TTestStatus;
begin
  if FStopEvent.WaitFor(0) = wrSignaled then
    Exit;
  try
    Json := TJSONObject.ParseJSONValue(MessageText);
    try
      if not (Json is TJSONObject) then
        raise Exception.Create('Invalid JSON message.');
      JsonObject := TJSONObject(Json);

      ErrorValue := JsonObject.GetValue('error');
      if ErrorValue is TJSONString then
      begin
        Fail('Erro do servidor Gemini Live: ' + TJSONString(ErrorValue).Value);
        Exit;
      end;

      ReadyValue := JsonObject.GetValue('ready');
      if (ReadyValue is TJSONBool) and TJSONBool(ReadyValue).AsBoolean then
      begin
        MarkActivity;
        FReadyEvent.SetEvent;
      end;

      TestStatusValue := JsonObject.GetValue('testStatus');
      if TestStatusValue = nil then
        TestStatusValue := JsonObject.GetValue('status');
      if TestStatusValue is TJSONString then
      begin
        RawStatusStr := TJSONString(TestStatusValue).Value;
        NormStatusStr := LowerCase(Trim(RawStatusStr));
        if (NormStatusStr = 'in_test') or (NormStatusStr = 'in test') or (NormStatusStr = 'intest') then
          FTestStatus := TTestStatus.tsInTest
        else if (NormStatusStr = 'test_ended') or (NormStatusStr = 'test ended') or (NormStatusStr = 'ended') then
          FTestStatus := TTestStatus.tsTestEnded
        else if (NormStatusStr = 'empty') or (NormStatusStr = 'none') then
          FTestStatus := TTestStatus.tsEmpty;

        if Assigned(FOnTestStatusChanged) then
        begin
          CurrentTestStatus := FTestStatus;
          TThread.Queue(nil,
            procedure
            begin
              if Assigned(FOnTestStatusChanged) then
                FOnTestStatusChanged(Self, CurrentTestStatus, RawStatusStr);
            end);
        end;
      end;

      AudioValue := JsonObject.GetValue('audio');
      if AudioValue is TJSONString then
      begin
        AudioData := TNetEncoding.Base64.DecodeStringToBytes(
          TJSONString(AudioValue).Value);
        FAudio.Play(AudioData);
        MarkActivity(FAudio.QueuedPlaybackMilliseconds);
      end;

      TextValue := JsonObject.GetValue('text');
      if TextValue is TJSONString then
      begin
        ReceivedText := TJSONString(TextValue).Value;
        if Assigned(FOnTextReceived) then
          TThread.Queue(nil,
            procedure
            begin
              if Assigned(FOnTextReceived) then
                FOnTextReceived(Self, ReceivedText);
            end);
      end;

      InterruptedValue := JsonObject.GetValue('interrupted');
      if (InterruptedValue is TJSONBool) and
        TJSONBool(InterruptedValue).AsBoolean then
      begin
        FAudio.ClearPlayback;
        MarkActivity;
      end;

      // Handle structured test protocol messages
      var MsgTypeValue: TJSONValue := JsonObject.GetValue('type');
      if MsgTypeValue is TJSONString then
      begin
        var MsgType := LowerCase(TJSONString(MsgTypeValue).Value);

        if MsgType = 'question_update' then
        begin
          var QData: TQuestionData;
          QData.HasActiveQuestion := True;
          var HasActiveVal := JsonObject.GetValue('hasActiveQuestion');
          if HasActiveVal is TJSONBool then
            QData.HasActiveQuestion := TJSONBool(HasActiveVal).AsBoolean;

          var QNumVal := JsonObject.GetValue('questionNumber');
          if QNumVal is TJSONNumber then
            QData.QuestionNumber := TJSONNumber(QNumVal).AsInt
          else
            QData.QuestionNumber := 0;

          var TotVal := JsonObject.GetValue('totalQuestions');
          if TotVal is TJSONNumber then
            QData.TotalQuestions := TJSONNumber(TotVal).AsInt
          else
            QData.TotalQuestions := 8;

          var QTextVal := JsonObject.GetValue('questionText');
          if QTextVal is TJSONString then
            QData.QuestionText := TJSONString(QTextVal).Value
          else
            QData.QuestionText := '';

          var SelAnsVal := JsonObject.GetValue('selectedAnswer');
          if SelAnsVal is TJSONString then
            QData.SelectedAnswer := TJSONString(SelAnsVal).Value
          else
            QData.SelectedAnswer := '';

          var OptsVal := JsonObject.GetValue('options');
          if OptsVal is TJSONArray then
          begin
            SetLength(QData.Options, TJSONArray(OptsVal).Count);
            for var i := 0 to TJSONArray(OptsVal).Count - 1 do
              QData.Options[i] := TJSONArray(OptsVal).Items[i].Value;
          end
          else
            SetLength(QData.Options, 0);

          if Assigned(FOnQuestionReceived) then
          begin
            var CaptureQData := QData;
            TThread.Queue(nil,
              procedure
              begin
                if Assigned(FOnQuestionReceived) then
                  FOnQuestionReceived(Self, CaptureQData);
              end);
          end;
        end
        else if MsgType = 'answer_recorded' then
        begin
          var AnsData: TAnswerRecordedData;
          var QNumVal := JsonObject.GetValue('questionNumber');
          if QNumVal is TJSONNumber then
            AnsData.QuestionNumber := TJSONNumber(QNumVal).AsInt
          else
            AnsData.QuestionNumber := 0;

          var SelOptVal := JsonObject.GetValue('selectedOption');
          if SelOptVal is TJSONString then
            AnsData.SelectedOption := TJSONString(SelOptVal).Value
          else
            AnsData.SelectedOption := '';

          var IsCorrVal := JsonObject.GetValue('isCorrect');
          if IsCorrVal is TJSONBool then
            AnsData.IsCorrect := TJSONBool(IsCorrVal).AsBoolean
          else
            AnsData.IsCorrect := False;

          var CorrAnsVal := JsonObject.GetValue('correctAnswer');
          if CorrAnsVal is TJSONString then
            AnsData.CorrectAnswer := TJSONString(CorrAnsVal).Value
          else
            AnsData.CorrectAnswer := '';

          var AnsCntVal := JsonObject.GetValue('answeredCount');
          if AnsCntVal is TJSONNumber then
            AnsData.AnsweredCount := TJSONNumber(AnsCntVal).AsInt
          else
            AnsData.AnsweredCount := 0;

          var TotVal := JsonObject.GetValue('totalQuestions');
          if TotVal is TJSONNumber then
            AnsData.TotalQuestions := TJSONNumber(TotVal).AsInt
          else
            AnsData.TotalQuestions := 8;

          if Assigned(FOnAnswerRecorded) then
          begin
            var CaptureAnsData := AnsData;
            TThread.Queue(nil,
              procedure
              begin
                if Assigned(FOnAnswerRecorded) then
                  FOnAnswerRecorded(Self, CaptureAnsData);
              end);
          end;
        end
        else if (MsgType = 'results_update') or (MsgType = 'test_ended') then
        begin
          var ResData: TResultsSummaryData;
          var TotVal := JsonObject.GetValue('totalQuestions');
          if TotVal is TJSONNumber then
            ResData.TotalQuestions := TJSONNumber(TotVal).AsInt
          else
            ResData.TotalQuestions := 8;

          var AnsCntVal := JsonObject.GetValue('answeredCount');
          if AnsCntVal is TJSONNumber then
            ResData.AnsweredCount := TJSONNumber(AnsCntVal).AsInt
          else
            ResData.AnsweredCount := 0;

          var CorrCntVal := JsonObject.GetValue('correctCount');
          if CorrCntVal is TJSONNumber then
            ResData.CorrectCount := TJSONNumber(CorrCntVal).AsInt
          else
            ResData.CorrectCount := 0;

          var IncorrCntVal := JsonObject.GetValue('incorrectCount');
          if IncorrCntVal is TJSONNumber then
            ResData.IncorrectCount := TJSONNumber(IncorrCntVal).AsInt
          else
            ResData.IncorrectCount := 0;

          var UnansCntVal := JsonObject.GetValue('unansweredCount');
          if UnansCntVal is TJSONNumber then
            ResData.UnansweredCount := TJSONNumber(UnansCntVal).AsInt
          else
            ResData.UnansweredCount := 0;

          var ScoreVal := JsonObject.GetValue('scorePercentage');
          if ScoreVal is TJSONNumber then
            ResData.ScorePercentage := TJSONNumber(ScoreVal).AsInt
          else
            ResData.ScorePercentage := 0;

          var SumMsgVal := JsonObject.GetValue('summaryMessage');
          if SumMsgVal = nil then
            SumMsgVal := JsonObject.GetValue('message');
          if SumMsgVal is TJSONString then
            ResData.SummaryMessage := TJSONString(SumMsgVal).Value
          else
            ResData.SummaryMessage := '';

          if Assigned(FOnResultsReceived) then
          begin
            var CaptureResData := ResData;
            TThread.Queue(nil,
              procedure
              begin
                if Assigned(FOnResultsReceived) then
                  FOnResultsReceived(Self, CaptureResData);
              end);
          end;
        end
        else if MsgType = 'test_report_image' then
        begin
          var RepData: TTestReportImageData;
          var SessVal := JsonObject.GetValue('sessionId');
          if SessVal is TJSONString then
            RepData.SessionId := TJSONString(SessVal).Value
          else
            RepData.SessionId := '';

          var ScoreVal := JsonObject.GetValue('scorePercentage');
          if ScoreVal is TJSONNumber then
            RepData.ScorePercentage := TJSONNumber(ScoreVal).AsInt
          else
            RepData.ScorePercentage := 0;

          var StatVal := JsonObject.GetValue('status');
          if StatVal is TJSONString then
            RepData.Status := TJSONString(StatVal).Value
          else
            RepData.Status := '';

          var SumVal := JsonObject.GetValue('summaryMessage');
          if SumVal is TJSONString then
            RepData.SummaryMessage := TJSONString(SumVal).Value
          else
            RepData.SummaryMessage := '';

          var ImgVal := JsonObject.GetValue('imageBase64');
          if ImgVal is TJSONString then
            RepData.ImageBase64 := TJSONString(ImgVal).Value
          else
            RepData.ImageBase64 := '';

          if Assigned(FOnTestReportImage) then
          begin
            var CaptureRepData := RepData;
            TThread.Queue(nil,
              procedure
              begin
                if Assigned(FOnTestReportImage) then
                  FOnTestReportImage(Self, CaptureRepData);
              end);
          end;
        end;
      end;
    finally
      Json.Free;
    end;
  except
    on E: Exception do
      Fail('Mensagem inválida recebida do servidor: ' + E.Message);
  end;
end;

procedure TGeminiLiveClient.RecordAnswer(const SelectedOption: string; QuestionNumber: Integer);
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('type', 'record_answer');
    Obj.AddPair('selectedOption', SelectedOption);
    if QuestionNumber > 0 then
      Obj.AddPair('questionNumber', TJSONNumber.Create(QuestionNumber));
    EnqueueMessage(Obj.ToJSON);
  finally
    Obj.Free;
  end;
end;

procedure TGeminiLiveClient.RequestNextQuestion;
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('type', 'next_question');
    EnqueueMessage(Obj.ToJSON);
  finally
    Obj.Free;
  end;
end;

procedure TGeminiLiveClient.RequestExplanation(QuestionNumber: Integer);
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('type', 'explain_question');
    if QuestionNumber > 0 then
      Obj.AddPair('questionNumber', TJSONNumber.Create(QuestionNumber));
    EnqueueMessage(Obj.ToJSON);
  finally
    Obj.Free;
  end;
end;

procedure TGeminiLiveClient.RequestResults;
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('type', 'get_results');
    EnqueueMessage(Obj.ToJSON);
  finally
    Obj.Free;
  end;
end;

procedure TGeminiLiveClient.RequestEndTest;
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('type', 'end_test');
    EnqueueMessage(Obj.ToJSON);
  finally
    Obj.Free;
  end;
end;

procedure TGeminiLiveClient.HandleWebSocketClosed(Code: Word;
  const Reason: string);
var
  Detail: string;
begin
  TMonitor.Enter(FStateLock);
  try
    FSocketConnected := False;
  finally
    TMonitor.Exit(FStateLock);
  end;
  if FStopEvent.WaitFor(0) = wrSignaled then
    Exit;
  Detail := Format('A conexão foi encerrada pelo servidor (código %d)', [Code]);
  if Reason <> '' then
    Detail := Detail + ': ' + Reason;
  Fail(Detail);
end;

end.
