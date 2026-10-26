unit EmitirNotaFiscal;

interface

uses EmissorNotaFiscal.Intf, NotaFiscal, NotaFiscal.RetornoEmissao;

type
  TEmitirNotaFiscal = class
  private
    FEmissor : IEmissorNotaFiscal;
  public
    constructor Create(AEmissor : IEmissorNotaFiscal);
    function Emitir(const ANotaFiscal : TNotaFiscal): TNotaFiscalRetornoEmissao;
    function EmitirPorXML(const AXML: String): TNotaFiscalRetornoEmissao;
  end;

implementation

{ TEmitirNotaFiscal }

constructor TEmitirNotaFiscal.Create(AEmissor: IEmissorNotaFiscal);
begin
  FEmissor := AEmissor;
end;

function TEmitirNotaFiscal.Emitir(
  const ANotaFiscal: TNotaFiscal): TNotaFiscalRetornoEmissao;
begin
  Result := FEmissor.Emitir(ANotaFiscal);
end;

function TEmitirNotaFiscal.EmitirPorXML(const AXML: String): TNotaFiscalRetornoEmissao;
begin
  Result := FEmissor.EmitirPorXML(AXML);
end;

end.
