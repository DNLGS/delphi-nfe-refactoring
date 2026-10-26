unit CartaCorrecaoNotaFiscal;

interface

uses EmissorNotaFiscal.Intf, NotaFiscal.RetornoEvento;

type
  TCartaCorrecaoNotaFiscal = class
  private
    FEmissor : IEmissorNotaFiscal;
  public
    constructor Create(AEmissor : IEmissorNotaFiscal);
    function CartaCorrecao(const AChave, ACorrecao: String; ASequencia : Integer) : TNotaFiscalRetornoEvento;
  end;

implementation

{ TCartaCorrecaoNotaFiscal }

function TCartaCorrecaoNotaFiscal.CartaCorrecao(const AChave, ACorrecao: String;
  ASequencia: Integer): TNotaFiscalRetornoEvento;
begin
  Result := FEmissor.CartaCorrecao(AChave,ACorrecao, ASequencia);
end;

constructor TCartaCorrecaoNotaFiscal.Create(AEmissor: IEmissorNotaFiscal);
begin
  FEmissor := AEmissor;
end;

end.
