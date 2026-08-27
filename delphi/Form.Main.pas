unit Form.Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.NetEncoding, System.StrUtils,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.StdCtrls, FMX.Controls.Presentation, FMX.Edit, FMX.Memo,
  FMX.Memo.Types, FMX.ScrollBox, FMX.ListBox, FMX.Objects, FMX.Layouts,
  Gemini.Live.Client;

type
  TFormMode = (None, Conversation, Translation);

  TForm1 = class(TForm)
    rectBackground: TRectangle;
    pnlTopBar: TRectangle;
    lblAppTitle: TLabel;
    lblAppSubtitle: TLabel;
    cbLanguage: TComboBox;
    lblTestStatus: TLabel;
    btnGeminiLive: TButton;
    pnlBottomBar: TRectangle;
    lblLiveTranscriptTitle: TLabel;
    lblGeminiStatus: TEdit;
    memTranslation: TMemo;
    pnlContent: TLayout;
    layoutWaiting: TLayout;
    rectHero: TRectangle;
    lblHeroTitle: TLabel;
    lblHeroDesc: TLabel;
    rectHeroBadge: TRectangle;
    lblHeroBadge1: TLabel;
    lblHeroBadge2: TLabel;
    lblHeroBadge3: TLabel;
    btnLiveTranslation: TButton;
    layoutInTest: TLayout;
    pnlTestHeader: TLayout;
    lblQuestionProgress: TLabel;
    pbProgress: TProgressBar;
    rectQuestionCard: TRectangle;
    lblQuestionNumBadge: TLabel;
    lblQuestionText: TLabel;
    layoutOptions: TLayout;
    btnOptionA: TButton;
    btnOptionB: TButton;
    btnOptionC: TButton;
    btnOptionD: TButton;
    layoutTestActions: TLayout;
    btnNextQuestion: TButton;
    btnExplain: TButton;
    btnGetResults: TButton;
    btnEndTestEarly: TButton;
    layoutResults: TLayout;
    rectScoreSummary: TRectangle;
    lblScoreStatus: TLabel;
    lblScoreDetails: TLabel;
    btnRestartTest: TButton;
    rectImageCard: TRectangle;
    lblReportGenerating: TLabel;
    imgReport: TImage;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure cbLanguageChange(Sender: TObject);
    procedure btnGeminiLiveClick(Sender: TObject);
    procedure btnLiveTranslationClick(Sender: TObject);
    procedure btnOptionClick(Sender: TObject);
    procedure btnNextQuestionClick(Sender: TObject);
    procedure btnExplainClick(Sender: TObject);
    procedure btnGetResultsClick(Sender: TObject);
    procedure btnEndTestEarlyClick(Sender: TObject);
    procedure btnRestartTestClick(Sender: TObject);
  private
    FGeminiClient: TGeminiLiveClient;
    FActiveMode: TFormMode;
    FCurrentLang: string;
    FCurrentQuestionNum: Integer;
    FTotalQuestions: Integer;
    FLastQuestionData: TQuestionData;
    FLastResultsData: TResultsSummaryData;
    FHasResults: Boolean;
    FSelectedOption: string;
    procedure GeminiStateChanged(Sender: TObject; State: TGeminiLiveState);
    procedure GeminiTestStatusChanged(Sender: TObject; Status: TTestStatus;
      const StatusText: string);
    procedure GeminiError(Sender: TObject; const ErrorMessage: string);
    procedure GeminiTextReceived(Sender: TObject; const Text: string);
    procedure GeminiQuestionReceived(Sender: TObject; const Question: TQuestionData);
    procedure GeminiAnswerRecorded(Sender: TObject; const AnswerData: TAnswerRecordedData);
    procedure GeminiResultsReceived(Sender: TObject; const Results: TResultsSummaryData);
    procedure GeminiReportImageReceived(Sender: TObject; const ReportImage: TTestReportImageData);
    procedure SetUIState(const AState: string); // 'waiting', 'intest', 'results'
    procedure UpdateGeminiControls(State: TGeminiLiveState);
    procedure ResetOptionButtons;
    function GetSelectedLanguage: string;
    function LocalizedStatusDisplay(Status: TTestStatus): string;
    procedure ApplyLanguage(const ALang: string);
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

const
  CDefaultGeminiLiveUrl = 'ws://127.0.0.1:3000/live';
  CDefaultContextEn = 'Delphi Certification Simulation Game with Gemini Live. Lead an interactive and educational test game with the candidate.';
  CDefaultContextPt = 'Jogo de Simulação de Certificação Delphi com Gemini Live. Conduza o jogo interativo e educativo com o jogador.';

procedure TForm1.FormCreate(Sender: TObject);
var
  ServerUrl: string;
begin
  FActiveMode := TFormMode.None;
  FCurrentQuestionNum := 0;
  FTotalQuestions := 8;
  FHasResults := False;
  FSelectedOption := '';
  FCurrentLang := 'en-US';

  ServerUrl := GetEnvironmentVariable('GEMINI_LIVE_WS_URL');
  if ServerUrl = '' then
    ServerUrl := CDefaultGeminiLiveUrl;

  if cbLanguage.Items.Count = 0 then
  begin
    cbLanguage.Items.Add('en-US');
    cbLanguage.Items.Add('pt-BR');
  end;
  cbLanguage.ItemIndex := 0;

  FGeminiClient := TGeminiLiveClient.Create(ServerUrl);
  FGeminiClient.OnStateChanged := GeminiStateChanged;
  FGeminiClient.OnTestStatusChanged := GeminiTestStatusChanged;
  FGeminiClient.OnError := GeminiError;
  FGeminiClient.OnTextReceived := GeminiTextReceived;
  FGeminiClient.OnQuestionReceived := GeminiQuestionReceived;
  FGeminiClient.OnAnswerRecorded := GeminiAnswerRecorded;
  FGeminiClient.OnResultsReceived := GeminiResultsReceived;
  FGeminiClient.OnTestReportImage := GeminiReportImageReceived;

  SetUIState('waiting');
  ApplyLanguage('en-US');
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  if FGeminiClient <> nil then
  begin
    FGeminiClient.OnStateChanged := nil;
    FGeminiClient.OnTestStatusChanged := nil;
    FGeminiClient.OnError := nil;
    FGeminiClient.OnTextReceived := nil;
    FGeminiClient.OnQuestionReceived := nil;
    FGeminiClient.OnAnswerRecorded := nil;
    FGeminiClient.OnResultsReceived := nil;
    FGeminiClient.OnTestReportImage := nil;
    FreeAndNil(FGeminiClient);
  end;
end;

function TForm1.GetSelectedLanguage: string;
begin
  Result := 'en-US';
  if (cbLanguage <> nil) and (cbLanguage.Selected <> nil) then
    Result := cbLanguage.Selected.Text
  else if (cbLanguage <> nil) and (cbLanguage.ItemIndex >= 0) then
    Result := cbLanguage.Items[cbLanguage.ItemIndex];
end;

function TForm1.LocalizedStatusDisplay(Status: TTestStatus): string;
begin
  if FCurrentLang = 'pt-BR' then
  begin
    case Status of
      TTestStatus.tsEmpty: Result := 'Inativo';
      TTestStatus.tsInTest: Result := 'Em Simulação';
      TTestStatus.tsTestEnded: Result := 'Simulação Finalizada';
    else
      Result := 'Desconhecido';
    end;
  end
  else
  begin
    case Status of
      TTestStatus.tsEmpty: Result := 'Inactive';
      TTestStatus.tsInTest: Result := 'In Simulation';
      TTestStatus.tsTestEnded: Result := 'Simulation Finished';
    else
      Result := 'Unknown';
    end;
  end;
end;

procedure TForm1.ApplyLanguage(const ALang: string);
var
  ProgressPct: Integer;
  IsPt: Boolean;
begin
  FCurrentLang := ALang;
  IsPt := (ALang = 'pt-BR');

  if IsPt then
  begin
    Caption := 'Simulação de Certificação Delphi - Gemini Live Voice AI';
    lblAppTitle.Text := 'SIMULAÇÃO DE CERTIFICAÇÃO DELPHI';
    lblAppSubtitle.Text := 'IA por Voz Gemini Live & Jogo Falado Interativo';
    lblLiveTranscriptTitle.Text := 'Transcrição / Voz Gemini Live:';

    lblHeroTitle.Text := 'Simulação de Certificação Delphi com IA';
    lblHeroDesc.Text := 'Pratique seus conhecimentos em Object Pascal, RTL, Arquitetura de Memória, ' +
      'VCL/FMX e Banco de Dados. Interaja conversando por voz ou clicando nas alternativas na tela.';
    lblHeroBadge1.Text := '• 8 Questões Técnicas de Múltipla Escolha';
    lblHeroBadge2.Text := '• Explicações didáticas e feedback falado em tempo real';
    lblHeroBadge3.Text := '• Certificado e Relatório de Desempenho Visual com IA';
    btnLiveTranslation.Text := 'Modo Tradutor Simultâneo';

    btnNextQuestion.Text := 'Próxima Questão >';
    btnExplain.Text := 'Explicar Questão';
    btnGetResults.Text := 'Ver Placar';
    btnEndTestEarly.Text := 'Encerrar Simulação';

    btnRestartTest.Text := 'Nova Simulação';
    lblReportGenerating.Text := 'Gerando Certificado e Relatório Visual com IA...';

    if FCurrentQuestionNum > 0 then
    begin
      if FTotalQuestions > 0 then
        ProgressPct := Round((FCurrentQuestionNum / FTotalQuestions) * 100)
      else
        ProgressPct := 0;
      lblQuestionProgress.Text := Format('Questão %d de %d (%d%%)', [FCurrentQuestionNum, FTotalQuestions, ProgressPct]);
      lblQuestionNumBadge.Text := Format('QUESTÃO %d', [FCurrentQuestionNum]);
    end
    else
    begin
      lblQuestionProgress.Text := 'Questão 1 de 8 (12%)';
      lblQuestionNumBadge.Text := 'QUESTÃO 1';
      lblQuestionText.Text := 'Carregando questão...';
    end;

    if FHasResults then
    begin
      if FLastResultsData.ScorePercentage >= 70 then
      begin
        lblScoreStatus.Text := Format('APROVADO NA SIMULAÇÃO! (%d%%)', [FLastResultsData.ScorePercentage]);
        lblScoreStatus.TextSettings.FontColor := $FF059669;
      end
      else
      begin
        lblScoreStatus.Text := Format('SIMULAÇÃO CONCLUÍDA - APROVEITAMENTO: %d%%', [FLastResultsData.ScorePercentage]);
        lblScoreStatus.TextSettings.FontColor := $FFD97706;
      end;
      lblScoreDetails.Text := Format('Total: %d | Respondidas: %d | Acertos: %d | Erros: %d | Não respondidas: %d',
        [FLastResultsData.TotalQuestions, FLastResultsData.AnsweredCount, FLastResultsData.CorrectCount,
         FLastResultsData.IncorrectCount, FLastResultsData.UnansweredCount]);
    end
    else
    begin
      lblScoreStatus.Text := 'SIMULAÇÃO CONCLUÍDA';
      lblScoreDetails.Text := 'Total: 8 | Acertos: 0 | Erros: 0 | Aproveitamento: 0%';
    end;
  end
  else
  begin
    Caption := 'Delphi Certification Simulator - Gemini Live Voice AI';
    lblAppTitle.Text := 'DELPHI CERTIFICATION SIMULATOR';
    lblAppSubtitle.Text := 'Gemini Live Voice AI & Interactive Spoken Game';
    lblLiveTranscriptTitle.Text := 'Live Transcript / Gemini Live Voice:';

    lblHeroTitle.Text := 'Delphi Certification Simulation with AI';
    lblHeroDesc.Text := 'Practice your knowledge in Object Pascal, RTL, Memory Architecture, ' +
      'VCL/FMX, and Database. Interact by voice conversation or by clicking the options on screen.';
    lblHeroBadge1.Text := '• 8 Technical Multiple-Choice Questions';
    lblHeroBadge2.Text := '• Real-time spoken explanations and instant feedback';
    lblHeroBadge3.Text := '• Visual Performance Certificate & Report generated by AI';
    btnLiveTranslation.Text := 'Simultaneous Translator Mode';

    btnNextQuestion.Text := 'Next Question >';
    btnExplain.Text := 'Explain Question';
    btnGetResults.Text := 'View Score';
    btnEndTestEarly.Text := 'End Simulation';

    btnRestartTest.Text := 'New Simulation';
    lblReportGenerating.Text := 'Generating Visual Performance Certificate with AI...';

    if FCurrentQuestionNum > 0 then
    begin
      if FTotalQuestions > 0 then
        ProgressPct := Round((FCurrentQuestionNum / FTotalQuestions) * 100)
      else
        ProgressPct := 0;
      lblQuestionProgress.Text := Format('Question %d of %d (%d%%)', [FCurrentQuestionNum, FTotalQuestions, ProgressPct]);
      lblQuestionNumBadge.Text := Format('QUESTION %d', [FCurrentQuestionNum]);
    end
    else
    begin
      lblQuestionProgress.Text := 'Question 1 of 8 (12%)';
      lblQuestionNumBadge.Text := 'QUESTION 1';
      lblQuestionText.Text := 'Loading question...';
    end;

    if FHasResults then
    begin
      if FLastResultsData.ScorePercentage >= 70 then
      begin
        lblScoreStatus.Text := Format('PASSED IN SIMULATION! (%d%%)', [FLastResultsData.ScorePercentage]);
        lblScoreStatus.TextSettings.FontColor := $FF059669;
      end
      else
      begin
        lblScoreStatus.Text := Format('SIMULATION COMPLETED - SCORE: %d%%', [FLastResultsData.ScorePercentage]);
        lblScoreStatus.TextSettings.FontColor := $FFD97706;
      end;
      lblScoreDetails.Text := Format('Total: %d | Answered: %d | Correct: %d | Incorrect: %d | Unanswered: %d',
        [FLastResultsData.TotalQuestions, FLastResultsData.AnsweredCount, FLastResultsData.CorrectCount,
         FLastResultsData.IncorrectCount, FLastResultsData.UnansweredCount]);
    end
    else
    begin
      lblScoreStatus.Text := 'SIMULATION COMPLETED';
      lblScoreDetails.Text := 'Total: 8 | Correct: 0 | Incorrect: 0 | Score: 0%';
    end;
  end;

  if FGeminiClient <> nil then
    UpdateGeminiControls(FGeminiClient.State);
end;

procedure TForm1.cbLanguageChange(Sender: TObject);
begin
  ApplyLanguage(GetSelectedLanguage);
end;

procedure TForm1.SetUIState(const AState: string);
begin
  if AState = 'waiting' then
  begin
    layoutWaiting.Visible := True;
    layoutInTest.Visible := False;
    layoutResults.Visible := False;
  end
  else if AState = 'intest' then
  begin
    layoutWaiting.Visible := False;
    layoutInTest.Visible := True;
    layoutResults.Visible := False;
  end
  else if AState = 'results' then
  begin
    layoutWaiting.Visible := False;
    layoutInTest.Visible := False;
    layoutResults.Visible := True;
  end;
end;

procedure TForm1.ResetOptionButtons;
var
  OptLabel: string;
begin
  if FCurrentLang = 'pt-BR' then
    OptLabel := 'Opção'
  else
    OptLabel := 'Option';

  btnOptionA.Text := Format('a) %s A', [OptLabel]);
  btnOptionB.Text := Format('b) %s B', [OptLabel]);
  btnOptionC.Text := Format('c) %s C', [OptLabel]);
  btnOptionD.Text := Format('d) %s D', [OptLabel]);
  btnOptionA.Enabled := True;
  btnOptionB.Enabled := True;
  btnOptionC.Enabled := True;
  btnOptionD.Enabled := True;
  FSelectedOption := '';
end;

procedure TForm1.btnGeminiLiveClick(Sender: TObject);
var
  SelectedLang: string;
  Ctx: string;
begin
  if FGeminiClient = nil then
    Exit;

  case FGeminiClient.State of
    TGeminiLiveState.Active:
      FGeminiClient.Stop;
    TGeminiLiveState.Disconnected,
    TGeminiLiveState.Error:
      begin
        SelectedLang := GetSelectedLanguage;
        FCurrentLang := SelectedLang;

        if SelectedLang = 'pt-BR' then
          Ctx := CDefaultContextPt
        else
          Ctx := CDefaultContextEn;

        FActiveMode := TFormMode.Conversation;
        memTranslation.Lines.Clear;
        ResetOptionButtons;
        FGeminiClient.Start(Ctx, SelectedLang);
      end;
  end;
end;

procedure TForm1.btnLiveTranslationClick(Sender: TObject);
const
  CTranslationContext = 'Act as a high-level simultaneous interpreter. ' +
    'Immediately translate whatever the user says into English (or Portuguese if English is spoken). ' +
    'Respond ONLY with the natural translation, without commentary or introductions.';
begin
  if FGeminiClient = nil then
    Exit;

  case FGeminiClient.State of
    TGeminiLiveState.Active:
      FGeminiClient.Stop;
    TGeminiLiveState.Disconnected,
    TGeminiLiveState.Error:
      begin
        memTranslation.Lines.Clear;
        FActiveMode := TFormMode.Translation;
        FGeminiClient.Start(CTranslationContext, GetSelectedLanguage);
      end;
  end;
end;

procedure TForm1.btnOptionClick(Sender: TObject);
var
  OptionKey: string;
  SelectedMsg: string;
begin
  if FGeminiClient = nil then
    Exit;

  if Sender = btnOptionA then
    OptionKey := 'A'
  else if Sender = btnOptionB then
    OptionKey := 'B'
  else if Sender = btnOptionC then
    OptionKey := 'C'
  else if Sender = btnOptionD then
    OptionKey := 'D'
  else
    Exit;

  FSelectedOption := OptionKey;
  FGeminiClient.RecordAnswer(OptionKey, FCurrentQuestionNum);

  if FCurrentLang = 'pt-BR' then
    SelectedMsg := '>>> Resposta selecionada na tela: Opção ' + OptionKey
  else
    SelectedMsg := '>>> Selected answer on screen: Option ' + OptionKey;

  memTranslation.Lines.Add(SelectedMsg);
  memTranslation.GoToTextEnd;
end;

procedure TForm1.btnNextQuestionClick(Sender: TObject);
begin
  if FGeminiClient <> nil then
  begin
    FGeminiClient.RequestNextQuestion;
    if FCurrentLang = 'pt-BR' then
      memTranslation.Lines.Add('>>> Solicitando próxima questão...')
    else
      memTranslation.Lines.Add('>>> Requesting next question...');
    memTranslation.GoToTextEnd;
  end;
end;

procedure TForm1.btnExplainClick(Sender: TObject);
begin
  if FGeminiClient <> nil then
  begin
    FGeminiClient.RequestExplanation(FCurrentQuestionNum);
    if FCurrentLang = 'pt-BR' then
      memTranslation.Lines.Add('>>> Solicitando explicação didática...')
    else
      memTranslation.Lines.Add('>>> Requesting detailed explanation...');
    memTranslation.GoToTextEnd;
  end;
end;

procedure TForm1.btnGetResultsClick(Sender: TObject);
begin
  if FGeminiClient <> nil then
  begin
    FGeminiClient.RequestResults;
    if FCurrentLang = 'pt-BR' then
      memTranslation.Lines.Add('>>> Solicitando placar atual...')
    else
      memTranslation.Lines.Add('>>> Requesting current score...');
    memTranslation.GoToTextEnd;
  end;
end;

procedure TForm1.btnEndTestEarlyClick(Sender: TObject);
begin
  if FGeminiClient <> nil then
  begin
    FGeminiClient.RequestEndTest;
    if FCurrentLang = 'pt-BR' then
      memTranslation.Lines.Add('>>> Encerrando simulação antecipadamente...')
    else
      memTranslation.Lines.Add('>>> Ending simulation early...');
    memTranslation.GoToTextEnd;
  end;
end;

procedure TForm1.btnRestartTestClick(Sender: TObject);
begin
  FHasResults := False;
  SetUIState('waiting');
  ResetOptionButtons;
  imgReport.Bitmap.SetSize(0, 0);
  lblReportGenerating.Visible := True;
  if FCurrentLang = 'pt-BR' then
    lblReportGenerating.Text := 'Gerando Certificado e Relatório Visual com IA...'
  else
    lblReportGenerating.Text := 'Generating Visual Performance Certificate with AI...';
end;

procedure TForm1.GeminiStateChanged(Sender: TObject; State: TGeminiLiveState);
begin
  UpdateGeminiControls(State);
end;

procedure TForm1.GeminiTestStatusChanged(Sender: TObject; Status: TTestStatus;
  const StatusText: string);
begin
  if FGeminiClient <> nil then
    lblTestStatus.Text := 'Status: ' + LocalizedStatusDisplay(Status);

  if (Status = TTestStatus.tsInTest) and (layoutWaiting.Visible) then
    SetUIState('intest')
  else if (Status = TTestStatus.tsTestEnded) then
    SetUIState('results');
end;

procedure TForm1.GeminiError(Sender: TObject; const ErrorMessage: string);
begin
  lblGeminiStatus.Text := ErrorMessage;
end;

procedure TForm1.GeminiTextReceived(Sender: TObject; const Text: string);
begin
  memTranslation.Lines.Text := memTranslation.Lines.Text + Text;
  memTranslation.GoToTextEnd;
end;

procedure TForm1.GeminiQuestionReceived(Sender: TObject; const Question: TQuestionData);
var
  ProgressPct: Integer;
begin
  SetUIState('intest');
  FLastQuestionData := Question;
  FCurrentQuestionNum := Question.QuestionNumber;
  FTotalQuestions := Question.TotalQuestions;
  ResetOptionButtons;

  if Question.TotalQuestions > 0 then
    ProgressPct := Round((Question.QuestionNumber / Question.TotalQuestions) * 100)
  else
    ProgressPct := 0;

  if FCurrentLang = 'pt-BR' then
  begin
    lblQuestionProgress.Text := Format('Questão %d de %d (%d%%)', [Question.QuestionNumber, Question.TotalQuestions, ProgressPct]);
    lblQuestionNumBadge.Text := Format('QUESTÃO %d', [Question.QuestionNumber]);
  end
  else
  begin
    lblQuestionProgress.Text := Format('Question %d of %d (%d%%)', [Question.QuestionNumber, Question.TotalQuestions, ProgressPct]);
    lblQuestionNumBadge.Text := Format('QUESTION %d', [Question.QuestionNumber]);
  end;

  pbProgress.Max := Question.TotalQuestions;
  pbProgress.Value := Question.QuestionNumber;
  lblQuestionText.Text := Question.QuestionText;

  if Length(Question.Options) > 0 then
    btnOptionA.Text := Question.Options[0]
  else
    btnOptionA.Text := 'a)';

  if Length(Question.Options) > 1 then
    btnOptionB.Text := Question.Options[1]
  else
    btnOptionB.Text := 'b)';

  if Length(Question.Options) > 2 then
    btnOptionC.Text := Question.Options[2]
  else
    btnOptionC.Text := 'c)';

  if Length(Question.Options) > 3 then
    btnOptionD.Text := Question.Options[3]
  else
    btnOptionD.Text := 'd)';
end;

procedure TForm1.GeminiAnswerRecorded(Sender: TObject; const AnswerData: TAnswerRecordedData);
var
  SelUpper: string;
  TagText: string;
begin
  if FCurrentLang = 'pt-BR' then
    TagText := '  [SELECIONADA]'
  else
    TagText := '  [SELECTED]';

  SelUpper := UpperCase(Trim(AnswerData.SelectedOption));
  if (Pos('A', SelUpper) > 0) or (Pos('1', SelUpper) > 0) then
    btnOptionA.Text := btnOptionA.Text + TagText
  else if (Pos('B', SelUpper) > 0) or (Pos('2', SelUpper) > 0) then
    btnOptionB.Text := btnOptionB.Text + TagText
  else if (Pos('C', SelUpper) > 0) or (Pos('3', SelUpper) > 0) then
    btnOptionC.Text := btnOptionC.Text + TagText
  else if (Pos('D', SelUpper) > 0) or (Pos('4', SelUpper) > 0) then
    btnOptionD.Text := btnOptionD.Text + TagText;
end;

procedure TForm1.GeminiResultsReceived(Sender: TObject; const Results: TResultsSummaryData);
begin
  FLastResultsData := Results;
  FHasResults := True;

  if FCurrentLang = 'pt-BR' then
  begin
    if Results.ScorePercentage >= 70 then
    begin
      lblScoreStatus.Text := Format('APROVADO NA SIMULAÇÃO! (%d%%)', [Results.ScorePercentage]);
      lblScoreStatus.TextSettings.FontColor := $FF059669;
    end
    else
    begin
      lblScoreStatus.Text := Format('SIMULAÇÃO CONCLUÍDA - APROVEITAMENTO: %d%%', [Results.ScorePercentage]);
      lblScoreStatus.TextSettings.FontColor := $FFD97706;
    end;

    lblScoreDetails.Text := Format('Total: %d | Respondidas: %d | Acertos: %d | Erros: %d | Não respondidas: %d',
      [Results.TotalQuestions, Results.AnsweredCount, Results.CorrectCount, Results.IncorrectCount, Results.UnansweredCount]);
  end
  else
  begin
    if Results.ScorePercentage >= 70 then
    begin
      lblScoreStatus.Text := Format('PASSED IN SIMULATION! (%d%%)', [Results.ScorePercentage]);
      lblScoreStatus.TextSettings.FontColor := $FF059669;
    end
    else
    begin
      lblScoreStatus.Text := Format('SIMULATION COMPLETED - SCORE: %d%%', [Results.ScorePercentage]);
      lblScoreStatus.TextSettings.FontColor := $FFD97706;
    end;

    lblScoreDetails.Text := Format('Total: %d | Answered: %d | Correct: %d | Incorrect: %d | Unanswered: %d',
      [Results.TotalQuestions, Results.AnsweredCount, Results.CorrectCount, Results.IncorrectCount, Results.UnansweredCount]);
  end;

  SetUIState('results');
end;

procedure TForm1.GeminiReportImageReceived(Sender: TObject; const ReportImage: TTestReportImageData);
var
  CleanBase64: string;
  ImgBytes: TBytes;
  Stream: TBytesStream;
  IsValidRaster: Boolean;
begin
  SetUIState('results');
  if ReportImage.ImageBase64 <> '' then
  begin
    try
      CleanBase64 := ReportImage.ImageBase64.Trim;
      if Pos('base64,', CleanBase64) > 0 then
        CleanBase64 := Copy(CleanBase64, Pos('base64,', CleanBase64) + 7, Length(CleanBase64));

      CleanBase64 := CleanBase64.Replace(#13, '').Replace(#10, '').Replace(' ', '');
      ImgBytes := TNetEncoding.Base64.DecodeStringToBytes(CleanBase64);

      if Length(ImgBytes) >= 4 then
      begin
        // Check for valid raster image magic headers (BMP, PNG, JPG, GIF)
        IsValidRaster :=
          ((ImgBytes[0] = $42) and (ImgBytes[1] = $4D)) or // BMP 'BM'
          ((ImgBytes[0] = $89) and (ImgBytes[1] = $50) and (ImgBytes[2] = $4E) and (ImgBytes[3] = $47)) or // PNG
          ((ImgBytes[0] = $FF) and (ImgBytes[1] = $D8)) or // JPEG
          ((ImgBytes[0] = $47) and (ImgBytes[1] = $49) and (ImgBytes[2] = $46)); // GIF

        if IsValidRaster then
        begin
          Stream := TBytesStream.Create(ImgBytes);
          try
            Stream.Position := 0;
            imgReport.Bitmap.LoadFromStream(Stream);
            lblReportGenerating.Visible := False;
          finally
            Stream.Free;
          end;
        end
        else
        begin
          if FCurrentLang = 'pt-BR' then
            lblReportGenerating.Text := 'Relatório de Desempenho gerado (arquivo salvo em logs/)'
          else
            lblReportGenerating.Text := 'Performance Report generated (file saved in logs/)';
          lblReportGenerating.Visible := True;
        end;
      end;
    except
      on E: Exception do
      begin
        if FCurrentLang = 'pt-BR' then
          lblReportGenerating.Text := 'Relatório de Desempenho salvo nos logs'
        else
          lblReportGenerating.Text := 'Performance Report saved in logs';
        lblReportGenerating.Visible := True;
      end;
    end;
  end;
end;

procedure TForm1.UpdateGeminiControls(State: TGeminiLiveState);
var
  IsPt: Boolean;
begin
  IsPt := (FCurrentLang = 'pt-BR');
  lblGeminiStatus.Text := GeminiLiveStateText(State);

  if FGeminiClient <> nil then
    lblTestStatus.Text := 'Status: ' + LocalizedStatusDisplay(FGeminiClient.TestStatus);

  case State of
    TGeminiLiveState.Disconnected:
      begin
        FActiveMode := TFormMode.None;
        if IsPt then
        begin
          btnGeminiLive.Text := 'Iniciar Simulação';
          btnLiveTranslation.Text := 'Modo Tradutor Simultâneo';
        end
        else
        begin
          btnGeminiLive.Text := 'Start Simulation';
          btnLiveTranslation.Text := 'Simultaneous Translator Mode';
        end;
        btnGeminiLive.Enabled := True;
        btnLiveTranslation.Enabled := True;
        if cbLanguage <> nil then
          cbLanguage.Enabled := True;
      end;
    TGeminiLiveState.Connecting:
      begin
        btnGeminiLive.Enabled := False;
        btnLiveTranslation.Enabled := False;
        if cbLanguage <> nil then
          cbLanguage.Enabled := False;

        if FActiveMode = TFormMode.Translation then
        begin
          if IsPt then
            btnLiveTranslation.Text := 'Conectando Tradutor...'
          else
            btnLiveTranslation.Text := 'Connecting Translator...';
          btnGeminiLive.Text := ifthen(IsPt, 'Iniciar Simulação', 'Start Simulation');
        end
        else
        begin
          if IsPt then
            btnGeminiLive.Text := 'Conectando Simulação...'
          else
            btnGeminiLive.Text := 'Connecting Simulation...';
          btnLiveTranslation.Text := ifthen(IsPt, 'Modo Tradutor Simultâneo', 'Simultaneous Translator Mode');
        end;
      end;
    TGeminiLiveState.Active:
      begin
        if cbLanguage <> nil then
          cbLanguage.Enabled := False;

        if FActiveMode = TFormMode.Translation then
        begin
          btnLiveTranslation.Text := ifthen(IsPt, 'Parar Tradutor', 'Stop Translator');
          btnLiveTranslation.Enabled := True;
          btnGeminiLive.Enabled := False;
        end
        else
        begin
          btnGeminiLive.Text := ifthen(IsPt, 'Encerrar Simulação', 'End Simulation');
          btnGeminiLive.Enabled := True;
          btnLiveTranslation.Enabled := False;
        end;
      end;
    TGeminiLiveState.Stopping:
      begin
        btnGeminiLive.Enabled := False;
        btnLiveTranslation.Enabled := False;
        if cbLanguage <> nil then
          cbLanguage.Enabled := False;

        if FActiveMode = TFormMode.Translation then
          btnLiveTranslation.Text := ifthen(IsPt, 'Encerrando Tradutor...', 'Stopping Translator...')
        else
          btnGeminiLive.Text := ifthen(IsPt, 'Encerrando Simulação...', 'Stopping Simulation...');
      end;
    TGeminiLiveState.Error:
      begin
        btnGeminiLive.Enabled := True;
        btnLiveTranslation.Enabled := True;
        if cbLanguage <> nil then
          cbLanguage.Enabled := True;

        if FActiveMode = TFormMode.Translation then
        begin
          btnLiveTranslation.Text := ifthen(IsPt, 'Erro: Tentar Tradutor', 'Error: Retry Translator');
          btnGeminiLive.Text := ifthen(IsPt, 'Iniciar Simulação', 'Start Simulation');
        end
        else
        begin
          btnGeminiLive.Text := ifthen(IsPt, 'Erro: Tentar Simulação', 'Error: Retry Simulation');
          btnLiveTranslation.Text := ifthen(IsPt, 'Modo Tradutor Simultâneo', 'Simultaneous Translator Mode');
        end;
      end;
  end;
end;

end.
