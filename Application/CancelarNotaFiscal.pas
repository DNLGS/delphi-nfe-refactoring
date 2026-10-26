unit CancelarNotaFiscal;

interface

uses EmissorNotaFiscal.Intf, NotaFiscal.RetornoEvento;

type
  TCancelarNotaFiscal = class
  private
    FEmissor : IEmissorNotaFiscal;
  public
    constructor Create(AEmissor : IEmissorNotaFiscal);
    function Cancelar(const AChave, AMotivo, AProtocoloAutorizacao : String) : TNotaFiscalRetornoEvento;
  end;

implementation

{ TCancelarNotaFiscal }

function TCancelarNotaFiscal.Cancelar(const AChave, AMotivo,
  AProtocoloAutorizacao: String): TNotaFiscalRetornoEvento;
begin
  Result := FEmissor.Cancelar(AChave, AMotivo, AProtocoloAutorizacao);
end;

constructor TCancelarNotaFiscal.Create(AEmissor: IEmissorNotaFiscal);
begin
  FEmissor := AEmissor;
end;

end.
