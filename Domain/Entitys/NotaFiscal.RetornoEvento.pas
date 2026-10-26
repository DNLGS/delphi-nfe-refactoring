unit NotaFiscal.RetornoEvento;

interface

uses NotaFiscal.Types;

type
  TNotaFiscalRetornoEvento = record
    TipoEvento : TTipoEvento;
    Status : TStatusEvento;
    Chave : String;
    CStat : Integer;
    Sequencia : Integer;
    Ambiente : TTipoAmbiente;
    Motivo : String;
    Protocolo : String;
    DtRegistro : String;
    Documento : String;
    ErroTecnico : String;
  end;

implementation

end.
