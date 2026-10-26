unit EmissorNotaFiscal.Intf;

interface

uses SefazStatus, NotaFiscal, NotaFiscal.RetornoEmissao,
  NotaFiscal.RetornoEvento;

type
  IEmissorNotaFiscal = Interface
    ['{ECAA8E9D-C5C0-4F41-97D8-F733F5E33A67}']
    function StatusServico : TSefazStatus;
    function ConsultarPorChave(const AChave : String) : TNotaFiscalRetornoEmissao;
    function Emitir(const ANotaFiscal : TNotaFiscal) : TNotaFiscalRetornoEmissao;
    function EmitirPorXML(const AXML : String) : TNotaFiscalRetornoEmissao;
    function Cancelar(const AChave, AMotivo, AProtocoloAutorizacao : String) : TNotaFiscalRetornoEvento;
    function CartaCorrecao(const AChave, ACorrecao : String; ASequencia : Integer) : TNotaFiscalRetornoEvento;
  End;

implementation

end.
