unit NotaFiscal.Totais;

interface

type
  TNotaFiscalTotais = class
  public
    BaseICMS, ValorICMS, BaseICMSST, ValorICMSST, ValorFCPST: Currency;
    ValorFCPDestino, ValorICMSDestino, ValorICMSRemetente: Currency;
    ValorProdutos, ValorServicos, Desconto, Frete, Seguro, OutrasDespesas: Currency;
    ValorPIS, ValorCOFINS, ValorIPI, ValorNota, ValorAproximadoTributos: Currency;
    BaseISSQN, ValorISSQN, ValorPISServicos, ValorCOFINSServicos: Currency;
    BaseIRRF, ValorIRRF: Currency;
    BaseIBSCBS, ValorIBSUF, ValorIBSMunicipio, ValorIBS, ValorCBS: Currency;
    procedure Validar;
  end;

implementation

uses
  NotaFiscal.Validacao;

procedure TNotaFiscalTotais.Validar;
begin
  TValidacaoNotaFiscal.Valores([BaseICMS, ValorICMS, BaseICMSST, ValorICMSST,
    ValorFCPST, ValorFCPDestino, ValorICMSDestino, ValorICMSRemetente,
    ValorProdutos, ValorServicos, Desconto, Frete, Seguro, OutrasDespesas,
    ValorPIS, ValorCOFINS, ValorIPI, ValorNota, ValorAproximadoTributos,
    BaseISSQN, ValorISSQN, ValorPISServicos, ValorCOFINSServicos, BaseIRRF,
    ValorIRRF, BaseIBSCBS, ValorIBSUF, ValorIBSMunicipio, ValorIBS, ValorCBS], 'Totais da nota');
  TValidacaoNotaFiscal.Exigir(Abs(ValorIBS - ValorIBSUF - ValorIBSMunicipio) <= 0.01, 'Total IBS difere da soma UF/municipio.');
end;

end.
