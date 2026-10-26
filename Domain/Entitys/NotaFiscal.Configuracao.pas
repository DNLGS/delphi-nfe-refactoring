unit NotaFiscal.Configuracao;

interface

uses
  NotaFiscal.Types;

type
  TNotaFiscalConfiguracao = class
  private
    FUF: String;
    FTipoNota: TTipoNota;
    FCodMunicipio: String;
    FPresencaConsumidor: TTipoPresencaConsumidor;
    FTipoFinalidade: TTipoFinalidade;
    FTipoEmissao: TTipoEmissao;
    FTipoAmbiente: TTipoAmbiente;
    FConsumidorFinal: TTipoConsumidorFinal;
    FDestinoOperacao: TTipoDestinoOperacao;
    FIntermediador: TTipoIntermediador;
    FDtContingencia: TDateTime;
    FJustificativaContingencia: String;
  public
    constructor Create;
    procedure Validar(AModelo: TModeloNotaFiscal);
    property TipoNota: TTipoNota read FTipoNota write FTipoNota;
    property TipoFinalidade: TTipoFinalidade read FTipoFinalidade write FTipoFinalidade;
    property TipoEmissao: TTipoEmissao read FTipoEmissao write FTipoEmissao;
    property TipoAmbiente: TTipoAmbiente read FTipoAmbiente write FTipoAmbiente;
    property UF: String read FUF write FUF;
    property CodMunicipio: String read FCodMunicipio write FCodMunicipio;
    property Intermediador: TTipoIntermediador read FIntermediador write FIntermediador;
    property DestinoOperacao: TTipoDestinoOperacao read FDestinoOperacao write FDestinoOperacao;
    property ConsumidorFinal: TTipoConsumidorFinal read FConsumidorFinal write FConsumidorFinal;
    property PresencaConsumidor: TTipoPresencaConsumidor read FPresencaConsumidor write FPresencaConsumidor;
    property DtContingencia: TDateTime read FDtContingencia write FDtContingencia;
    property JustificativaContingencia: String read FJustificativaContingencia write FJustificativaContingencia;
  end;

implementation

uses
  NotaFiscal.Validacao;

constructor TNotaFiscalConfiguracao.Create;
begin
  inherited Create;
  FTipoNota := teSaida;
  FTipoFinalidade := tfNormal;
  FTipoEmissao := temNormal;
  FTipoAmbiente := taHomologacao;
  FDestinoOperacao := tdInterna;
  FConsumidorFinal := tcFinal;
  FPresencaConsumidor := tpPresencial;
end;

procedure TNotaFiscalConfiguracao.Validar(AModelo: TModeloNotaFiscal);
begin
  TValidacaoNotaFiscal.Municipio(FCodMunicipio, FUF);
  TValidacaoNotaFiscal.Exigir((FTipoNota = teEntrada) or (FTipoNota = teSaida), 'Tipo de nota invalido.');
  TValidacaoNotaFiscal.Exigir((Ord(FTipoFinalidade) >= 1) and (Ord(FTipoFinalidade) <= 6), 'Finalidade invalida.');
  TValidacaoNotaFiscal.Exigir((FTipoAmbiente = taProducao) or (FTipoAmbiente = taHomologacao), 'Ambiente invalido.');
  TValidacaoNotaFiscal.Exigir((FTipoEmissao = temNormal) or (FTipoEmissao = temContingenciaFSIA) or
    (FTipoEmissao = temEPEC) or (FTipoEmissao = temContingenciaFSDA) or
    (FTipoEmissao = temSVCAN) or (FTipoEmissao = temSVCRS) or
    (FTipoEmissao = temContingenciaOffline), 'Tipo de emissao invalido ou descontinuado.');
  TValidacaoNotaFiscal.Exigir((Ord(FDestinoOperacao) >= 1) and (Ord(FDestinoOperacao) <= 3), 'Destino da operacao invalido.');
  TValidacaoNotaFiscal.Exigir((FConsumidorFinal = tcNaoFinal) or (FConsumidorFinal = tcFinal), 'Consumidor final invalido.');
  TValidacaoNotaFiscal.Exigir((Ord(FPresencaConsumidor) <= 5) or
    (FPresencaConsumidor = tpOutros), 'Presenca do consumidor invalida.');
  TValidacaoNotaFiscal.Exigir((FIntermediador = tiSemIntermediador) or
    (FIntermediador = tiComIntermediador), 'Indicador de intermediador invalido.');
  if FTipoEmissao <> temNormal then
  begin
    TValidacaoNotaFiscal.NaoNegativo(FDtContingencia, 'Data da contingencia');
    TValidacaoNotaFiscal.Exigir(FDtContingencia > 0, 'Data da contingencia obrigatoria.');
    TValidacaoNotaFiscal.Texto(FJustificativaContingencia, 'Justificativa da contingencia', 256);
    TValidacaoNotaFiscal.Exigir(Length(FJustificativaContingencia) >= 15, 'Justificativa da contingencia deve ter pelo menos 15 caracteres.');
  end;
  if AModelo = mNFE then
    TValidacaoNotaFiscal.Exigir(FTipoEmissao <> temContingenciaOffline, 'Contingencia offline apenas para NFC-e.')
  else if AModelo = mNFCe then
  begin
    TValidacaoNotaFiscal.Exigir((FTipoEmissao = temNormal) or (FTipoEmissao = temContingenciaOffline), 'Tipo de emissao incompativel com NFC-e.');
    TValidacaoNotaFiscal.Exigir((FTipoNota = teSaida) and (FTipoFinalidade = tfNormal) and
      (FDestinoOperacao = tdInterna) and (FConsumidorFinal = tcFinal), 'NFC-e exige saida normal interna para consumidor final.');
    TValidacaoNotaFiscal.Exigir((FPresencaConsumidor = tpPresencial) or
      (FPresencaConsumidor = tpEntregaDomicilio), 'Presenca incompativel com NFC-e.');
  end;
end;

end.
