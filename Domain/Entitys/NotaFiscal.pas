unit NotaFiscal;

interface

uses
  System.Generics.Collections, NotaFiscal.Types, NotaFiscal.Configuracao,
  NotaFiscal.Emissor, NotaFiscal.Destinatario, NotaFiscal.Endereco,
  NotaFiscal.Item, NotaFiscal.Totais, NotaFiscal.Transporte,
  NotaFiscal.Cobranca, NotaFiscal.Complementos;

type
  TNotaFiscal = class
  private
    FNroNota, FSerie, FCodigoNumerico: Integer;
    FModelo: TModeloNotaFiscal;
    FDtEmissao, FDtSaidaEmissao: TDateTime;
    FTipoCredito, FTipoDebito, FNaturezaOperacao, FVersaoProcesso: String;
    FNFReferencia: TArray<String>;
    FNFConfiguracao: TNotaFiscalConfiguracao;
    FEmitente: TNotaFiscalEmissor;
    FDestinatario: TNotaFiscalDestinatario;
    FEntrega: TNotaFiscalLocalEntrega;
    FItens: TObjectList<TNotaFiscalItem>;
    FTotais: TNotaFiscalTotais;
    FTransporte: TNotaFiscalTransporte;
    FCobranca: TNotaFiscalCobranca;
    FComplementos: TNotaFiscalComplementos;
    function GetItem(AIndice: Integer): TNotaFiscalItem;
    function GetQuantidadeItens: Integer;
    function GetNFReferencia: TArray<String>;
    procedure ValidarItensETotais;
  public
    constructor Create;
    destructor Destroy; override;
    function AdicionarItem: TNotaFiscalItem;
    procedure AdicionarReferencia(const AChave: String);
    // Chamar depois do preenchimento e novamente antes de consumir a nota.
    // shortcut: validacao local; aplicar schema e regras por UF/data no adaptador fiscal.
    procedure Validar;
    property NroNota: Integer read FNroNota write FNroNota;
    property Modelo: TModeloNotaFiscal read FModelo write FModelo;
    property Serie: Integer read FSerie write FSerie;
    property CodigoNumerico: Integer read FCodigoNumerico write FCodigoNumerico;
    property NaturezaOperacao: String read FNaturezaOperacao write FNaturezaOperacao;
    property VersaoProcesso: String read FVersaoProcesso write FVersaoProcesso;
    property TipoCredito: String read FTipoCredito write FTipoCredito;
    property TipoDebito: String read FTipoDebito write FTipoDebito;
    property DtEmissao: TDateTime read FDtEmissao write FDtEmissao;
    property DtSaidaEmissao: TDateTime read FDtSaidaEmissao write FDtSaidaEmissao;
    property NFConfiguracao: TNotaFiscalConfiguracao read FNFConfiguracao;
    property NFReferencia: TArray<String> read GetNFReferencia;
    property Emitente: TNotaFiscalEmissor read FEmitente;
    property Destinatario: TNotaFiscalDestinatario read FDestinatario;
    property Entrega: TNotaFiscalLocalEntrega read FEntrega;
    property Itens[AIndice: Integer]: TNotaFiscalItem read GetItem;
    property QuantidadeItens: Integer read GetQuantidadeItens;
    property Totais: TNotaFiscalTotais read FTotais;
    property Transporte: TNotaFiscalTransporte read FTransporte;
    property Cobranca: TNotaFiscalCobranca read FCobranca;
    property Complementos: TNotaFiscalComplementos read FComplementos;
  end;

implementation

uses
  System.SysUtils, NotaFiscal.Validacao;

constructor TNotaFiscal.Create;
begin
  inherited Create;
  FModelo := mNFE;
  FNFConfiguracao := TNotaFiscalConfiguracao.Create;
  FEmitente := TNotaFiscalEmissor.Create;
  FDestinatario := TNotaFiscalDestinatario.Create;
  FEntrega := TNotaFiscalLocalEntrega.Create;
  FItens := TObjectList<TNotaFiscalItem>.Create(True);
  FTotais := TNotaFiscalTotais.Create;
  FTransporte := TNotaFiscalTransporte.Create;
  FCobranca := TNotaFiscalCobranca.Create;
  FComplementos := TNotaFiscalComplementos.Create;
end;

destructor TNotaFiscal.Destroy;
begin
  FComplementos.Free;
  FCobranca.Free;
  FTransporte.Free;
  FTotais.Free;
  FItens.Free;
  FEntrega.Free;
  FDestinatario.Free;
  FEmitente.Free;
  FNFConfiguracao.Free;
  inherited;
end;

function TNotaFiscal.GetItem(AIndice: Integer): TNotaFiscalItem;
begin
  Result := FItens[AIndice];
end;

function TNotaFiscal.GetQuantidadeItens: Integer;
begin
  Result := FItens.Count;
end;

function TNotaFiscal.GetNFReferencia: TArray<String>;
begin
  Result := Copy(FNFReferencia, 0, Length(FNFReferencia));
end;

function TNotaFiscal.AdicionarItem: TNotaFiscalItem;
begin
  TValidacaoNotaFiscal.Exigir(FItens.Count < 990, 'Limite de 990 itens por nota.');
  Result := TNotaFiscalItem.Create(FItens.Count + 1);
  try
    FItens.Add(Result);
  except
    Result.Free;
    raise;
  end;
end;

procedure TNotaFiscal.AdicionarReferencia(const AChave: String);
var
  Chave: String;
begin
  TValidacaoNotaFiscal.Chave(AChave);
  TValidacaoNotaFiscal.Exigir(Length(FNFReferencia) + Length(FComplementos.ReferenciasECF) < 500, 'Limite de 500 referencias.');
  for Chave in FNFReferencia do
    TValidacaoNotaFiscal.Exigir(Chave <> AChave, 'Chave referenciada repetida.');
  SetLength(FNFReferencia, Length(FNFReferencia) + 1);
  FNFReferencia[High(FNFReferencia)] := AChave;
end;

procedure TNotaFiscal.ValidarItensETotais;
var
  Item: TNotaFiscalItem;
  Produtos, Servicos, Descontos, Frete, Seguro, Outras: Currency;
  IBSUF, IBSMunicipio, IBS, CBS, BaseIBSCBS: Currency;
  PrefixoCFOP: Char;
begin
  TValidacaoNotaFiscal.Exigir(FItens.Count > 0, 'Nota deve ter pelo menos um item.');
  Produtos := 0;
  Servicos := 0;
  Descontos := 0;
  Frete := 0;
  Seguro := 0;
  Outras := 0;
  IBSUF := 0;
  IBSMunicipio := 0;
  IBS := 0;
  CBS := 0;
  BaseIBSCBS := 0;
  if FNFConfiguracao.TipoNota = teSaida then
    case FNFConfiguracao.DestinoOperacao of
      tdInterna: PrefixoCFOP := '5';
      tdInterestadual: PrefixoCFOP := '6';
      tdExterior: PrefixoCFOP := '7';
    else
      PrefixoCFOP := #0;
    end
  else
    case FNFConfiguracao.DestinoOperacao of
      tdInterna: PrefixoCFOP := '1';
      tdInterestadual: PrefixoCFOP := '2';
      tdExterior: PrefixoCFOP := '3';
    else
      PrefixoCFOP := #0;
    end;
  for Item in FItens do
  begin
    try
      Item.Validar(FEmitente.RegimeTributario, FNFConfiguracao.TipoFinalidade);
      TValidacaoNotaFiscal.Exigir(Item.CFOP[1] = PrefixoCFOP, 'CFOP incompativel com tipo/destino da operacao.');
      if Item.Impostos.ISSQN.Informado then
        Servicos := Servicos + Item.ValorProdutos
      else if Item.CompoeTotal then
        Produtos := Produtos + Item.ValorProdutos;
      Descontos := Descontos + Item.Desconto;
      Frete := Frete + Item.Frete;
      Seguro := Seguro + Item.Seguro;
      Outras := Outras + Item.OutrasDespesas;
      if Item.Impostos.IBSCBS.Informado then
      begin
        BaseIBSCBS := BaseIBSCBS + Item.Impostos.IBSCBS.BaseCalculo;
        IBSUF := IBSUF + Item.Impostos.IBSCBS.IBSUF.Valor;
        IBSMunicipio := IBSMunicipio + Item.Impostos.IBSCBS.IBSMunicipio.Valor;
        IBS := IBS + Item.Impostos.IBSCBS.ValorIBS;
        CBS := CBS + Item.Impostos.IBSCBS.CBS.Valor;
      end;
    except
      on E: ENotaFiscalInvalida do
        raise ENotaFiscalInvalida.CreateFmt('Item %d: %s', [Item.Numero, E.Message]);
    end;
  end;
  TValidacaoNotaFiscal.Exigir(Abs(Produtos - FTotais.ValorProdutos) <= 0.01, 'Total dos produtos difere dos itens.');
  TValidacaoNotaFiscal.Exigir(Abs(Servicos - FTotais.ValorServicos) <= 0.01, 'Total dos servicos difere dos itens.');
  TValidacaoNotaFiscal.Exigir(Abs(Descontos - FTotais.Desconto) <= 0.01, 'Total dos descontos difere dos itens.');
  TValidacaoNotaFiscal.Exigir(Abs(Frete - FTotais.Frete) <= 0.01, 'Total do frete difere dos itens.');
  TValidacaoNotaFiscal.Exigir(Abs(Seguro - FTotais.Seguro) <= 0.01, 'Total do seguro difere dos itens.');
  TValidacaoNotaFiscal.Exigir(Abs(Outras - FTotais.OutrasDespesas) <= 0.01, 'Total das outras despesas difere dos itens.');
  TValidacaoNotaFiscal.Exigir((Abs(BaseIBSCBS - FTotais.BaseIBSCBS) <= 0.01) and
    (Abs(IBSUF - FTotais.ValorIBSUF) <= 0.01) and
    (Abs(IBSMunicipio - FTotais.ValorIBSMunicipio) <= 0.01) and
    (Abs(IBS - FTotais.ValorIBS) <= 0.01) and (Abs(CBS - FTotais.ValorCBS) <= 0.01), 'Totais IBS/CBS diferem dos itens.');
end;

procedure TNotaFiscal.Validar;
var
  Chave: String;
begin
  TValidacaoNotaFiscal.Exigir((FModelo = mNFE) or (FModelo = mNFCe), 'Modelo deve ser 55 ou 65.');
  TValidacaoNotaFiscal.Exigir((FNroNota >= 1) and (FNroNota <= 999999999), 'Numero da nota deve estar entre 1 e 999999999.');
  TValidacaoNotaFiscal.Exigir((FSerie >= 0) and (FSerie <= 999), 'Serie deve estar entre 0 e 999.');
  TValidacaoNotaFiscal.Exigir((FCodigoNumerico >= 0) and (FCodigoNumerico <= 99999999), 'Codigo numerico deve ter no maximo 8 digitos.');
  TValidacaoNotaFiscal.Exigir(FDtEmissao > 0, 'Data de emissao obrigatoria.');
  TValidacaoNotaFiscal.NaoNegativo(FDtEmissao, 'Data de emissao');
  TValidacaoNotaFiscal.NaoNegativo(FDtSaidaEmissao, 'Data de saida/entrada');
  TValidacaoNotaFiscal.Texto(FNaturezaOperacao, 'Natureza da operacao', 60);
  TValidacaoNotaFiscal.Texto(FVersaoProcesso, 'Versao do processo emissor', 20);
  FNFConfiguracao.Validar(FModelo);
  if FModelo = mNFCe then
    TValidacaoNotaFiscal.Exigir(FDtSaidaEmissao = 0, 'NFC-e nao permite data de saida/entrada.');
  if FNFConfiguracao.TipoNota = teSaida then
    TValidacaoNotaFiscal.Exigir((FDtSaidaEmissao = 0) or
      (Trunc(FDtSaidaEmissao) >= Trunc(FDtEmissao)), 'Data de saida anterior a emissao.');
  FEmitente.Validar;
  FDestinatario.Validar(FModelo);
  FEntrega.Validar;
  if (FModelo = mNFCe) and (FNFConfiguracao.PresencaConsumidor = tpEntregaDomicilio) then
    TValidacaoNotaFiscal.Exigir(FDestinatario.Informado and FDestinatario.EnderecoInformado,
      'NFC-e com entrega a domicilio exige destinatario e endereco.');
  TValidacaoNotaFiscal.Exigir(FNFConfiguracao.UF = FEmitente.Endereco.UF, 'UF da configuracao difere do emitente.');
  if FDestinatario.Informado and ((FModelo = mNFE) or FDestinatario.EnderecoInformado) then
  begin
    TValidacaoNotaFiscal.Exigir((FNFConfiguracao.DestinoOperacao = tdExterior) =
      (FDestinatario.Endereco.UF = 'EX'), 'Destino exterior incompativel com endereco do destinatario.');
  end;
  TValidacaoNotaFiscal.Exigir(Length(FNFReferencia) + Length(FComplementos.ReferenciasECF) <= 500, 'Limite de 500 documentos referenciados.');
  for Chave in FNFReferencia do
    TValidacaoNotaFiscal.Chave(Chave);
  if FNFConfiguracao.TipoFinalidade = tfDevolucao then
    TValidacaoNotaFiscal.Exigir(Length(FNFReferencia) + Length(FComplementos.ReferenciasECF) > 0, 'Devolucao exige documento referenciado.');
  TValidacaoNotaFiscal.Digitos(FTipoCredito, 'Tipo de credito', 2, FNFConfiguracao.TipoFinalidade = tfCredito);
  TValidacaoNotaFiscal.Digitos(FTipoDebito, 'Tipo de debito', 2, FNFConfiguracao.TipoFinalidade = tfDebito);
  if FTipoCredito <> '' then
    TValidacaoNotaFiscal.Exigir(Pos('|' + FTipoCredito + '|', '|01|02|03|04|05|06|') > 0, 'Tipo de credito invalido.');
  if FTipoDebito <> '' then
    TValidacaoNotaFiscal.Exigir(Pos('|' + FTipoDebito + '|', '|01|02|03|04|05|06|07|08|') > 0, 'Tipo de debito invalido.');
  TValidacaoNotaFiscal.Exigir((FTipoCredito = '') or (FNFConfiguracao.TipoFinalidade = tfCredito), 'Tipo de credito exige finalidade credito.');
  TValidacaoNotaFiscal.Exigir((FTipoDebito = '') or (FNFConfiguracao.TipoFinalidade = tfDebito), 'Tipo de debito exige finalidade debito.');
  FTotais.Validar;
  ValidarItensETotais;
  if (FNFConfiguracao.DestinoOperacao <> tdExterior) and
    (FNFConfiguracao.TipoFinalidade in [tfNormal, tfDevolucao]) then
    TValidacaoNotaFiscal.Exigir(Abs(FTotais.ValorNota - (FTotais.ValorProdutos +
      FTotais.ValorServicos - FTotais.Desconto + FTotais.ValorICMSST +
      FTotais.ValorFCPST + FTotais.Frete + FTotais.Seguro + FTotais.OutrasDespesas +
      FTotais.ValorIPI)) <= 0.01, 'Valor da nota difere da composicao dos totais.');
  FTransporte.Validar;
  FCobranca.Validar(FTotais.ValorNota, FModelo, FDtEmissao, FNFConfiguracao.TipoFinalidade);
  FComplementos.Validar(FNFConfiguracao.Intermediador = tiComIntermediador);
end;

end.
