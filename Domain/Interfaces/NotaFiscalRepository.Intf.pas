unit NotaFiscalRepository.Intf;

interface

uses NotaFiscal, NotaFiscal.Types, NotaFiscal.RetornoEmissao,
  NotaFiscal.RetornoEvento;


type
  INotaFiscalRepository = interface
    ['{C43F22BB-A98F-489D-A87D-F0D97C41E36F}']

    // Persistência
    // Referencia estavel da nota no sistema de origem, mesmo sem chave fiscal.
    procedure InserirEmissao(const AReferenciaNota: String;
      const ANotaFiscal: TNotaFiscalRetornoEmissao);
    procedure AtualizarEmissao(const AReferenciaNota: String;
      const ANotaFiscal: TNotaFiscalRetornoEmissao);
    procedure InserirEvento(const ANotaFiscal: TNotaFiscalRetornoEvento);
    procedure AtualizarEvento(const ANotaFiscal: TNotaFiscalRetornoEvento);
  end;


implementation

end.
