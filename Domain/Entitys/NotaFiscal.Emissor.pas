unit NotaFiscal.Emissor;

interface

uses
  NotaFiscal.Types, NotaFiscal.Endereco;

type
  TNotaFiscalEmissor = class
  private
    FCNPJCPF, FIE, FIEST, FIM, FCNAE, FRazaoSocial, FNomeFantasia: String;
    FRegimeTributario: TRegimeTributario;
    FEndereco: TNotaFiscalEndereco;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Validar;
    property CNPJCPF: String read FCNPJCPF write FCNPJCPF;
    property IE: String read FIE write FIE;
    property IEST: String read FIEST write FIEST;
    property IM: String read FIM write FIM;
    property CNAE: String read FCNAE write FCNAE;
    property RazaoSocial: String read FRazaoSocial write FRazaoSocial;
    property NomeFantasia: String read FNomeFantasia write FNomeFantasia;
    property RegimeTributario: TRegimeTributario read FRegimeTributario write FRegimeTributario;
    property Endereco: TNotaFiscalEndereco read FEndereco;
  end;

implementation

uses
  NotaFiscal.Validacao;

constructor TNotaFiscalEmissor.Create;
begin
  inherited Create;
  FEndereco := TNotaFiscalEndereco.Create;
  FRegimeTributario := rtRegimeNormal;
end;

destructor TNotaFiscalEmissor.Destroy;
begin
  FEndereco.Free;
  inherited;
end;

procedure TNotaFiscalEmissor.Validar;
begin
  TValidacaoNotaFiscal.Documento(FCNPJCPF, 'CPF/CNPJ do emitente');
  TValidacaoNotaFiscal.Texto(FIE, 'IE do emitente', 14);
  TValidacaoNotaFiscal.Texto(FIEST, 'IE do substituto tributario', 14, False);
  TValidacaoNotaFiscal.Texto(FIM, 'IM do emitente', 15, False);
  TValidacaoNotaFiscal.Digitos(FCNAE, 'CNAE', 7, False);
  TValidacaoNotaFiscal.Texto(FRazaoSocial, 'Razao social do emitente', 60);
  TValidacaoNotaFiscal.Texto(FNomeFantasia, 'Nome fantasia', 60, False);
  TValidacaoNotaFiscal.Exigir((Ord(FRegimeTributario) >= 1) and
    (Ord(FRegimeTributario) <= 4), 'Regime tributario invalido.');
  FEndereco.Validar(True);
  TValidacaoNotaFiscal.Exigir(FEndereco.UF <> 'EX', 'Emitente deve estar no Brasil.');
end;

end.
