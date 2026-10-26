unit ConsultarStatusServico;

interface

uses EmissorNotaFiscal.Intf, SefazStatus;

type
  TConsultarStatusServico = class
  private
    FEmissor : IEmissorNotaFiscal;
  public
    constructor Create(AEmissor : IEmissorNotaFiscal);
    function Consultar : TSefazStatus;
  end;

implementation

{ TConsultarStatusServico }

function TConsultarStatusServico.Consultar: TSefazStatus;
begin
  Result := FEmissor.StatusServico;
end;

constructor TConsultarStatusServico.Create(AEmissor: IEmissorNotaFiscal);
begin
  FEmissor := AEmissor;
end;

end.
