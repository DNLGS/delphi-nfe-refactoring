unit NotaFiscal.Impostos;

interface

uses
  NotaFiscal.Types;

type
  TICMSNotaFiscal = record
    Origem, ModalidadeBase, ModalidadeBaseST: Integer;
    CST, CSOSN: String;
    BaseCalculo, Valor, BaseST, ValorST, BaseFCPST, ValorFCPST, ValorCreditoSN: Currency;
    Aliquota, AliquotaST, MargemValorAdicionadoST, ReducaoBase, AliquotaFCPST,
      AliquotaCreditoSN: Double;
    procedure Validar(ARegime: TRegimeTributario);
  end;

  TContribuicaoNotaFiscal = record
    CST: String;
    BaseCalculo, Valor: Currency;
    Aliquota, QuantidadeBase, AliquotaUnitaria: Double;
    procedure Validar(const ANome: String; AObrigatorio: Boolean);
  end;

  TContribuicaoSTNotaFiscal = record
    Informado: Boolean;
    BaseCalculo, Valor: Currency;
    Aliquota, QuantidadeBase, AliquotaUnitaria: Double;
    procedure Validar(const ANome: String);
  end;

  TIPINotaFiscal = record
    Informado: Boolean;
    CST, Enquadramento: String;
    BaseCalculo, Valor: Currency;
    Aliquota, Quantidade, ValorUnidade: Double;
    procedure Validar;
  end;

  TISSQNNotaFiscal = record
    Informado: Boolean;
    CodMunicipio, ListaServico, SituacaoTributaria: String;
    BaseCalculo, Valor: Currency;
    Aliquota: Double;
    procedure Validar;
  end;

  TDIFALNotaFiscal = record
    Informado: Boolean;
    BaseCalculo, BaseFCP, ValorFCP, ValorDestino, ValorRemetente: Currency;
    AliquotaFCP, AliquotaDestino, AliquotaInterestadual, PartilhaDestino: Double;
    procedure Validar;
  end;

  TParcelaIBSCBS = record
    Aliquota, ReducaoAliquota, AliquotaEfetiva: Double;
    Valor: Currency;
    procedure Validar;
  end;

  TTributacaoRegularIBSCBS = record
    Informado: Boolean;
    CST, ClassificacaoTributaria: String;
    AliquotaEfetivaIBSUF, AliquotaEfetivaIBSMunicipio, AliquotaEfetivaCBS: Double;
    ValorIBSUF, ValorIBSMunicipio, ValorCBS: Currency;
    procedure Validar;
  end;

  TIBSCBSNotaFiscal = record
    Informado: Boolean;
    CST, ClassificacaoTributaria: String;
    BaseCalculo, ValorIBS: Currency;
    IBSUF, IBSMunicipio, CBS: TParcelaIBSCBS;
    TributacaoRegular: TTributacaoRegularIBSCBS;
    procedure Validar;
  end;

  TNotaFiscalImpostos = class
  public
    ICMS: TICMSNotaFiscal;
    PIS, COFINS: TContribuicaoNotaFiscal;
    PISST, COFINSST: TContribuicaoSTNotaFiscal;
    IPI: TIPINotaFiscal;
    ISSQN: TISSQNNotaFiscal;
    DIFAL: TDIFALNotaFiscal;
    IBSCBS: TIBSCBSNotaFiscal;
    ValorAproximadoTributos: Currency;
    procedure Validar(ARegime: TRegimeTributario);
  end;

implementation

uses
  System.SysUtils, NotaFiscal.Validacao;

procedure TICMSNotaFiscal.Validar(ARegime: TRegimeTributario);
begin
  TValidacaoNotaFiscal.Exigir((Origem >= 0) and (Origem <= 8), 'Origem do produto invalida.');
  if ARegime in [rtSimplesNacional, rtMEI] then
  begin
    TValidacaoNotaFiscal.Digitos(CSOSN, 'CSOSN', 3);
    TValidacaoNotaFiscal.Exigir(Pos('|' + CSOSN + '|', '|101|102|103|201|202|203|300|400|500|900|') > 0, 'CSOSN invalido.');
    TValidacaoNotaFiscal.Exigir(CST = '', 'Informe CSOSN sem CST no Simples Nacional/MEI.');
  end
  else
  begin
    TValidacaoNotaFiscal.Digitos(CST, 'CST ICMS', 2);
    TValidacaoNotaFiscal.Exigir(Pos('|' + CST + '|', '|00|02|10|15|20|30|40|41|50|51|53|60|61|70|90|') > 0, 'CST ICMS invalido.');
    TValidacaoNotaFiscal.Exigir((CST <> '02') and (CST <> '15') and
      (CST <> '53') and (CST <> '61'),
      'ICMS monofasico nao suportado: faltam os campos especificos no modelo da nota.');
    TValidacaoNotaFiscal.Exigir(CSOSN = '', 'CSOSN incompativel com o regime tributario.');
  end;
  TValidacaoNotaFiscal.Exigir((ModalidadeBase >= 0) and (ModalidadeBase <= 3), 'Modalidade de base ICMS invalida.');
  TValidacaoNotaFiscal.Exigir((ModalidadeBaseST >= 0) and (ModalidadeBaseST <= 6), 'Modalidade de base ICMS ST invalida.');
  TValidacaoNotaFiscal.Valores([BaseCalculo, Valor, BaseST, ValorST, BaseFCPST,
    ValorFCPST, ValorCreditoSN, MargemValorAdicionadoST], 'ICMS');
  TValidacaoNotaFiscal.Percentuais([Aliquota, AliquotaST, ReducaoBase,
    AliquotaFCPST, AliquotaCreditoSN], 'Aliquota/reducao ICMS');
end;

procedure TContribuicaoNotaFiscal.Validar(const ANome: String; AObrigatorio: Boolean);
var
  Codigo: Integer;
begin
  TValidacaoNotaFiscal.Valores([BaseCalculo, Valor, QuantidadeBase, AliquotaUnitaria], ANome);
  TValidacaoNotaFiscal.Percentual(Aliquota, 'Aliquota ' + ANome);
  if (CST = '') and not AObrigatorio then
  begin
    TValidacaoNotaFiscal.Exigir((BaseCalculo = 0) and (Valor = 0) and (Aliquota = 0) and
      (QuantidadeBase = 0) and (AliquotaUnitaria = 0), 'CST obrigatorio para valores de ' + ANome + '.');
    Exit;
  end;
  TValidacaoNotaFiscal.Digitos(CST, 'CST ' + ANome, 2);
  Codigo := StrToInt(CST);
  TValidacaoNotaFiscal.Exigir((Codigo in [1..9, 49..56, 60..67, 70..75, 98, 99]), 'CST ' + ANome + ' invalido.');
end;

procedure TContribuicaoSTNotaFiscal.Validar(const ANome: String);
begin
  if not Informado then
    Exit;
  TValidacaoNotaFiscal.Valores([BaseCalculo, Valor, QuantidadeBase, AliquotaUnitaria], ANome);
  TValidacaoNotaFiscal.Percentual(Aliquota, ANome);
end;

procedure TIPINotaFiscal.Validar;
begin
  if not Informado then
    Exit;
  TValidacaoNotaFiscal.Digitos(CST, 'CST IPI', 2);
  TValidacaoNotaFiscal.Exigir(Pos('|' + CST + '|', '|00|01|02|03|04|05|49|50|51|52|53|54|55|99|') > 0, 'CST IPI invalido.');
  TValidacaoNotaFiscal.Digitos(Enquadramento, 'Enquadramento IPI', 3);
  TValidacaoNotaFiscal.Valores([BaseCalculo, Valor, Quantidade, ValorUnidade], 'IPI');
  TValidacaoNotaFiscal.Percentual(Aliquota, 'Aliquota IPI');
end;

procedure TISSQNNotaFiscal.Validar;
begin
  if not Informado then
    Exit;
  TValidacaoNotaFiscal.Digitos(CodMunicipio, 'Municipio ISSQN', 7);
  TValidacaoNotaFiscal.Texto(ListaServico, 'Item da lista de servicos', 5);
  TValidacaoNotaFiscal.Texto(SituacaoTributaria, 'Situacao tributaria ISSQN', 2, False);
  TValidacaoNotaFiscal.Valores([BaseCalculo, Valor], 'ISSQN');
  TValidacaoNotaFiscal.Percentual(Aliquota, 'Aliquota ISSQN');
end;

procedure TDIFALNotaFiscal.Validar;
begin
  if not Informado then
    Exit;
  TValidacaoNotaFiscal.Valores([BaseCalculo, BaseFCP, ValorFCP, ValorDestino, ValorRemetente], 'DIFAL');
  TValidacaoNotaFiscal.Percentuais([AliquotaFCP, AliquotaDestino, AliquotaInterestadual,
    PartilhaDestino], 'Aliquota/partilha DIFAL');
end;

procedure TParcelaIBSCBS.Validar;
begin
  TValidacaoNotaFiscal.Percentuais([Aliquota, ReducaoAliquota, AliquotaEfetiva], 'Aliquota IBS/CBS');
  TValidacaoNotaFiscal.NaoNegativo(Valor, 'Valor IBS/CBS');
end;

procedure TTributacaoRegularIBSCBS.Validar;
begin
  if not Informado then
    Exit;
  TValidacaoNotaFiscal.Digitos(CST, 'CST regular IBS/CBS', 3);
  TValidacaoNotaFiscal.Digitos(ClassificacaoTributaria, 'Classificacao regular IBS/CBS', 6);
  TValidacaoNotaFiscal.Exigir(Copy(ClassificacaoTributaria, 1, 3) = CST, 'Classificacao regular incompativel com CST.');
  TValidacaoNotaFiscal.Percentuais([AliquotaEfetivaIBSUF, AliquotaEfetivaIBSMunicipio,
    AliquotaEfetivaCBS], 'Aliquota regular IBS/CBS');
  TValidacaoNotaFiscal.Valores([ValorIBSUF, ValorIBSMunicipio, ValorCBS], 'Tributacao regular IBS/CBS');
end;

procedure TIBSCBSNotaFiscal.Validar;
begin
  if not Informado then
    Exit;
  TValidacaoNotaFiscal.Digitos(CST, 'CST IBS/CBS', 3);
  TValidacaoNotaFiscal.Digitos(ClassificacaoTributaria, 'Classificacao IBS/CBS', 6);
  TValidacaoNotaFiscal.Exigir(Copy(ClassificacaoTributaria, 1, 3) = CST, 'Classificacao IBS/CBS incompativel com CST.');
  TValidacaoNotaFiscal.Valores([BaseCalculo, ValorIBS], 'IBS/CBS');
  IBSUF.Validar;
  IBSMunicipio.Validar;
  CBS.Validar;
  TributacaoRegular.Validar;
  TValidacaoNotaFiscal.Exigir(Abs(ValorIBS - IBSUF.Valor - IBSMunicipio.Valor) <= 0.01, 'Valor IBS difere da soma UF/municipio.');
end;

procedure TNotaFiscalImpostos.Validar(ARegime: TRegimeTributario);
begin
  // O ERP informa os valores; as entidades nao calculam impostos.
  if not ISSQN.Informado then
    ICMS.Validar(ARegime);
  PIS.Validar('PIS', not (ARegime in [rtSimplesNacional, rtMEI]));
  COFINS.Validar('COFINS', not (ARegime in [rtSimplesNacional, rtMEI]));
  PISST.Validar('PIS ST');
  COFINSST.Validar('COFINS ST');
  IPI.Validar;
  ISSQN.Validar;
  DIFAL.Validar;
  IBSCBS.Validar;
  TValidacaoNotaFiscal.NaoNegativo(ValorAproximadoTributos, 'Valor aproximado dos tributos');
end;

end.
