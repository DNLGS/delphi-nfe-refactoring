unit NotaFiscal.Cobranca;

interface

uses
  NotaFiscal.Types;

type
  TFaturaNotaFiscal = record
    Informada: Boolean;
    Numero: String;
    ValorOriginal, Desconto, ValorLiquido: Currency;
    procedure Validar;
  end;

  TDuplicataNotaFiscal = record
    Numero: String;
    Vencimento: TDateTime;
    Valor: Currency;
    procedure Validar;
  end;

  TPagamentoNotaFiscal = record
    Indicador: TIndicadorPagamento;
    Meio: String;
    Descricao: String;
    Valor: Currency;
    Integracao: TIntegracaoPagamento;
    CNPJInstituicao, BandeiraCartao, Autorizacao: String;
    procedure Validar;
  end;

  TNotaFiscalCobranca = class
  public
    Fatura: TFaturaNotaFiscal;
    Duplicatas: TArray<TDuplicataNotaFiscal>;
    Pagamentos: TArray<TPagamentoNotaFiscal>;
    Troco: Currency;
    procedure Validar(AValorNota: Currency; AModelo: TModeloNotaFiscal;
      AEmissao: TDateTime; AFinalidade: TTipoFinalidade = tfNormal);
  end;

implementation

uses
  System.SysUtils, NotaFiscal.Validacao;

procedure TFaturaNotaFiscal.Validar;
begin
  if not Informada then
    Exit;
  TValidacaoNotaFiscal.Texto(Numero, 'Numero da fatura', 60, False);
  TValidacaoNotaFiscal.Valores([ValorOriginal, Desconto, ValorLiquido], 'Fatura');
  TValidacaoNotaFiscal.Exigir(Desconto <= ValorOriginal, 'Desconto excede a fatura.');
  TValidacaoNotaFiscal.Exigir(Abs(ValorOriginal - Desconto - ValorLiquido) <= 0.01, 'Valor liquido da fatura inconsistente.');
end;

procedure TDuplicataNotaFiscal.Validar;
begin
  TValidacaoNotaFiscal.Digitos(Numero, 'Numero da duplicata', 3);
  TValidacaoNotaFiscal.Exigir(Numero <> '000', 'Numero da duplicata deve ser positivo.');
  TValidacaoNotaFiscal.NaoNegativo(Vencimento, 'Vencimento da duplicata');
  TValidacaoNotaFiscal.Exigir(Vencimento > 0, 'Vencimento da duplicata obrigatorio.');
  TValidacaoNotaFiscal.Exigir(Valor > 0, 'Valor da duplicata deve ser positivo.');
end;

procedure TPagamentoNotaFiscal.Validar;
begin
  TValidacaoNotaFiscal.Exigir((Indicador = ipVista) or (Indicador = ipPrazo), 'Indicador de pagamento invalido.');
  TValidacaoNotaFiscal.Digitos(Meio, 'Meio de pagamento', 2);
  TValidacaoNotaFiscal.Exigir(Pos('|' + Meio + '|', '|01|02|03|04|05|10|11|12|13|14|15|16|17|18|19|20|21|22|90|91|99|') > 0, 'Meio de pagamento invalido.');
  TValidacaoNotaFiscal.Texto(Descricao, 'Descricao do pagamento', 60, Meio = '99');
  TValidacaoNotaFiscal.NaoNegativo(Valor, 'Valor do pagamento');
  TValidacaoNotaFiscal.Exigir((Integracao = itNaoInformada) or
    (Integracao = itIntegrado) or (Integracao = itNaoIntegrado), 'Integracao do pagamento invalida.');
  if Meio = '90' then
    TValidacaoNotaFiscal.Exigir(Valor = 0, 'Sem pagamento exige valor zero.')
  else
    TValidacaoNotaFiscal.Exigir(Valor > 0, 'Pagamento deve ter valor positivo.');
  if (Meio = '03') or (Meio = '04') then
    TValidacaoNotaFiscal.Exigir(Integracao <> itNaoInformada, 'Cartao exige tipo de integracao.');
  if Integracao = itIntegrado then
  begin
    TValidacaoNotaFiscal.Documento(CNPJInstituicao, 'CNPJ da instituicao de pagamento');
    TValidacaoNotaFiscal.Exigir(Length(TValidacaoNotaFiscal.NormalizarDocumento(CNPJInstituicao)) = 14, 'Instituicao deve informar CNPJ.');
    TValidacaoNotaFiscal.Texto(Autorizacao, 'Autorizacao de pagamento', 128);
  end
  else
  begin
    TValidacaoNotaFiscal.Documento(CNPJInstituicao, 'CNPJ da instituicao de pagamento', False);
    TValidacaoNotaFiscal.Texto(Autorizacao, 'Autorizacao de pagamento', 128, False);
  end;
  TValidacaoNotaFiscal.Digitos(BandeiraCartao, 'Bandeira do cartao', 2, False);
end;

procedure TNotaFiscalCobranca.Validar(AValorNota: Currency;
  AModelo: TModeloNotaFiscal; AEmissao: TDateTime; AFinalidade: TTipoFinalidade);
var
  I: Integer;
  SomaDuplicatas, SomaPagamentos: Currency;
  SemPagamento: Boolean;
begin
  Fatura.Validar;
  TValidacaoNotaFiscal.NaoNegativo(Troco, 'Troco');
  TValidacaoNotaFiscal.Exigir((Length(Duplicatas) <= 120) and
    (Length(Pagamentos) >= 1) and (Length(Pagamentos) <= 100), 'Quantidade de duplicatas/pagamentos invalida.');
  TValidacaoNotaFiscal.Exigir((Length(Duplicatas) = 0) or Fatura.Informada, 'Duplicatas exigem fatura.');
  TValidacaoNotaFiscal.Exigir((AModelo <> mNFCe) or
    ((Length(Duplicatas) = 0) and not Fatura.Informada), 'NFC-e nao permite grupo de cobranca.');
  SomaDuplicatas := 0;
  for I := 0 to High(Duplicatas) do
  begin
    Duplicatas[I].Validar;
    TValidacaoNotaFiscal.Exigir(Duplicatas[I].Numero = FormatFloat('000', I + 1), 'Duplicatas devem ser numeradas de 001 em diante.');
    TValidacaoNotaFiscal.Exigir(Trunc(Duplicatas[I].Vencimento) >= Trunc(AEmissao), 'Duplicata vence antes da emissao.');
    if I > 0 then
      TValidacaoNotaFiscal.Exigir(Duplicatas[I].Vencimento >= Duplicatas[I - 1].Vencimento, 'Vencimentos devem estar em ordem crescente.');
    SomaDuplicatas := SomaDuplicatas + Duplicatas[I].Valor;
  end;
  if Length(Duplicatas) > 0 then
    TValidacaoNotaFiscal.Exigir(Abs(SomaDuplicatas - Fatura.ValorLiquido) <= 0.01, 'Duplicatas diferem do valor liquido da fatura.');
  SomaPagamentos := 0;
  SemPagamento := False;
  for I := 0 to High(Pagamentos) do
  begin
    Pagamentos[I].Validar;
    SomaPagamentos := SomaPagamentos + Pagamentos[I].Valor;
    SemPagamento := SemPagamento or (Pagamentos[I].Meio = '90');
    if AFinalidade in [tfAjuste, tfDevolucao] then
      TValidacaoNotaFiscal.Exigir(Pagamentos[I].Meio = '90', 'Ajuste/devolucao exige meio sem pagamento.');
  end;
  if SemPagamento then
    TValidacaoNotaFiscal.Exigir((Length(Pagamentos) = 1) and (Troco = 0), 'Sem pagamento nao pode ser combinado com outros meios ou troco.')
  else if (AModelo = mNFE) and (SomaPagamentos < AValorNota) then
    TValidacaoNotaFiscal.Exigir(Troco = 0, 'Pagamento parcial nao pode informar troco.')
  else
    TValidacaoNotaFiscal.Exigir(Abs(SomaPagamentos - Troco - AValorNota) <= 0.01, 'Pagamentos menos troco diferem do total da nota.');
end;

end.
