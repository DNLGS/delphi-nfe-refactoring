unit NotaFiscal.Validacao;

interface

uses
  System.SysUtils, System.Math;

type
  ENotaFiscalInvalida = class(EArgumentException);

  TValidacaoNotaFiscal = class
  public
    class procedure Exigir(ACondicao: Boolean; const AMensagem: String); static;
    class procedure Texto(const AValor, ACampo: String; AMaximo: Integer;
      AObrigatorio: Boolean = True); static;
    class procedure Digitos(const AValor, ACampo: String; ATamanho: Integer;
      AObrigatorio: Boolean = True); static;
    class procedure NaoNegativo(AValor: Extended; const ACampo: String); static;
    class procedure Percentual(AValor: Extended; const ACampo: String); static;
    class procedure Valores(const AValores: array of Extended; const ACampo: String); static;
    class procedure Percentuais(const AValores: array of Extended; const ACampo: String); static;
    class function NormalizarDocumento(const AValor: String): String; static;
    class procedure Documento(const AValor, ACampo: String;
      AObrigatorio: Boolean = True); static;
    class procedure Chave(const AValor: String); static;
    class function CodigoUF(const AUF: String): String; static;
    class procedure Municipio(const ACodigo, AUF: String); static;
    class procedure Email(const AValor: String; AObrigatorio: Boolean = False); static;
  end;

implementation

class procedure TValidacaoNotaFiscal.Exigir(ACondicao: Boolean;
  const AMensagem: String);
begin
  if not ACondicao then
    raise ENotaFiscalInvalida.Create(AMensagem);
end;

class procedure TValidacaoNotaFiscal.Texto(const AValor, ACampo: String;
  AMaximo: Integer; AObrigatorio: Boolean);
begin
  Exigir(not AObrigatorio or (Trim(AValor) <> ''), ACampo + ' obrigatorio.');
  Exigir(Length(AValor) <= AMaximo, ACampo + ' excede o tamanho permitido.');
end;

class procedure TValidacaoNotaFiscal.Digitos(const AValor, ACampo: String;
  ATamanho: Integer; AObrigatorio: Boolean);
var
  C: Char;
begin
  if (AValor = '') and not AObrigatorio then
    Exit;
  Exigir(Length(AValor) = ATamanho, ACampo + ': tamanho invalido.');
  for C in AValor do
    Exigir(CharInSet(C, ['0'..'9']), ACampo + ' deve conter somente numeros.');
end;

class procedure TValidacaoNotaFiscal.NaoNegativo(AValor: Extended;
  const ACampo: String);
begin
  Exigir(not IsNan(AValor) and not IsInfinite(AValor) and (AValor >= 0),
    ACampo + ' deve ser um numero finito nao negativo.');
end;

class procedure TValidacaoNotaFiscal.Percentual(AValor: Extended;
  const ACampo: String);
begin
  NaoNegativo(AValor, ACampo);
  Exigir(AValor <= 100, ACampo + ' nao pode exceder 100%.');
end;

class function TValidacaoNotaFiscal.NormalizarDocumento(
  const AValor: String): String;
var
  C: Char;
begin
  Result := '';
  for C in UpperCase(Trim(AValor)) do
    if not CharInSet(C, ['.', '/', '-', ' ']) then
      Result := Result + C;
end;

class procedure TValidacaoNotaFiscal.Valores(const AValores: array of Extended;
  const ACampo: String);
var
  Valor: Extended;
begin
  for Valor in AValores do
    NaoNegativo(Valor, ACampo);
end;

class procedure TValidacaoNotaFiscal.Percentuais(const AValores: array of Extended;
  const ACampo: String);
var
  Valor: Extended;
begin
  for Valor in AValores do
    Percentual(Valor, ACampo);
end;

function DigitoModulo11(const ABase: String; APesoMaximo: Integer): Integer;
var
  I, Peso, Soma: Integer;
begin
  Peso := 2;
  Soma := 0;
  for I := Length(ABase) downto 1 do
  begin
    Soma := Soma + (Ord(ABase[I]) - Ord('0')) * Peso;
    Inc(Peso);
    if Peso > APesoMaximo then
      Peso := 2;
  end;
  Result := 11 - Soma mod 11;
  if Result >= 10 then
    Result := 0;
end;

class procedure TValidacaoNotaFiscal.Documento(const AValor, ACampo: String;
  AObrigatorio: Boolean);
var
  S: String;
  I, D1, D2: Integer;
begin
  S := NormalizarDocumento(AValor);
  if (S = '') and not AObrigatorio then
    Exit;
  Exigir((Length(S) = 11) or (Length(S) = 14), ACampo + ': CPF/CNPJ invalido.');
  Exigir(S <> StringOfChar(S[1], Length(S)), ACampo + ': digitos repetidos.');
  if Length(S) = 11 then
  begin
    Digitos(S, ACampo, 11);
    D1 := DigitoModulo11(Copy(S, 1, 9), 10);
    D2 := DigitoModulo11(Copy(S, 1, 10), 11);
  end
  else
  begin
    // Receita Federal: no CNPJ alfanumerico cada caractere vale ASCII - 48.
    for I := 1 to 12 do
      Exigir(CharInSet(S[I], ['0'..'9', 'A'..'Z']), ACampo + ': CNPJ invalido.');
    Digitos(Copy(S, 13, 2), ACampo + ' DV', 2);
    D1 := DigitoModulo11(Copy(S, 1, 12), 9);
    D2 := DigitoModulo11(Copy(S, 1, 13), 9);
  end;
  Exigir((Ord(S[Length(S) - 1]) - Ord('0') = D1) and
    (Ord(S[Length(S)]) - Ord('0') = D2), ACampo + ': digito verificador invalido.');
end;

class procedure TValidacaoNotaFiscal.Chave(const AValor: String);
var
  I, Modelo, Mes: Integer;
  CUF: String;
begin
  Exigir(Length(AValor) = 44, 'Chave referenciada deve ter 44 caracteres.');
  Digitos(Copy(AValor, 1, 6), 'UF/ano/mes da chave', 6);
  Digitos(Copy(AValor, 19, 26), 'Parte numerica da chave', 26);
  for I := 1 to 43 do
  begin
    Exigir(CharInSet(AValor[I], ['0'..'9', 'A'..'Z']), 'Caractere invalido na chave.');
    if (I < 7) or (I > 18) then
      Exigir(CharInSet(AValor[I], ['0'..'9']), 'Letra fora do CNPJ da chave.');
  end;
  CUF := Copy(AValor, 1, 2);
  Exigir(Pos('|' + CUF + '|', '|11|12|13|14|15|16|17|21|22|23|24|25|26|27|28|29|31|32|33|35|41|42|43|50|51|52|53|') > 0,
    'UF invalida na chave.');
  Mes := StrToInt(Copy(AValor, 5, 2));
  Exigir((Mes >= 1) and (Mes <= 12), 'Mes invalido na chave.');
  Modelo := StrToInt(Copy(AValor, 21, 2));
  Exigir((Modelo = 55) or (Modelo = 65) or (Modelo = 59),
    'Referencia deve ser NF-e, NFC-e ou CF-e SAT.');
  Exigir(DigitoModulo11(Copy(AValor, 1, 43), 9) = Ord(AValor[44]) - Ord('0'),
    'Digito verificador invalido na chave.');
end;

class function TValidacaoNotaFiscal.CodigoUF(const AUF: String): String;
const
  UFs: array[0..26] of String = ('RO', 'AC', 'AM', 'RR', 'PA', 'AP', 'TO',
    'MA', 'PI', 'CE', 'RN', 'PB', 'PE', 'AL', 'SE', 'BA', 'MG', 'ES', 'RJ',
    'SP', 'PR', 'SC', 'RS', 'MS', 'MT', 'GO', 'DF');
  Codigos: array[0..26] of String = ('11', '12', '13', '14', '15', '16', '17',
    '21', '22', '23', '24', '25', '26', '27', '28', '29', '31', '32', '33',
    '35', '41', '42', '43', '50', '51', '52', '53');
var
  I: Integer;
begin
  Result := '';
  for I := Low(UFs) to High(UFs) do
    if AUF = UFs[I] then
      Exit(Codigos[I]);
  Exigir(False, 'UF brasileira invalida: ' + AUF + '.');
end;

class procedure TValidacaoNotaFiscal.Municipio(const ACodigo, AUF: String);
begin
  Digitos(ACodigo, 'Codigo do municipio', 7);
  if AUF = 'EX' then
    Exigir(ACodigo = '9999999', 'Municipio do exterior deve ser 9999999.')
  else
    Exigir(Copy(ACodigo, 1, 2) = CodigoUF(AUF), 'Municipio nao pertence a UF.');
end;

class procedure TValidacaoNotaFiscal.Email(const AValor: String;
  AObrigatorio: Boolean);
var
  P: Integer;
begin
  Texto(AValor, 'Email', 60, AObrigatorio);
  if AValor = '' then
    Exit;
  P := Pos('@', AValor);
  Exigir((P > 1) and (P < Length(AValor)) and (Pos(' ', AValor) = 0) and
    (Pos('@', Copy(AValor, P + 1, MaxInt)) = 0), 'Email invalido.');
end;

end.
