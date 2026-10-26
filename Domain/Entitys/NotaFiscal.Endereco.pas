unit NotaFiscal.Endereco;

interface

type
  TNotaFiscalEndereco = class
  private
    FLogradouro, FNumero, FComplemento, FBairro, FCodMunicipio: String;
    FMunicipio, FUF, FCEP, FPais, FTelefone: String;
    FCodPais: Integer;
  public
    constructor Create;
    procedure Validar(AExigirCEP: Boolean = False);
    property Logradouro: String read FLogradouro write FLogradouro;
    property Numero: String read FNumero write FNumero;
    property Complemento: String read FComplemento write FComplemento;
    property Bairro: String read FBairro write FBairro;
    property CodMunicipio: String read FCodMunicipio write FCodMunicipio;
    property Municipio: String read FMunicipio write FMunicipio;
    property UF: String read FUF write FUF;
    property CEP: String read FCEP write FCEP;
    property CodPais: Integer read FCodPais write FCodPais;
    property Pais: String read FPais write FPais;
    property Telefone: String read FTelefone write FTelefone;
  end;

  TNotaFiscalLocalEntrega = class
  private
    FInformado: Boolean;
    FCNPJCPF, FNome: String;
    FEndereco: TNotaFiscalEndereco;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Validar;
    property Informado: Boolean read FInformado write FInformado;
    property CNPJCPF: String read FCNPJCPF write FCNPJCPF;
    property Nome: String read FNome write FNome;
    property Endereco: TNotaFiscalEndereco read FEndereco;
  end;

implementation

uses
  NotaFiscal.Validacao;

constructor TNotaFiscalEndereco.Create;
begin
  inherited Create;
  FCodPais := 1058;
  FPais := 'BRASIL';
end;

procedure TNotaFiscalEndereco.Validar(AExigirCEP: Boolean);
begin
  TValidacaoNotaFiscal.Texto(FLogradouro, 'Logradouro', 60);
  TValidacaoNotaFiscal.Texto(FNumero, 'Numero do endereco', 60);
  TValidacaoNotaFiscal.Texto(FComplemento, 'Complemento', 60, False);
  TValidacaoNotaFiscal.Texto(FBairro, 'Bairro', 60);
  TValidacaoNotaFiscal.Texto(FMunicipio, 'Municipio', 60);
  TValidacaoNotaFiscal.Municipio(FCodMunicipio, FUF);
  TValidacaoNotaFiscal.Exigir((FCodPais > 0) and (FCodPais <= 9999), 'Codigo do pais invalido.');
  TValidacaoNotaFiscal.Texto(FPais, 'Pais', 60);
  TValidacaoNotaFiscal.Exigir((FUF = 'EX') = (FCodPais <> 1058), 'Pais incompativel com a UF.');
  TValidacaoNotaFiscal.Digitos(FCEP, 'CEP', 8, AExigirCEP and (FUF <> 'EX'));
  if FTelefone <> '' then
  begin
    TValidacaoNotaFiscal.Exigir((Length(FTelefone) >= 6) and
      (Length(FTelefone) <= 14), 'Telefone deve ter entre 6 e 14 digitos.');
    TValidacaoNotaFiscal.Digitos(FTelefone, 'Telefone', Length(FTelefone));
  end;
end;

constructor TNotaFiscalLocalEntrega.Create;
begin
  inherited Create;
  FEndereco := TNotaFiscalEndereco.Create;
end;

destructor TNotaFiscalLocalEntrega.Destroy;
begin
  FEndereco.Free;
  inherited;
end;

procedure TNotaFiscalLocalEntrega.Validar;
begin
  if not FInformado then
    Exit;
  TValidacaoNotaFiscal.Documento(FCNPJCPF, 'CPF/CNPJ do local de entrega');
  TValidacaoNotaFiscal.Texto(FNome, 'Nome do local de entrega', 60, False);
  FEndereco.Validar;
end;

end.
