unit NotaFiscal.Transporte;

interface

uses
  NotaFiscal.Types;

type
  TVolumeNotaFiscal = record
    Quantidade: Int64;
    Especie, Marca, Numeracao: String;
    PesoLiquido, PesoBruto: Double;
    procedure Validar;
  end;

  TNotaFiscalTransporte = class
  public
    ModalidadeFrete: TModalidadeFrete;
    CNPJCPF, Nome, IE, Endereco, Municipio, UF: String;
    Placa, UFPlaca, RNTC, CFOPRetencao, CodMunicipioRetencao: String;
    ValorServicoRetencao, BaseRetencao, ValorICMSRetido: Currency;
    AliquotaRetencao: Double;
    Volumes: TArray<TVolumeNotaFiscal>;
    constructor Create;
    procedure Validar;
  end;

implementation

uses
  System.SysUtils, NotaFiscal.Validacao;

procedure TVolumeNotaFiscal.Validar;
begin
  TValidacaoNotaFiscal.Exigir(Quantidade >= 0, 'Quantidade de volumes negativa.');
  TValidacaoNotaFiscal.Texto(Especie, 'Especie do volume', 60, False);
  TValidacaoNotaFiscal.Texto(Marca, 'Marca do volume', 60, False);
  TValidacaoNotaFiscal.Texto(Numeracao, 'Numeracao do volume', 60, False);
  TValidacaoNotaFiscal.Valores([PesoLiquido, PesoBruto], 'Peso do volume');
  if PesoBruto > 0 then
    TValidacaoNotaFiscal.Exigir(PesoLiquido <= PesoBruto, 'Peso liquido excede o peso bruto.');
end;

constructor TNotaFiscalTransporte.Create;
begin
  inherited Create;
  ModalidadeFrete := mfSemFrete;
end;

procedure TNotaFiscalTransporte.Validar;
var
  I: Integer;
  Volume: TVolumeNotaFiscal;
begin
  TValidacaoNotaFiscal.Exigir((Ord(ModalidadeFrete) <= 4) or
    (ModalidadeFrete = mfSemFrete), 'Modalidade de frete invalida.');
  TValidacaoNotaFiscal.Documento(CNPJCPF, 'CPF/CNPJ do transportador', False);
  TValidacaoNotaFiscal.Texto(Nome, 'Nome do transportador', 60, False);
  TValidacaoNotaFiscal.Texto(IE, 'IE do transportador', 14, False);
  TValidacaoNotaFiscal.Texto(Endereco, 'Endereco do transportador', 60, False);
  TValidacaoNotaFiscal.Texto(Municipio, 'Municipio do transportador', 60, False);
  if (UF <> '') and (UF <> 'EX') then
    TValidacaoNotaFiscal.CodigoUF(UF);
  TValidacaoNotaFiscal.Exigir((IE = '') or (UF <> ''), 'IE do transportador exige UF.');
  if Placa <> '' then
  begin
    TValidacaoNotaFiscal.Exigir(Length(Placa) in [6, 7], 'Placa deve ter 6 ou 7 caracteres sem separador.');
    for I := 1 to Length(Placa) do
      TValidacaoNotaFiscal.Exigir(CharInSet(Placa[I], ['0'..'9', 'A'..'Z']), 'Placa invalida.');
    if UFPlaca <> 'EX' then
      TValidacaoNotaFiscal.CodigoUF(UFPlaca);
  end
  else
    TValidacaoNotaFiscal.Exigir((UFPlaca = '') and (RNTC = ''), 'UF/RNTC do veiculo exigem placa.');
  TValidacaoNotaFiscal.Texto(RNTC, 'RNTC', 20, False);
  TValidacaoNotaFiscal.Valores([ValorServicoRetencao, BaseRetencao, ValorICMSRetido], 'Retencao ICMS do transporte');
  TValidacaoNotaFiscal.Percentual(AliquotaRetencao, 'Aliquota de retencao do transporte');
  if CFOPRetencao <> '' then
  begin
    TValidacaoNotaFiscal.Digitos(CFOPRetencao, 'CFOP de retencao do transporte', 4);
    TValidacaoNotaFiscal.Digitos(CodMunicipioRetencao, 'Municipio da retencao', 7);
  end
  else
    TValidacaoNotaFiscal.Exigir((CodMunicipioRetencao = '') and (ValorServicoRetencao = 0) and
      (BaseRetencao = 0) and (ValorICMSRetido = 0) and (AliquotaRetencao = 0), 'Dados de retencao do transporte exigem CFOP.');
  TValidacaoNotaFiscal.Exigir(Length(Volumes) <= 5000, 'Limite de 5000 volumes.');
  for Volume in Volumes do
    Volume.Validar;
end;

end.
