unit NotaFiscal.RetornoEmissao;

interface

uses NotaFiscal.Types;

type
  TNotaFiscalRetornoEmissao = record
    Status: TStatusEmissao;
    CStat : Integer;
    Motivo : String;
    DtRecebimento : TDateTime;
    ChaveAcesso : String;
    Protocolo : String;
    Documento : String;
    ErroTecnico : String;
  end;

implementation

end.
