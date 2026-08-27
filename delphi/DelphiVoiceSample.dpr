program DelphiVoiceSample;

uses
  System.StartUpCopy,
  FMX.Forms,
  Form.Main in 'Form.Main.pas' {Form1};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
