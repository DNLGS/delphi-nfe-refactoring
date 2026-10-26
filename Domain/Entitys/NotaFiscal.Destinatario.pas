unit NotaFiscal.Destinatario;

interface

uses
  NotaFiscal.Types, NotaFiscal.Endereco;

type
  TNotaFiscalDestinatario = class
  private
    FInformado: Boolean;
    FEnderecoInformado: Boolean;
    FCNPJCPF, FIdEstrangeiro, FNome, FIE, FISUF, FEmail: String;
    FIndicadorIE: TIndicadorIEDestinatario;
    FEndereco: TNotaFiscalEndereco;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Validar(AModelo: TModeloNotaFiscal);
    property Informado: Boolean read FInformado write FInformado;
    property EnderecoInformado: Boolean read FEnderecoInformado write FEnderecoInformado;
    property CNPJCPF: String read FCNPJCPF write FCNPJCPF;
    property IdEstrangeiro: String read FIdEstrangeiro write FIdEstrangeiro;
    property Nome: String read FNome write FNome;
    property IE: String read FIE write FIE;
    property ISUF: String read FISUF write FISUF;
    property Email: String read FEmail write FEmail;
    property IndicadorIE: TIndicadorIEDestinatario read FIndicadorIE write FIndicadorIE;
    property Endereco: TNotaFiscalEndereco read FEndereco;
  end;

implementation

uses
  NotaFiscal.Validacao;

constructor TNotaFiscalDestinatario.Create;
begin
  inherited Create;
  FIndicadorIE := ieNaoContribuinte;
  FEndereco := TNotaFiscalEndereco.Create;
end;

destructor TNotaFiscalDestinatario.Destroy;
begin
  FEndereco.Free;
  inherited;
end;

procedure TNotaFiscalDestinatario.Validar(AModelo: TModeloNotaFiscal);
begin
  TValidacaoNotaFiscal.Exigir(FInformado or (AModelo = mNFCe), 'Destinatario obrigatorio para NF-e.');
  if not FInformado then
    Exit;
  if FEndereco.UF = 'EX' then
  begin
    TValidacaoNotaFiscal.Exigir(FCNPJCPF = '', 'Destinatario estrangeiro nao deve informar CPF/CNPJ.');
    TValidacaoNotaFiscal.Texto(FIdEstrangeiro, 'Identificacao estrangeira', 20, False);
  end
  else
  begin
    TValidacaoNotaFiscal.Documento(FCNPJCPF, 'CPF/CNPJ do destinatario');
    TValidacaoNotaFiscal.Exigir(FIdEstrangeiro = '', 'Identificacao estrangeira apenas para exterior.');
  end;
  TValidacaoNotaFiscal.Exigir((FIndicadorIE = ieContribuinte) or
    (FIndicadorIE = ieIsento) or (FIndicadorIE = ieNaoContribuinte), 'Indicador de IE invalido.');
  TValidacaoNotaFiscal.Texto(FNome, 'Nome do destinatario', 60, AModelo = mNFE);
  TValidacaoNotaFiscal.Texto(FIE, 'IE do destinatario', 14, FIndicadorIE = ieContribuinte);
  if (FIndicadorIE = ieIsento) or (FEndereco.UF = 'EX') or (AModelo = mNFCe) then
    TValidacaoNotaFiscal.Exigir(FIE = '', 'IE nao permitida para este destinatario.');
  if (AModelo = mNFCe) or (FEndereco.UF = 'EX') then
    TValidacaoNotaFiscal.Exigir(FIndicadorIE = ieNaoContribuinte, 'Destinatario deve ser nao contribuinte.');
  TValidacaoNotaFiscal.Texto(FISUF, 'Inscricao SUFRAMA', 9, False);
  TValidacaoNotaFiscal.Email(FEmail);
  if (AModelo = mNFE) or FEnderecoInformado then
    FEndereco.Validar;
end;

end.
