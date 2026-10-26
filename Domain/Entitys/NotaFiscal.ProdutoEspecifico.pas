unit NotaFiscal.ProdutoEspecifico;

interface

type
  TLoteNotaFiscal = record
    Numero: String;
    Quantidade: Double;
    Fabricacao, Validade: TDateTime;
    procedure Validar;
  end;

  TMedicamentoNotaFiscal = record
    Informado: Boolean;
    CodigoANVISA, MotivoIsencao: String;
    PrecoMaximoConsumidor: Currency;
    procedure Validar;
  end;

  TCombustivelNotaFiscal = record
    Informado: Boolean;
    CodigoANP, DescricaoANP, UFConsumo: String;
    PercentualGLP, PercentualGasNacional, PercentualGasImportado: Double;
    ValorPartida: Currency;
    procedure Validar;
  end;

  TAdicaoImportacaoNotaFiscal = record
    Numero, Sequencia: Integer;
    CodigoFabricante: String;
    Desconto: Currency;
    procedure Validar;
  end;

  TImportacaoNotaFiscal = record
    Numero, LocalDesembaraco, UFDesembaraco, CodigoExportador: String;
    Registro, Desembaraco: TDateTime;
    ViaTransporte, TipoIntermediacao: Integer;
    CNPJAdquirente, UFTerceiro: String;
    ValorAFRMM: Currency;
    Adicoes: TArray<TAdicaoImportacaoNotaFiscal>;
    procedure Validar;
  end;

  TReceituarioNotaFiscal = record
    Numero, CPFResponsavel: String;
    procedure Validar;
  end;

  TNotaFiscalProdutoEspecifico = class
  public
    Medicamento: TMedicamentoNotaFiscal;
    Combustivel: TCombustivelNotaFiscal;
    Lotes: TArray<TLoteNotaFiscal>;
    Importacoes: TArray<TImportacaoNotaFiscal>;
    Receituarios: TArray<TReceituarioNotaFiscal>;
    procedure Validar;
  end;

implementation

uses
  NotaFiscal.Validacao;

procedure TLoteNotaFiscal.Validar;
begin
  TValidacaoNotaFiscal.Texto(Numero, 'Numero do lote', 20);
  TValidacaoNotaFiscal.NaoNegativo(Quantidade, 'Quantidade do lote');
  TValidacaoNotaFiscal.Exigir(Quantidade > 0, 'Quantidade do lote deve ser positiva.');
  TValidacaoNotaFiscal.Valores([Fabricacao, Validade], 'Datas do lote');
  TValidacaoNotaFiscal.Exigir((Fabricacao > 0) and (Validade >= Fabricacao), 'Datas do lote invalidas.');
end;

procedure TMedicamentoNotaFiscal.Validar;
begin
  if not Informado then
    Exit;
  if CodigoANVISA = 'ISENTO' then
    TValidacaoNotaFiscal.Texto(MotivoIsencao, 'Motivo de isencao ANVISA', 255, False)
  else
  begin
    TValidacaoNotaFiscal.Exigir(Length(CodigoANVISA) in [11, 13], 'Registro ANVISA deve ter 11 ou 13 digitos.');
    TValidacaoNotaFiscal.Digitos(CodigoANVISA, 'Registro ANVISA', Length(CodigoANVISA));
  end;
  TValidacaoNotaFiscal.NaoNegativo(PrecoMaximoConsumidor, 'Preco maximo do medicamento');
end;

procedure TCombustivelNotaFiscal.Validar;
var
  Soma: Double;
begin
  if not Informado then
    Exit;
  TValidacaoNotaFiscal.Digitos(CodigoANP, 'Codigo ANP', 9);
  TValidacaoNotaFiscal.Texto(DescricaoANP, 'Descricao ANP', 95);
  TValidacaoNotaFiscal.CodigoUF(UFConsumo);
  TValidacaoNotaFiscal.Percentuais([PercentualGLP, PercentualGasNacional,
    PercentualGasImportado], 'Composicao do combustivel');
  Soma := PercentualGLP + PercentualGasNacional + PercentualGasImportado;
  if Soma > 0 then
    TValidacaoNotaFiscal.Exigir(Abs(Soma - 100) <= 0.0001, 'Composicao do combustivel deve somar 100%.');
  TValidacaoNotaFiscal.NaoNegativo(ValorPartida, 'Valor de partida do combustivel');
end;

procedure TAdicaoImportacaoNotaFiscal.Validar;
begin
  TValidacaoNotaFiscal.Exigir((Numero > 0) and (Numero <= 999) and
    (Sequencia > 0) and (Sequencia <= 999), 'Numero/sequencia da adicao invalido.');
  TValidacaoNotaFiscal.Texto(CodigoFabricante, 'Fabricante estrangeiro', 60);
  TValidacaoNotaFiscal.NaoNegativo(Desconto, 'Desconto da adicao');
end;

procedure TImportacaoNotaFiscal.Validar;
var
  Adicao: TAdicaoImportacaoNotaFiscal;
begin
  TValidacaoNotaFiscal.Texto(Numero, 'Numero DI/DUIMP', 15);
  TValidacaoNotaFiscal.Valores([Registro, Desembaraco], 'Datas da importacao');
  TValidacaoNotaFiscal.Exigir((Registro > 0) and (Desembaraco > 0), 'Datas da importacao obrigatorias.');
  TValidacaoNotaFiscal.Texto(LocalDesembaraco, 'Local de desembaraco', 60);
  TValidacaoNotaFiscal.CodigoUF(UFDesembaraco);
  TValidacaoNotaFiscal.Texto(CodigoExportador, 'Codigo do exportador', 60);
  TValidacaoNotaFiscal.Exigir((ViaTransporte >= 1) and (ViaTransporte <= 13), 'Via de transporte da importacao invalida.');
  TValidacaoNotaFiscal.Exigir((TipoIntermediacao >= 1) and (TipoIntermediacao <= 3), 'Intermediacao da importacao invalida.');
  if TipoIntermediacao > 1 then
  begin
    TValidacaoNotaFiscal.Documento(CNPJAdquirente, 'CNPJ do adquirente');
    TValidacaoNotaFiscal.Exigir(Length(TValidacaoNotaFiscal.NormalizarDocumento(CNPJAdquirente)) = 14, 'Adquirente deve informar CNPJ.');
    TValidacaoNotaFiscal.CodigoUF(UFTerceiro);
  end;
  TValidacaoNotaFiscal.NaoNegativo(ValorAFRMM, 'AFRMM');
  TValidacaoNotaFiscal.Exigir((Length(Adicoes) > 0) and (Length(Adicoes) <= 999), 'Importacao deve ter de 1 a 999 adicoes.');
  for Adicao in Adicoes do
    Adicao.Validar;
end;

procedure TReceituarioNotaFiscal.Validar;
begin
  TValidacaoNotaFiscal.Texto(Numero, 'Numero do receituario', 30);
  TValidacaoNotaFiscal.Digitos(TValidacaoNotaFiscal.NormalizarDocumento(CPFResponsavel), 'CPF do responsavel pelo receituario', 11);
  TValidacaoNotaFiscal.Documento(CPFResponsavel, 'CPF do responsavel pelo receituario');
end;

procedure TNotaFiscalProdutoEspecifico.Validar;
var
  Lote: TLoteNotaFiscal;
  Importacao: TImportacaoNotaFiscal;
  Receita: TReceituarioNotaFiscal;
begin
  Medicamento.Validar;
  Combustivel.Validar;
  TValidacaoNotaFiscal.Exigir(Length(Lotes) <= 500, 'Limite de 500 lotes por item.');
  TValidacaoNotaFiscal.Exigir(Length(Importacoes) <= 100, 'Limite de 100 declaracoes de importacao por item.');
  for Lote in Lotes do
    Lote.Validar;
  for Importacao in Importacoes do
    Importacao.Validar;
  for Receita in Receituarios do
    Receita.Validar;
end;

end.
