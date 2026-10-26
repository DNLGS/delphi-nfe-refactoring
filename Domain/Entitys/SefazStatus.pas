unit SefazStatus;

interface

uses
  SysUtils;

type
  TSefazStatus = class
  private
    FCStat: Integer;
    FMotivo: String;
    FDtRecebimento: TDateTime;
    FDtRetorno: TDateTime;
    FUF: String;
    FVersaoAplicacao, FObservacao: String;
    FTempoMedio: Integer;
    FErroTecnico: String;
  public
    property CStat: Integer read FCStat;
    property Motivo: String read FMotivo;
    property UF: String read FUF;
    property DtRecebimento: TDateTime read FDtRecebimento;
    property DtRetorno: TDateTime read FDtRetorno;
    property VersaoAplicacao: String read FVersaoAplicacao;
    property Observacao: String read FObservacao;
    property TempoMedio: Integer read FTempoMedio;
    property ErroTecnico: String read FErroTecnico;
    procedure Validar;
    constructor Create(ACStat: Integer; AMotivo, AUF: String;
      ADtRecebimento, ADtRetorno: TDateTime; const AVersaoAplicacao: String = '';
      ATempoMedio: Integer = 0; const AObservacao: String = '';
      const AErroTecnico: String = '');
  end;

implementation

uses
  NotaFiscal.Validacao;

constructor TSefazStatus.Create(ACStat: Integer; AMotivo, AUF: String;
  ADtRecebimento, ADtRetorno: TDateTime; const AVersaoAplicacao: String;
  ATempoMedio: Integer; const AObservacao: String; const AErroTecnico: String);
begin
  inherited Create;

  FCStat := ACStat;
  FMotivo := AMotivo;
  FUF := AUF;
  FDtRecebimento := ADtRecebimento;
  FDtRetorno := ADtRetorno;
  FVersaoAplicacao := AVersaoAplicacao;
  FTempoMedio := ATempoMedio;
  FObservacao := AObservacao;
  FErroTecnico := AErroTecnico;
  Validar;
end;

procedure TSefazStatus.Validar;
begin
  TValidacaoNotaFiscal.Exigir(((FCStat > 0) and (FCStat <= 9999)) or
    ((FCStat = 0) and (FErroTecnico <> '')), 'CStat deve estar entre 1 e 9999, ou zero com erro tecnico.');
  TValidacaoNotaFiscal.Texto(FMotivo, 'Motivo SEFAZ', 255, FCStat <> 0);
  TValidacaoNotaFiscal.CodigoUF(FUF);
  TValidacaoNotaFiscal.Valores([FDtRecebimento, FDtRetorno, FTempoMedio], 'Datas/tempo do status SEFAZ');
  TValidacaoNotaFiscal.Texto(FVersaoAplicacao, 'Versao da aplicacao SEFAZ', 20, False);
  TValidacaoNotaFiscal.Texto(FObservacao, 'Observacao SEFAZ', 255, False);
end;

end.
