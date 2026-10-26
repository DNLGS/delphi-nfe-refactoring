unit NotaFiscal.Complementos;

interface

type
  TReferenciaECFNotaFiscal = record
    Modelo, NumeroECF, NumeroCOO: String;
    procedure Validar;
  end;

  TObservacaoNotaFiscal = record
    Campo, Texto: String;
    procedure Validar;
  end;

  TIntermediadorNotaFiscal = record
    CNPJ, IdentificacaoCadastro: String;
    procedure Validar(AObrigatorio: Boolean);
  end;

  TResponsavelTecnicoNotaFiscal = record
    Informado: Boolean;
    CNPJ, Contato, Email, Telefone, HashCSRT: String;
    IdCSRT: Integer;
    procedure Validar;
  end;

  TExportacaoNotaFiscal = record
    Informada: Boolean;
    UFSaidaPais, LocalExportacao, LocalDespacho: String;
    procedure Validar;
  end;

  TNotaFiscalComplementos = class
  public
    InformacoesFisco, InformacoesComplementares: String;
    Observacoes: TArray<TObservacaoNotaFiscal>;
    AutorizadosXML: TArray<String>;
    ReferenciasECF: TArray<TReferenciaECFNotaFiscal>;
    Intermediador: TIntermediadorNotaFiscal;
    ResponsavelTecnico: TResponsavelTecnicoNotaFiscal;
    Exportacao: TExportacaoNotaFiscal;
    procedure Validar(AComIntermediador: Boolean);
  end;

implementation

uses
  System.SysUtils, NotaFiscal.Validacao;

procedure TReferenciaECFNotaFiscal.Validar;
begin
  TValidacaoNotaFiscal.Exigir((Modelo = '2B') or (Modelo = '2C') or (Modelo = '2D'), 'Modelo ECF invalido.');
  TValidacaoNotaFiscal.Exigir((Length(NumeroECF) >= 1) and (Length(NumeroECF) <= 3), 'Numero ECF deve ter de 1 a 3 digitos.');
  TValidacaoNotaFiscal.Exigir((Length(NumeroCOO) >= 1) and (Length(NumeroCOO) <= 6), 'Numero COO deve ter de 1 a 6 digitos.');
  TValidacaoNotaFiscal.Digitos(NumeroECF, 'Numero do ECF', Length(NumeroECF));
  TValidacaoNotaFiscal.Digitos(NumeroCOO, 'Numero COO', Length(NumeroCOO));
end;

procedure TObservacaoNotaFiscal.Validar;
begin
  TValidacaoNotaFiscal.Texto(Campo, 'Identificacao da observacao', 20);
  TValidacaoNotaFiscal.Texto(Texto, 'Texto da observacao', 60);
end;

procedure TIntermediadorNotaFiscal.Validar(AObrigatorio: Boolean);
begin
  if not AObrigatorio then
  begin
    TValidacaoNotaFiscal.Exigir((CNPJ = '') and (IdentificacaoCadastro = ''), 'Dados de intermediador exigem indicador com intermediador.');
    Exit;
  end;
  TValidacaoNotaFiscal.Documento(CNPJ, 'CNPJ do intermediador');
  TValidacaoNotaFiscal.Exigir(Length(TValidacaoNotaFiscal.NormalizarDocumento(CNPJ)) = 14, 'Intermediador deve informar CNPJ.');
  TValidacaoNotaFiscal.Texto(IdentificacaoCadastro, 'Cadastro no intermediador', 60);
end;

procedure TResponsavelTecnicoNotaFiscal.Validar;
var
  I: Integer;
begin
  if not Informado then
    Exit;
  TValidacaoNotaFiscal.Documento(CNPJ, 'CNPJ do responsavel tecnico');
  TValidacaoNotaFiscal.Exigir(Length(TValidacaoNotaFiscal.NormalizarDocumento(CNPJ)) = 14, 'Responsavel tecnico deve informar CNPJ.');
  TValidacaoNotaFiscal.Texto(Contato, 'Contato do responsavel tecnico', 60);
  TValidacaoNotaFiscal.Email(Email, True);
  TValidacaoNotaFiscal.Exigir((Length(Telefone) >= 6) and (Length(Telefone) <= 14), 'Telefone do responsavel tecnico invalido.');
  TValidacaoNotaFiscal.Digitos(Telefone, 'Telefone do responsavel tecnico', Length(Telefone));
  if (IdCSRT <> 0) or (HashCSRT <> '') then
  begin
    TValidacaoNotaFiscal.Exigir((IdCSRT >= 1) and (IdCSRT <= 99), 'Identificador CSRT invalido.');
    TValidacaoNotaFiscal.Exigir(Length(HashCSRT) = 28, 'Hash CSRT deve ser SHA-1 em Base64 (28 caracteres).');
    for I := 1 to 27 do
      TValidacaoNotaFiscal.Exigir(CharInSet(HashCSRT[I], ['A'..'Z', 'a'..'z', '0'..'9', '+', '/']), 'Hash CSRT invalido.');
    TValidacaoNotaFiscal.Exigir(HashCSRT[28] = '=', 'Hash CSRT invalido.');
  end;
end;

procedure TExportacaoNotaFiscal.Validar;
begin
  if not Informada then
    Exit;
  TValidacaoNotaFiscal.CodigoUF(UFSaidaPais);
  TValidacaoNotaFiscal.Texto(LocalExportacao, 'Local de exportacao', 60);
  TValidacaoNotaFiscal.Texto(LocalDespacho, 'Local de despacho', 60, False);
end;

procedure TNotaFiscalComplementos.Validar(AComIntermediador: Boolean);
var
  I, J: Integer;
begin
  TValidacaoNotaFiscal.Texto(InformacoesFisco, 'Informacoes ao fisco', 2000, False);
  TValidacaoNotaFiscal.Texto(InformacoesComplementares, 'Informacoes complementares', 5000, False);
  TValidacaoNotaFiscal.Exigir(Length(Observacoes) <= 10, 'Limite de 10 observacoes do contribuinte.');
  TValidacaoNotaFiscal.Exigir(Length(AutorizadosXML) <= 10, 'Limite de 10 autorizados a obter XML.');
  for I := 0 to High(Observacoes) do
    Observacoes[I].Validar;
  for I := 0 to High(ReferenciasECF) do
    ReferenciasECF[I].Validar;
  for I := 0 to High(AutorizadosXML) do
  begin
    TValidacaoNotaFiscal.Documento(AutorizadosXML[I], 'CPF/CNPJ autorizado a obter XML');
    for J := 0 to I - 1 do
      TValidacaoNotaFiscal.Exigir(TValidacaoNotaFiscal.NormalizarDocumento(AutorizadosXML[I]) <>
        TValidacaoNotaFiscal.NormalizarDocumento(AutorizadosXML[J]), 'Autorizado XML repetido.');
  end;
  Intermediador.Validar(AComIntermediador);
  ResponsavelTecnico.Validar;
  Exportacao.Validar;
end;

end.
