unit ConsultarNotaFiscal;

interface

uses EmissorNotaFiscal.Intf, NotaFiscal.RetornoEmissao;

type
  TConsultarNotaFiscal = class
  private
    FEmissor: IEmissorNotaFiscal;
  public
    constructor Create(AEmissor: IEmissorNotaFiscal);
    function Consultar(const AChave: String): TNotaFiscalRetornoEmissao;
  end;

implementation

constructor TConsultarNotaFiscal.Create(AEmissor: IEmissorNotaFiscal);
begin
  FEmissor := AEmissor;
end;

function TConsultarNotaFiscal.Consultar(const AChave: String): TNotaFiscalRetornoEmissao;
begin
  Result := FEmissor.ConsultarPorChave(AChave);
end;

end.
