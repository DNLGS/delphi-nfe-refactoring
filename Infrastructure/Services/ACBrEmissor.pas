unit ACBrEmissor;

interface

uses
  EmissorNotaFiscal.Intf, SefazStatus, NotaFiscal.RetornoEmissao,
  NotaFiscal.RetornoEvento, NotaFiscal, NotaFiscal.Types, NotaFiscal.Item,
  ACBrNFe, ACBrNFe.Classes;

type
  TACBrEmissorConfig = record
    PathSalvar, PathSalvarEvento, PathSchemas: String;
    Timeout: Integer; // Milissegundos; zero usa 30000.
    UF: String;
    Ambiente: NotaFiscal.Types.TTipoAmbiente;
    Modelo: TModeloNotaFiscal; // Zero usa modelo 55 no status.
    ArquivoPFX, NumeroSerie, Senha, CSC, IdCSC, CSRT: String;
    VersaoQRCode: Integer; // Zero usa versao 3.
  end;

  TACBrEmissor = class(TInterfacedObject, IEmissorNotaFiscal)
  private
    FACBr: TACBrNFe;
    FConfig: TACBrEmissorConfig;
    procedure ConfigurarComponente;
    procedure Limpar;
    procedure PreencherNota(const ANota: TNotaFiscal);
    procedure PreencherItem(const AItem: TNotaFiscalItem; ADet: TDetCollectionItem);
    procedure PreencherComplementos(const ANota: TNotaFiscal; ANFe: TNFe);
    procedure LerEmissao(var ARetorno: TNotaFiscalRetornoEmissao;
      const AXMLAssinado: String);
    procedure LerEvento(var ARetorno: TNotaFiscalRetornoEvento);
    procedure LerConsulta(var ARetorno: TNotaFiscalRetornoEmissao);
    procedure ValidarNotaCarregada;
    function EmitirNotaCarregada(AAssinar, ATransmitir: Boolean): TNotaFiscalRetornoEmissao;
    function EnviarEvento(const AChave, ATexto, AProtocolo: String;
      ASequencia: Integer; ATipo: NotaFiscal.Types.TTipoEvento): TNotaFiscalRetornoEvento;
  protected
    property Componente: TACBrNFe read FACBr;
    // Substituicao da assinatura/transporte nos testes sem certificado/rede.
    procedure AssinarEValidar; virtual;
    procedure TransmitirNota; virtual;
    procedure TransmitirEvento; virtual;
    procedure ConsultarStatus; virtual;
    procedure ConsultarNota; virtual;
    procedure ValidarXMLAssinado; virtual;
    procedure SalvarDocumento(const AXML, ANome, APasta: String);
    procedure GravarTemporario(const ACaminho, AXML: String); virtual;
  public
    constructor Create(AConfig: TACBrEmissorConfig);
    destructor Destroy; override;
    function Cancelar(const AChave, AMotivo, AProtocoloAutorizacao: String): TNotaFiscalRetornoEvento;
    function CartaCorrecao(const AChave, ACorrecao: String;
      ASequencia: Integer): TNotaFiscalRetornoEvento;
    function Emitir(const ANotaFiscal: TNotaFiscal): TNotaFiscalRetornoEmissao;
    function StatusServico: TSefazStatus;
    function ConsultarPorChave(const AChave: String): TNotaFiscalRetornoEmissao;
    function EmitirPorXML(const AXML: String): TNotaFiscalRetornoEmissao;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils, System.DateUtils, Winapi.Windows,
  NotaFiscal.Validacao, NotaFiscal.Impostos, NotaFiscal.ProdutoEspecifico,
  NotaFiscal.Cobranca, NotaFiscal.Complementos, NotaFiscal.Transporte,
  ACBrDFe.Conversao, ACBrDFeSSL, ACBrDFeUtil, ACBrDFeComum.Proc, ACBrUtil.Strings,
  ACBrNFeNotasFiscais, ACBrNFeWebServices, ACBrNFe.RetConsSit, pcnConversaoNFe;

procedure ExigirConversao(AOk: Boolean; const ACampo: String);
begin
  TValidacaoNotaFiscal.Exigir(AOk, ACampo + ' nao suportado pelo ACBr instalado.');
end;

function DocumentoNormalizado(const ADocumento: String): String;
begin
  Result := TValidacaoNotaFiscal.NormalizarDocumento(ADocumento);
end;

function Diagnostico(E: Exception): String;
begin
  Result := E.ClassName + ': ' + E.Message;
end;

constructor TACBrEmissor.Create(AConfig: TACBrEmissorConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FConfig.UF := UpperCase(Trim(FConfig.UF));
  TValidacaoNotaFiscal.CodigoUF(FConfig.UF);
  TValidacaoNotaFiscal.Exigir((FConfig.Ambiente = NotaFiscal.Types.taProducao) or
    (FConfig.Ambiente = NotaFiscal.Types.taHomologacao), 'Ambiente obrigatorio: producao ou homologacao.');
  TValidacaoNotaFiscal.Exigir(FConfig.Timeout >= 0, 'Timeout nao pode ser negativo.');
  if FConfig.Timeout = 0 then FConfig.Timeout := 30000;
  if Ord(FConfig.Modelo) = 0 then FConfig.Modelo := mNFE;
  TValidacaoNotaFiscal.Exigir((FConfig.Modelo = mNFE) or (FConfig.Modelo = mNFCe), 'Modelo de status invalido.');
  if FConfig.VersaoQRCode = 0 then FConfig.VersaoQRCode := 3;
  TValidacaoNotaFiscal.Exigir((FConfig.VersaoQRCode = 2) or
    (FConfig.VersaoQRCode = 3), 'Versao do QR Code deve ser 2 ou 3.');
  TValidacaoNotaFiscal.Exigir((FConfig.ArquivoPFX = '') or
    (FConfig.NumeroSerie = ''), 'Informe arquivo PFX ou numero de serie, nunca ambos.');
  if FConfig.PathSalvarEvento = '' then FConfig.PathSalvarEvento := FConfig.PathSalvar;
  FACBr := TACBrNFe.Create(nil);
  ConfigurarComponente;
end;

destructor TACBrEmissor.Destroy;
begin
  FACBr.Free;
  inherited;
end;

procedure TACBrEmissor.ConfigurarComponente;
begin
  with FACBr.Configuracoes do
  begin
    Geral.SSLLib := libWinCrypt;
    Geral.SSLCryptLib := cryWinCrypt;
    Geral.SSLHttpLib := httpWinINet;
    Geral.SSLXmlSignLib := xsLibXml2;
    Geral.VersaoDF := ve400;
    Geral.ModeloDF := moNFe;
    if FConfig.Modelo = mNFCe then Geral.ModeloDF := moNFCe;
    Geral.FormaEmissao := ACBrDFe.Conversao.teNormal;
    Geral.Salvar := False;
    Geral.RetirarAcentos := False;
    if FConfig.VersaoQRCode = 2 then Geral.VersaoQRCode := veqr200
    else Geral.VersaoQRCode := veqr300;
    Geral.CSC := FConfig.CSC;
    Geral.IdCSC := FConfig.IdCSC;
    Certificados.ArquivoPFX := FConfig.ArquivoPFX;
    Certificados.NumeroSerie := FConfig.NumeroSerie;
    Certificados.Senha := AnsiString(FConfig.Senha);
    WebServices.UF := FConfig.UF;
    WebServices.Ambiente := StrToTipoAmbiente(IntToStr(Ord(FConfig.Ambiente)));
    WebServices.TimeOut := FConfig.Timeout;
    WebServices.Visualizar := False;
    WebServices.Salvar := False;
    WebServices.Tentativas := 1;
    Arquivos.PathSchemas := FConfig.PathSchemas;
    Arquivos.PathSalvar := FConfig.PathSalvar;
    Arquivos.PathNFe := FConfig.PathSalvar;
    Arquivos.PathEvento := FConfig.PathSalvarEvento;
    // O adaptador substitui o arquivo somente depois de concluir a escrita.
    Arquivos.Salvar := False;
    Arquivos.SalvarEvento := False;
    Arquivos.SalvarApenasNFeProcessadas := False;
    RespTec.IdCSRT := 0;
    RespTec.CSRT := '';
  end;
end;

procedure TACBrEmissor.Limpar;
begin
  FACBr.NotasFiscais.Clear;
  FACBr.EventoNFe.Evento.Clear;
  FACBr.WebServices.Enviar.Clear;
  FACBr.WebServices.Retorno.Clear;
  FACBr.WebServices.EnvEvento.Clear;
  FACBr.WebServices.StatusServico.Clear;
  FACBr.WebServices.Consulta.Clear;
  ConfigurarComponente;
end;

procedure TACBrEmissor.AssinarEValidar;
begin
  FACBr.NotasFiscais.Assinar;
  ValidarNotaCarregada;
end;

procedure TACBrEmissor.ValidarNotaCarregada;
var
  Regras: String;
begin
  FACBr.NotasFiscais.Validar;
  Regras := '';
  if not FACBr.NotasFiscais.ValidarRegrasdeNegocios(Regras) then
    raise ENotaFiscalInvalida.Create(Regras);
end;

procedure TACBrEmissor.ValidarXMLAssinado;
var
  Erros: String;
begin
  ValidarNotaCarregada;
  if not FACBr.NotasFiscais.VerificarAssinatura(Erros) then
    raise ENotaFiscalInvalida.Create('Assinatura do XML invalida: ' + Erros);
end;

procedure TACBrEmissor.TransmitirNota;
begin
  // A nota ja foi assinada, validada e salva: Enviar repetiria a assinatura.
  FACBr.WebServices.Envia('1', False, False);
end;

procedure TACBrEmissor.TransmitirEvento;
var
  DocumentoCertificado: String;
begin
  // A chave completa CPF com zeros; o XML do evento precisa do CPF com 11 digitos.
  DocumentoCertificado := DocumentoNormalizado(FACBr.SSL.CertCNPJ);
  if (Length(DocumentoCertificado) = 11) and
    (Copy(FACBr.EventoNFe.Evento[0].infEvento.chNFe, 7, 14) = '000' + DocumentoCertificado) then
    FACBr.EventoNFe.Evento[0].infEvento.CNPJ := DocumentoCertificado;
  FACBr.EnviarEvento(1);
end;

procedure TACBrEmissor.ConsultarStatus;
begin
  if not FACBr.WebServices.StatusServico.Executar then
    if FACBr.WebServices.StatusServico.cStat = 0 then
      raise Exception.Create(FACBr.WebServices.StatusServico.Msg);
end;

procedure TACBrEmissor.LerEmissao(var ARetorno: TNotaFiscalRetornoEmissao;
  const AXMLAssinado: String);
var
  N: ACBrNFeNotasFiscais.NotaFiscal;
  Processado: TProcDFe;
  Resposta: TRetConsSitNFe;
begin
  if FACBr.NotasFiscais.Count = 0 then Exit;

  N := FACBr.NotasFiscais[0];
  ARetorno.ChaveAcesso := N.NumID;
  ARetorno.Status := sePendente;
  if AXMLAssinado <> '' then ARetorno.Documento := AXMLAssinado
  else ARetorno.Documento := UTF8ToNativeString(AnsiString(N.XMLOriginal));
  with N.NFe.procNFe do
    if cStat <> 0 then
    begin
      ARetorno.CStat := cStat;
      ARetorno.Motivo := xMotivo;
      ARetorno.Protocolo := nProt;
      ARetorno.DtRecebimento := dhRecbto;
    end
    else
      with FACBr.WebServices.Enviar do
      begin
        ARetorno.CStat := cStat;
        ARetorno.Motivo := xMotivo;
        ARetorno.DtRecebimento := dhRecbto;
      end;
  case ARetorno.CStat of
    0: Exit;
    100, 120, 150:
    begin
      Resposta := TRetConsSitNFe.Create('4.00');
      try
        Resposta.XmlRetorno := FACBr.WebServices.Enviar.RetWS;
        if Resposta.LerXml and
          (Resposta.protNFe.tpAmb = FACBr.Configuracoes.WebServices.Ambiente) and
          (Resposta.protNFe.chDFe = ARetorno.ChaveAcesso) and
          (ARetorno.Protocolo <> '') and
          (N.NFe.procNFe.chDFe = ARetorno.ChaveAcesso) and
          (N.NFe.procNFe.tpAmb = FACBr.Configuracoes.WebServices.Ambiente) and
          (N.NFe.procNFe.XML_prot <> '') and (AXMLAssinado <> '') then
        begin
          // Preserva o XML enviado; XMLOriginal e reconvertido pelo ACBr no retorno.
          Processado := TProcDFe.Create('4.00', 'xmlns="http://www.portalfiscal.inf.br/nfe"', 'nfeProc', 'NFe');
          try
            Processado.XML_DFe := AXMLAssinado;
            Processado.XML_Prot := UTF8ToNativeString(AnsiString(N.NFe.procNFe.XML_prot));
            ARetorno.Documento := '<?xml version="1.0" encoding="UTF-8"?>' + Processado.GerarXML;
            ARetorno.Status := seAutorizada;
          finally
            Processado.Free;
          end;
        end
        else
        begin
          ARetorno.Status := seIndeterminada;
          ARetorno.ErroTecnico := 'Retorno de autorizacao incompleto; consulte a SEFAZ antes de reenviar.';
        end;
      finally
        Resposta.Free;
      end;
    end;
    103, 104, 105, 204, 539: ARetorno.Status := seIndeterminada;
  else
    ARetorno.Status := seRejeitada;
  end;
end;

procedure TACBrEmissor.ConsultarNota;
begin
  if not FACBr.WebServices.Consulta.Executar then
    if FACBr.WebServices.Consulta.cStat = 0 then
      raise Exception.Create(FACBr.WebServices.Consulta.Msg);
end;

procedure TACBrEmissor.LerConsulta(var ARetorno: TNotaFiscalRetornoEmissao);
var
  Retorno: TRetConsSitNFe;
begin
  ARetorno.Status := seIndeterminada;
  with FACBr.WebServices.Consulta do
  begin
    ARetorno.CStat := cStat;
    ARetorno.Motivo := XMotivo;
    ARetorno.Protocolo := Protocolo;
    ARetorno.DtRecebimento := DhRecbto;
    ARetorno.Documento := UTF8ToNativeString(AnsiString(RetWS));
  end;
  if ARetorno.CStat = 0 then
  begin
    ARetorno.ErroTecnico := 'Consulta sem resposta fiscal.';
    Exit;
  end;
  Retorno := TRetConsSitNFe.Create('4.00');
  try
    Retorno.XmlRetorno := FACBr.WebServices.Consulta.RetWS;
    TValidacaoNotaFiscal.Exigir(Retorno.LerXml, 'Resposta da consulta invalida.');
    if (Retorno.chNfe <> ARetorno.ChaveAcesso) or
      (Retorno.tpAmb <> FACBr.Configuracoes.WebServices.Ambiente) then
    begin
      ARetorno.ErroTecnico := 'Chave/ambiente da consulta nao correspondem ao solicitado.';
      Exit;
    end;
    if FACBr.CstatProcessado(ARetorno.CStat) then
    begin
      if (Retorno.protNFe.nProt = '') or
        (Retorno.protNFe.chDFe <> ARetorno.ChaveAcesso) or
        (Retorno.protNFe.tpAmb <> Retorno.tpAmb) or
        not FACBr.CstatProcessado(Retorno.protNFe.cStat) then
      begin
        ARetorno.ErroTecnico := 'Consulta com autorizacao incompleta.';
        Exit;
      end;
      ARetorno.Status := seAutorizada;
    end
    else if FACBr.CstatCancelada(ARetorno.CStat) then ARetorno.Status := seCancelada
    else if ARetorno.CStat = 217 then ARetorno.Status := sePendente
    else if (ARetorno.CStat <> 108) and (ARetorno.CStat <> 109) and
      (ARetorno.CStat <> 656) then ARetorno.Status := seRejeitada;
  finally
    Retorno.Free;
  end;
end;

function TACBrEmissor.ConsultarPorChave(const AChave: String): TNotaFiscalRetornoEmissao;
var
  ConsultaIniciada: Boolean;
begin
  Result := Default(TNotaFiscalRetornoEmissao);
  Result.Status := seRejeitada;
  Result.ChaveAcesso := AChave;
  ConsultaIniciada := False;
  try
    TValidacaoNotaFiscal.Chave(AChave);
    TValidacaoNotaFiscal.Exigir((Copy(AChave, 21, 2) = '55') or
      (Copy(AChave, 21, 2) = '65'), 'Consulta exige chave NF-e ou NFC-e.');
    TValidacaoNotaFiscal.Exigir(Copy(AChave, 1, 2) =
      TValidacaoNotaFiscal.CodigoUF(FConfig.UF), 'UF da chave difere da configuracao.');
    Limpar;
    if Copy(AChave, 21, 2) = '65' then FACBr.Configuracoes.Geral.ModeloDF := moNFCe;
    FACBr.Configuracoes.Geral.FormaEmissao := StrToTipoEmissao(Copy(AChave, 35, 1));
    FACBr.WebServices.Consulta.NFeChave := AChave;
    FACBr.WebServices.Consulta.ExtrairEventos := False;
    ConsultaIniciada := True;
    ConsultarNota;
    LerConsulta(Result);
  except
    on E: Exception do
    begin
      if ConsultaIniciada then
      begin
        Result.Status := seIndeterminada;
        try
          LerConsulta(Result);
        except
          on ELeitura: Exception do Result.ErroTecnico := Diagnostico(ELeitura);
        end;
      end;
      if Result.ErroTecnico = '' then Result.ErroTecnico := Diagnostico(E)
      else Result.ErroTecnico := Diagnostico(E) + sLineBreak + Result.ErroTecnico;
    end;
  end;
end;

procedure TACBrEmissor.GravarTemporario(const ACaminho, AXML: String);
begin
  TFile.WriteAllText(ACaminho, AXML, TEncoding.UTF8);
end;

procedure TACBrEmissor.SalvarDocumento(const AXML, ANome, APasta: String);
var
  Caminho, Temporario: String;
begin
  if Trim(APasta) = '' then
    raise EWriteError.Create('Pasta de XML nao informada.');
  if not ForceDirectories(APasta) then
    raise EWriteError.Create('Nao foi possivel criar a pasta de XML.');
  Caminho := TPath.Combine(APasta, ANome);
  if FileExists(Caminho) and (Pos('<nfeProc', AXML) = 0) and
    (Pos('<nfeProc', TFile.ReadAllText(Caminho, TEncoding.UTF8)) > 0) then
    raise EWriteError.Create('XML autorizado existente; consulte a SEFAZ antes de reenviar.');
  Temporario := Caminho + '.' + TPath.GetRandomFileName + '.tmp';
  try
    GravarTemporario(Temporario, AXML);
    if not MoveFileEx(PChar(Temporario), PChar(Caminho),
      MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
      RaiseLastOSError;
  finally
    if FileExists(Temporario) then System.SysUtils.DeleteFile(Temporario);
  end;
end;

function TACBrEmissor.Emitir(const ANotaFiscal: TNotaFiscal): TNotaFiscalRetornoEmissao;
var
  N: ACBrNFeNotasFiscais.NotaFiscal;
begin
  Result := Default(TNotaFiscalRetornoEmissao);
  Result.Status := seRejeitada;
  try
    TValidacaoNotaFiscal.Exigir(ANotaFiscal <> nil, 'Nota fiscal obrigatoria.');
    ANotaFiscal.Validar;
    TValidacaoNotaFiscal.Exigir(ANotaFiscal.NFConfiguracao.UF = FConfig.UF, 'UF da nota difere da configuracao.');
    TValidacaoNotaFiscal.Exigir(ANotaFiscal.NFConfiguracao.TipoAmbiente = FConfig.Ambiente, 'Ambiente da nota difere da configuracao.');
    TValidacaoNotaFiscal.Exigir(Trim(FConfig.PathSalvar) <> '', 'PathSalvar obrigatorio para emissao.');
    if (ANotaFiscal.Modelo = mNFCe) and (FConfig.VersaoQRCode = 2) then
      TValidacaoNotaFiscal.Exigir((FConfig.CSC <> '') and (FConfig.IdCSC <> ''), 'QR Code 2 exige CSC e IdCSC.');
    Limpar;
    PreencherNota(ANotaFiscal);
    N := FACBr.NotasFiscais[0];
    N.GerarXML;
    if ANotaFiscal.Complementos.ResponsavelTecnico.Informado and
      (ANotaFiscal.Complementos.ResponsavelTecnico.IdCSRT <> 0) then
      TValidacaoNotaFiscal.Exigir(CalcularHashCSRT(FConfig.CSRT, N.NumID) =
        ANotaFiscal.Complementos.ResponsavelTecnico.HashCSRT, 'HashCSRT difere do segredo/chave da nota.');
    Result := EmitirNotaCarregada(True,
      ANotaFiscal.NFConfiguracao.TipoEmissao <> temContingenciaOffline);
  except
    on E: Exception do Result.ErroTecnico := Diagnostico(E);
  end;
end;

function TACBrEmissor.EmitirPorXML(const AXML: String): TNotaFiscalRetornoEmissao;
var
  N: ACBrNFeNotasFiscais.NotaFiscal;
  Assinar: Boolean;
begin
  Result := Default(TNotaFiscalRetornoEmissao);
  Result.Status := seRejeitada;
  try
    TValidacaoNotaFiscal.Exigir(Trim(AXML) <> '', 'XML da nota obrigatorio.');
    TValidacaoNotaFiscal.Exigir(Trim(FConfig.PathSalvar) <> '', 'PathSalvar obrigatorio para emissao.');
    Limpar;
    TValidacaoNotaFiscal.Exigir(FACBr.NotasFiscais.LoadFromString(String(NativeStringToUTF8(AXML)), False) and
      (FACBr.NotasFiscais.Count = 1), 'Informe o XML de uma unica NF-e ou NFC-e.');
    N := FACBr.NotasFiscais[0];
    TValidacaoNotaFiscal.Exigir((N.NFe.Ide.modelo = 55) or (N.NFe.Ide.modelo = 65), 'XML deve ser NF-e ou NFC-e.');
    TValidacaoNotaFiscal.Exigir((N.NFe.procNFe.cStat = 0) and (Pos('<nfeProc', AXML) = 0) and
      (Pos('<procNFe', AXML) = 0), 'XML processado nao pode ser reenviado; consulte a SEFAZ.');
    TValidacaoNotaFiscal.Exigir(N.NFe.Ide.cUF = StrToInt(TValidacaoNotaFiscal.CodigoUF(FConfig.UF)), 'UF do XML difere da configuracao.');
    TValidacaoNotaFiscal.Exigir(N.NFe.Ide.tpAmb = FACBr.Configuracoes.WebServices.Ambiente, 'Ambiente do XML difere da configuracao.');
    TValidacaoNotaFiscal.Chave(N.NumID);
    FACBr.Configuracoes.Geral.ModeloDF := moNFe;
    if N.NFe.Ide.modelo = 65 then FACBr.Configuracoes.Geral.ModeloDF := moNFCe;
    FACBr.Configuracoes.Geral.FormaEmissao := N.NFe.Ide.tpEmis;
    Assinar := not XmlEstaAssinado(N.XMLOriginal);
    if Assinar and (N.NFe.Ide.modelo = 65) and (FConfig.VersaoQRCode = 2) then
      TValidacaoNotaFiscal.Exigir((FConfig.CSC <> '') and (FConfig.IdCSC <> ''), 'QR Code 2 exige CSC e IdCSC.');
    Result := EmitirNotaCarregada(Assinar, True);
  except
    on E: Exception do Result.ErroTecnico := Diagnostico(E);
  end;
end;

function TACBrEmissor.EmitirNotaCarregada(AAssinar, ATransmitir: Boolean): TNotaFiscalRetornoEmissao;
var
  N: ACBrNFeNotasFiscais.NotaFiscal;
  XMLAssinado, CaminhoXML: String;
  EnvioIniciado: Boolean;
begin
  Result := Default(TNotaFiscalRetornoEmissao);
  Result.Status := seRejeitada;
  XMLAssinado := '';
  EnvioIniciado := False;
  N := FACBr.NotasFiscais[0];
  try
    CaminhoXML := TPath.Combine(FConfig.PathSalvar, N.NumID + '-nfe.xml');
    if FileExists(CaminhoXML) and
      (Pos('<nfeProc', TFile.ReadAllText(CaminhoXML, TEncoding.UTF8)) > 0) then
    begin
      LerEmissao(Result, XMLAssinado);
      Result.Status := seIndeterminada;
      Result.ErroTecnico := 'XML autorizado existente; consulte a SEFAZ antes de reenviar.';
      Exit;
    end;
    if AAssinar then AssinarEValidar else ValidarXMLAssinado;
    XMLAssinado := UTF8ToNativeString(AnsiString(N.XMLAssinado));
    LerEmissao(Result, XMLAssinado);
    SalvarDocumento(Result.Documento, Result.ChaveAcesso + '-nfe.xml', FConfig.PathSalvar);
    if not ATransmitir then
    begin
      Result.Motivo := 'NFC-e em contingencia offline; pendente de autorizacao.';
      Exit;
    end;
    EnvioIniciado := True;
    TransmitirNota;
    LerEmissao(Result, XMLAssinado);
    if Result.CStat = 0 then
    begin
      Result.Status := seIndeterminada;
      Result.ErroTecnico := 'Envio sem resposta fiscal; consulte a SEFAZ antes de reenviar.';
      Exit;
    end;
    if (Result.CStat = 103) or (Result.CStat = 104) or (Result.CStat = 105) then
    begin
      Result.ErroTecnico := 'Resposta de lote sem resultado individual; consulte a SEFAZ antes de reenviar.';
      Exit;
    end;
    if Result.Status = seAutorizada then
      SalvarDocumento(Result.Documento, Result.ChaveAcesso + '-nfe.xml', FConfig.PathSalvar);
  except
    on E: Exception do
    begin
      try
        LerEmissao(Result, XMLAssinado);
      except
        on ELeitura: Exception do
          Result.ErroTecnico := 'Falha ao ler retorno: ' + Diagnostico(ELeitura);
      end;
      if Result.ErroTecnico = '' then
        Result.ErroTecnico := Diagnostico(E)
      else
        Result.ErroTecnico := Diagnostico(E) + sLineBreak + Result.ErroTecnico;
      if not EnvioIniciado then Result.Status := seRejeitada
      else if Result.CStat = 0 then Result.Status := seIndeterminada;
    end;
  end;
end;

function TACBrEmissor.Cancelar(const AChave, AMotivo,
  AProtocoloAutorizacao: String): TNotaFiscalRetornoEvento;
begin
  Result := EnviarEvento(AChave, Trim(AMotivo), AProtocoloAutorizacao, 1, NotaFiscal.Types.teCancelamento);
end;

function TACBrEmissor.CartaCorrecao(const AChave, ACorrecao: String;
  ASequencia: Integer): TNotaFiscalRetornoEvento;
begin
  Result := EnviarEvento(AChave, Trim(ACorrecao), '', ASequencia, teCartaCorrecao);
end;

function TACBrEmissor.EnviarEvento(const AChave, ATexto, AProtocolo: String;
  ASequencia: Integer; ATipo: NotaFiscal.Types.TTipoEvento): TNotaFiscalRetornoEvento;
var
  RecuperarRetorno: Boolean;
begin
  Result := Default(TNotaFiscalRetornoEvento);
  Result.Status := steRejeitado;
  Result.TipoEvento := ATipo;
  Result.Chave := AChave;
  Result.Sequencia := ASequencia;
  Result.Ambiente := FConfig.Ambiente;
  RecuperarRetorno := False;
  try
    TValidacaoNotaFiscal.Chave(AChave);
    TValidacaoNotaFiscal.Exigir((Copy(AChave, 21, 2) = '55') or
      (Copy(AChave, 21, 2) = '65'), 'Evento exige chave NF-e ou NFC-e.');
    TValidacaoNotaFiscal.Exigir(Copy(AChave, 1, 2) = TValidacaoNotaFiscal.CodigoUF(FConfig.UF), 'UF da chave difere da configuracao.');
    TValidacaoNotaFiscal.Exigir(Length(ATexto) >= 15, 'Texto do evento deve ter pelo menos 15 caracteres.');
    if ATipo = NotaFiscal.Types.teCancelamento then
    begin
      TValidacaoNotaFiscal.Texto(ATexto, 'Justificativa', 255);
      TValidacaoNotaFiscal.Exigir((Length(AProtocolo) = 15) or (Length(AProtocolo) = 17), 'Protocolo deve ter 15 ou 17 digitos.');
      TValidacaoNotaFiscal.Digitos(AProtocolo, 'Protocolo', Length(AProtocolo));
    end
    else
    begin
      TValidacaoNotaFiscal.Exigir(Copy(AChave, 21, 2) = '55', 'CC-e permitida somente para NF-e modelo 55.');
      TValidacaoNotaFiscal.Texto(ATexto, 'Correcao', 1000);
      TValidacaoNotaFiscal.Exigir((ASequencia >= 1) and (ASequencia <= 20), 'Sequencia CC-e deve estar entre 1 e 20.');
    end;
    Limpar;
    if Copy(AChave, 21, 2) = '65' then FACBr.Configuracoes.Geral.ModeloDF := moNFCe;
    with FACBr.EventoNFe.Evento.New.infEvento do
    begin
      chNFe := AChave;
      cOrgao := StrToInt(Copy(AChave, 1, 2));
      CNPJ := Copy(AChave, 7, 14);
      tpAmb := FACBr.Configuracoes.WebServices.Ambiente;
      dhEvento := Now;
      nSeqEvento := ASequencia;
      if ATipo = NotaFiscal.Types.teCancelamento then
      begin
        tpEvento := ACBrDFe.Conversao.teCancelamento;
        detEvento.nProt := AProtocolo;
        detEvento.xJust := ATexto;
      end
      else
      begin
        tpEvento := teCCe;
        detEvento.xCorrecao := ATexto;
      end;
    end;
    RecuperarRetorno := True;
    Result.Status := steIndeterminado;
    TransmitirEvento;
    LerEvento(Result);
    if (Result.Status = steRegistradoComVinculo) or
      (Result.Status = steRegistradoSemVinculo) then
      SalvarDocumento(Result.Documento,
        Copy(FACBr.EventoNFe.Evento[0].infEvento.Id, 3, MaxInt) + '-procEventoNFe.xml',
        FConfig.PathSalvarEvento);
  except
    on E: Exception do
    begin
      if RecuperarRetorno then
        try
          LerEvento(Result);
        except
          on ELeitura: Exception do
            Result.ErroTecnico := 'Falha ao ler retorno: ' + Diagnostico(ELeitura);
        end;
      if Result.ErroTecnico = '' then
        Result.ErroTecnico := Diagnostico(E)
      else
        Result.ErroTecnico := Diagnostico(E) + sLineBreak + Result.ErroTecnico;
    end;
  end;
end;

procedure TACBrEmissor.LerEvento(var ARetorno: TNotaFiscalRetornoEvento);
begin
  ARetorno.Status := steIndeterminado;
  with FACBr.WebServices.EnvEvento.EventoRetorno do
  begin
    if retEvento.Count <> 1 then
    begin
      ARetorno.CStat := cStat;
      ARetorno.Motivo := xMotivo;
      ARetorno.Documento := UTF8ToNativeString(AnsiString(XmlRetorno));
      if (retEvento.Count = 0) and (cStat >= 200) and
        (cStat <> 218) and (cStat <> 573) and (cStat <> 656) and (cStat <> 999) then
        ARetorno.Status := steRejeitado
      else if ARetorno.ErroTecnico = '' then
        ARetorno.ErroTecnico := 'Resposta sem retorno individual do evento; consulte antes de reenviar.';
      Exit;
    end;
    with retEvento[0].RetInfEvento do
    begin
      if (chNFe <> ARetorno.Chave) or
        (tpAmb <> FACBr.Configuracoes.WebServices.Ambiente) or
        (nSeqEvento <> FACBr.EventoNFe.Evento[0].infEvento.nSeqEvento) or
        (tpEvento <> FACBr.EventoNFe.Evento[0].infEvento.tpEvento) then
      begin
        ARetorno.ErroTecnico := 'Retorno individual nao corresponde ao evento enviado.';
        Exit;
      end;
      ARetorno.CStat := cStat;
      ARetorno.Motivo := xMotivo;
      ARetorno.Protocolo := nProt;
      if dhRegEvento > 0 then ARetorno.DtRegistro := DateToISO8601(dhRegEvento, False);
      ARetorno.Documento := UTF8ToNativeString(AnsiString(XML));
    end;
    if ARetorno.Documento = '' then ARetorno.Documento := UTF8ToNativeString(AnsiString(XmlRetorno));
  end;
  case ARetorno.CStat of
    135, 136, 155:
      if (ARetorno.Protocolo <> '') and
        (Pos('<procEventoNFe', ARetorno.Documento) > 0) then
      begin
        if ARetorno.CStat = 136 then ARetorno.Status := steRegistradoSemVinculo
        else ARetorno.Status := steRegistradoComVinculo;
      end
      else
        ARetorno.ErroTecnico := 'Registro do evento sem protocolo/XML processado; consulte antes de reenviar.';
    // Situacao anterior, duplicidade e falhas do servico exigem reconciliacao.
    0, 108, 109, 128, 218, 573, 656, 999:
      ARetorno.ErroTecnico := 'Resultado do evento indeterminado; consulte antes de reenviar.';
  else
    if ARetorno.CStat >= 200 then ARetorno.Status := steRejeitado
    else ARetorno.ErroTecnico := 'Resposta inesperada do evento; consulte antes de reenviar.';
  end;
end;

function TACBrEmissor.StatusServico: TSefazStatus;
var
  Erro: String;
begin
  Limpar;
  Erro := '';
  try
    ConsultarStatus;
    if FACBr.WebServices.StatusServico.cStat = 0 then
      raise Exception.Create('Consulta sem resposta fiscal.');
  except
    on E: Exception do Erro := Diagnostico(E);
  end;
  with FACBr.WebServices.StatusServico do
    Result := TSefazStatus.Create(cStat, xMotivo, FConfig.UF, dhRecbto,
      dhRetorno, verAplic, TMed, xObs, Erro);
end;


procedure TACBrEmissor.PreencherNota(const ANota: TNotaFiscal);
var
  N: TNFe;
  I: Integer;
  Ok: Boolean;
  Chave: String;
  Volume: TVolumeNotaFiscal;
  Pagamento: TPagamentoNotaFiscal;
  Duplicata: TDuplicataNotaFiscal;
begin
  if ANota.Modelo = mNFE then FACBr.Configuracoes.Geral.ModeloDF := moNFe
  else FACBr.Configuracoes.Geral.ModeloDF := moNFCe;
  FACBr.Configuracoes.Geral.FormaEmissao := StrToTipoEmissao(IntToStr(Ord(ANota.NFConfiguracao.TipoEmissao)));
  N := FACBr.NotasFiscais.Add.NFe;
  N.infNFe.Versao := 4;
  N.Ide.modelo := Ord(ANota.Modelo);
  N.Ide.cNF := ANota.CodigoNumerico;
  N.Ide.nNF := ANota.NroNota;
  N.Ide.serie := ANota.Serie;
  N.Ide.natOp := ANota.NaturezaOperacao;
  N.Ide.verProc := ANota.VersaoProcesso;
  N.Ide.dEmi := ANota.DtEmissao;
  N.Ide.dSaiEnt := ANota.DtSaidaEmissao;
  N.Ide.hSaiEnt := Frac(ANota.DtSaidaEmissao);
  N.Ide.cUF := StrToInt(TValidacaoNotaFiscal.CodigoUF(FConfig.UF));
  N.Ide.cMunFG := StrToInt(ANota.NFConfiguracao.CodMunicipio);
  N.Ide.tpAmb := FACBr.Configuracoes.WebServices.Ambiente;
  N.Ide.tpEmis := FACBr.Configuracoes.Geral.FormaEmissao;
  N.Ide.tpNF := StrToTpNF(IntToStr(Ord(ANota.NFConfiguracao.TipoNota)));
  N.Ide.procEmi := peAplicativoContribuinte;
  N.Ide.tpImp := tiRetrato;
  if ANota.Modelo = mNFCe then N.Ide.tpImp := tiNFCe;
  N.Ide.dhCont := ANota.NFConfiguracao.DtContingencia;
  N.Ide.xJust := ANota.NFConfiguracao.JustificativaContingencia;
  N.Ide.finNFe := StrToFinNFe(Ok, IntToStr(Ord(ANota.NFConfiguracao.TipoFinalidade)));
  ExigirConversao(Ok, 'finNFe');
  N.Ide.idDest := StrToDestinoOperacao(Ok, IntToStr(Ord(ANota.NFConfiguracao.DestinoOperacao)));
  ExigirConversao(Ok, 'idDest');
  N.Ide.indFinal := StrToConsumidorFinal(Ok, IntToStr(Ord(ANota.NFConfiguracao.ConsumidorFinal)));
  ExigirConversao(Ok, 'indFinal');
  N.Ide.indPres := StrToPresencaComprador(Ok, IntToStr(Ord(ANota.NFConfiguracao.PresencaConsumidor)));
  ExigirConversao(Ok, 'indPres');
  N.Ide.indIntermed := StrToIndIntermed(Ok, IntToStr(Ord(ANota.NFConfiguracao.Intermediador)));
  ExigirConversao(Ok, 'indIntermed');
  N.Ide.tpNFCredito := StrTotpNFCredito(ANota.TipoCredito);
  N.Ide.tpNFDebito := ACBrDFe.Conversao.StrTotpNFDebito(ANota.TipoDebito);
  for Chave in ANota.NFReferencia do N.Ide.NFref.New.refNFe := Chave;
  N.Emit.CNPJCPF := DocumentoNormalizado(ANota.Emitente.CNPJCPF);
  N.Emit.IE := ANota.Emitente.IE;
  N.Emit.IEST := ANota.Emitente.IEST;
  N.Emit.IM := ANota.Emitente.IM;
  N.Emit.CNAE := ANota.Emitente.CNAE;
  N.Emit.xNome := ANota.Emitente.RazaoSocial;
  N.Emit.xFant := ANota.Emitente.NomeFantasia;
  N.Emit.CRT := StrToCRT(Ok, IntToStr(Ord(ANota.Emitente.RegimeTributario)));
  ExigirConversao(Ok, 'CRT');
  N.Emit.EnderEmit.xLgr := ANota.Emitente.Endereco.Logradouro;
  N.Emit.EnderEmit.nro := ANota.Emitente.Endereco.Numero;
  N.Emit.EnderEmit.xCpl := ANota.Emitente.Endereco.Complemento;
  N.Emit.EnderEmit.xBairro := ANota.Emitente.Endereco.Bairro;
  N.Emit.EnderEmit.xMun := ANota.Emitente.Endereco.Municipio;
  N.Emit.EnderEmit.UF := ANota.Emitente.Endereco.UF;
  N.Emit.EnderEmit.cPais := ANota.Emitente.Endereco.CodPais;
  N.Emit.EnderEmit.xPais := ANota.Emitente.Endereco.Pais;
  N.Emit.EnderEmit.fone := ANota.Emitente.Endereco.Telefone;
  N.Emit.EnderEmit.cMun := StrToInt(ANota.Emitente.Endereco.CodMunicipio);
  N.Emit.EnderEmit.CEP := StrToIntDef(ANota.Emitente.Endereco.CEP, 0);
  if ANota.Destinatario.Informado then
  begin
    N.Dest.CNPJCPF := DocumentoNormalizado(ANota.Destinatario.CNPJCPF);
    N.Dest.idEstrangeiro := ANota.Destinatario.IdEstrangeiro;
    N.Dest.xNome := ANota.Destinatario.Nome;
    N.Dest.IE := ANota.Destinatario.IE;
    N.Dest.ISUF := ANota.Destinatario.ISUF;
    N.Dest.Email := ANota.Destinatario.Email;
    case ANota.Destinatario.IndicadorIE of
      ieContribuinte: N.Dest.indIEDest := inContribuinte;
      ieIsento: N.Dest.indIEDest := inIsento;
      ieNaoContribuinte: N.Dest.indIEDest := inNaoContribuinte;
    end;
    if (ANota.Modelo = mNFE) or ANota.Destinatario.EnderecoInformado then
    begin
  N.Dest.EnderDest.xLgr := ANota.Destinatario.Endereco.Logradouro;
  N.Dest.EnderDest.nro := ANota.Destinatario.Endereco.Numero;
  N.Dest.EnderDest.xCpl := ANota.Destinatario.Endereco.Complemento;
  N.Dest.EnderDest.xBairro := ANota.Destinatario.Endereco.Bairro;
  N.Dest.EnderDest.xMun := ANota.Destinatario.Endereco.Municipio;
  N.Dest.EnderDest.UF := ANota.Destinatario.Endereco.UF;
  N.Dest.EnderDest.cPais := ANota.Destinatario.Endereco.CodPais;
  N.Dest.EnderDest.xPais := ANota.Destinatario.Endereco.Pais;
  N.Dest.EnderDest.fone := ANota.Destinatario.Endereco.Telefone;
  N.Dest.EnderDest.cMun := StrToInt(ANota.Destinatario.Endereco.CodMunicipio);
  N.Dest.EnderDest.CEP := StrToIntDef(ANota.Destinatario.Endereco.CEP, 0);
    end;
  end;
  if ANota.Entrega.Informado then
  begin
    N.Entrega.CNPJCPF := DocumentoNormalizado(ANota.Entrega.CNPJCPF);
    N.Entrega.xNome := ANota.Entrega.Nome;
  N.Entrega.xLgr := ANota.Entrega.Endereco.Logradouro;
  N.Entrega.nro := ANota.Entrega.Endereco.Numero;
  N.Entrega.xCpl := ANota.Entrega.Endereco.Complemento;
  N.Entrega.xBairro := ANota.Entrega.Endereco.Bairro;
  N.Entrega.xMun := ANota.Entrega.Endereco.Municipio;
  N.Entrega.UF := ANota.Entrega.Endereco.UF;
  N.Entrega.cPais := ANota.Entrega.Endereco.CodPais;
  N.Entrega.xPais := ANota.Entrega.Endereco.Pais;
  N.Entrega.fone := ANota.Entrega.Endereco.Telefone;
  N.Entrega.cMun := StrToInt(ANota.Entrega.Endereco.CodMunicipio);
  N.Entrega.CEP := StrToIntDef(ANota.Entrega.Endereco.CEP, 0);
  end;
  for I := 0 to ANota.QuantidadeItens - 1 do PreencherItem(ANota.Itens[I], N.Det.New);
  N.Total.ICMSTot.vBC := ANota.Totais.BaseICMS;
  N.Total.ICMSTot.vICMS := ANota.Totais.ValorICMS;
  N.Total.ICMSTot.vBCST := ANota.Totais.BaseICMSST;
  N.Total.ICMSTot.vST := ANota.Totais.ValorICMSST;
  N.Total.ICMSTot.vFCPST := ANota.Totais.ValorFCPST;
  N.Total.ICMSTot.vFCPUFDest := ANota.Totais.ValorFCPDestino;
  N.Total.ICMSTot.vICMSUFDest := ANota.Totais.ValorICMSDestino;
  N.Total.ICMSTot.vICMSUFRemet := ANota.Totais.ValorICMSRemetente;
  N.Total.ICMSTot.vProd := ANota.Totais.ValorProdutos;
  N.Total.ICMSTot.vDesc := ANota.Totais.Desconto;
  N.Total.ICMSTot.vFrete := ANota.Totais.Frete;
  N.Total.ICMSTot.vSeg := ANota.Totais.Seguro;
  N.Total.ICMSTot.vOutro := ANota.Totais.OutrasDespesas;
  N.Total.ICMSTot.vPIS := ANota.Totais.ValorPIS;
  N.Total.ICMSTot.vCOFINS := ANota.Totais.ValorCOFINS;
  N.Total.ICMSTot.vIPI := ANota.Totais.ValorIPI;
  N.Total.ICMSTot.vNF := ANota.Totais.ValorNota;
  N.Total.ICMSTot.vTotTrib := ANota.Totais.ValorAproximadoTributos;
  N.Total.ISSQNtot.vServ := ANota.Totais.ValorServicos;
  N.Total.ISSQNtot.vBC := ANota.Totais.BaseISSQN;
  N.Total.ISSQNtot.vISS := ANota.Totais.ValorISSQN;
  N.Total.ISSQNtot.vPIS := ANota.Totais.ValorPISServicos;
  N.Total.ISSQNtot.vCOFINS := ANota.Totais.ValorCOFINSServicos;
  if ANota.Totais.ValorServicos <> 0 then N.Total.ISSQNtot.dCompet := ANota.DtEmissao;
  N.Total.retTrib.vBCIRRF := ANota.Totais.BaseIRRF;
  N.Total.retTrib.vIRRF := ANota.Totais.ValorIRRF;
  N.Total.IBSCBSTot.vBCIBSCBS := ANota.Totais.BaseIBSCBS;
  N.Total.IBSCBSTot.gIBS.vIBS := ANota.Totais.ValorIBS;
  N.Total.IBSCBSTot.gIBS.gIBSUFTot.vIBSUF := ANota.Totais.ValorIBSUF;
  N.Total.IBSCBSTot.gIBS.gIBSMunTot.vIBSMun := ANota.Totais.ValorIBSMunicipio;
  N.Total.IBSCBSTot.gCBS.vCBS := ANota.Totais.ValorCBS;
  N.Transp.modFrete := StrTomodFrete(Ok, IntToStr(Ord(ANota.Transporte.ModalidadeFrete)));
  ExigirConversao(Ok, 'Modalidade de frete');
  N.Transp.Transporta.CNPJCPF := DocumentoNormalizado(ANota.Transporte.CNPJCPF);
  N.Transp.Transporta.xNome := ANota.Transporte.Nome;
  N.Transp.Transporta.IE := ANota.Transporte.IE;
  N.Transp.Transporta.xEnder := ANota.Transporte.Endereco;
  N.Transp.Transporta.xMun := ANota.Transporte.Municipio;
  N.Transp.Transporta.UF := ANota.Transporte.UF;
  N.Transp.veicTransp.placa := ANota.Transporte.Placa;
  N.Transp.veicTransp.UF := ANota.Transporte.UFPlaca;
  N.Transp.veicTransp.RNTC := ANota.Transporte.RNTC;
  N.Transp.retTransp.vServ := ANota.Transporte.ValorServicoRetencao;
  N.Transp.retTransp.vBCRet := ANota.Transporte.BaseRetencao;
  N.Transp.retTransp.pICMSRet := ANota.Transporte.AliquotaRetencao;
  N.Transp.retTransp.vICMSRet := ANota.Transporte.ValorICMSRetido;
  N.Transp.retTransp.CFOP := ANota.Transporte.CFOPRetencao;
  N.Transp.retTransp.cMunFG := StrToIntDef(ANota.Transporte.CodMunicipioRetencao, 0);
  for Volume in ANota.Transporte.Volumes do
    with N.Transp.Vol.New do
    begin
      qVol := Volume.Quantidade;
      esp := Volume.Especie;
      marca := Volume.Marca;
      nVol := Volume.Numeracao;
      pesoL := Volume.PesoLiquido;
      pesoB := Volume.PesoBruto;
    end;
  if ANota.Cobranca.Fatura.Informada then
  begin
    N.Cobr.Fat.nFat := ANota.Cobranca.Fatura.Numero;
    N.Cobr.Fat.vOrig := ANota.Cobranca.Fatura.ValorOriginal;
    N.Cobr.Fat.vDesc := ANota.Cobranca.Fatura.Desconto;
    N.Cobr.Fat.vLiq := ANota.Cobranca.Fatura.ValorLiquido;
  end;
  for Duplicata in ANota.Cobranca.Duplicatas do
    with N.Cobr.Dup.New do
    begin
      nDup := Duplicata.Numero;
      dVenc := Duplicata.Vencimento;
      vDup := Duplicata.Valor;
    end;
  N.pag.vTroco := ANota.Cobranca.Troco;
  for Pagamento in ANota.Cobranca.Pagamentos do
    with N.pag.New do
    begin
      indPag := StrToIndpagEX(IntToStr(Ord(Pagamento.Indicador)));
      tPag := StrToFormaPagamento(Ok, Pagamento.Meio);
      ExigirConversao(Ok, 'Meio de pagamento');
      xPag := Pagamento.Descricao;
      vPag := Pagamento.Valor;
      case Pagamento.Integracao of
        itNaoInformada: tpIntegra := tiNaoInformado;
        itIntegrado: tpIntegra := tiPagIntegrado;
        itNaoIntegrado: tpIntegra := tiPagNaoIntegrado;
      end;
      CNPJ := DocumentoNormalizado(Pagamento.CNPJInstituicao);
      if Pagamento.BandeiraCartao <> '' then
      begin
        tBand := StrToBandeiraCartao(Ok, Pagamento.BandeiraCartao);
        ExigirConversao(Ok, 'Bandeira do cartao');
      end;
      cAut := Pagamento.Autorizacao;
    end;
  PreencherComplementos(ANota, N);
end;

procedure TACBrEmissor.PreencherItem(const AItem: TNotaFiscalItem; ADet: TDetCollectionItem);
var
  Ok: Boolean;
  Origem: TOrigemMercadoria;
  CSTICMS: TCSTIcms;
  CSOSN: TCSOSNIcms;
  CSTPIS: TCSTPis;
  CSTCOFINS: TCSTCofins;
  CSTIBS: TCSTIBSCBS;
  Lote: TLoteNotaFiscal;
  Importacao: TImportacaoNotaFiscal;
  Adicao: TAdicaoImportacaoNotaFiscal;
  DI: TDICollectionItem;
begin
  ADet.Prod.nItem := AItem.Numero;
  ADet.Prod.cProd := AItem.CodigoProduto;
  ADet.Prod.xProd := AItem.Descricao;
  ADet.Prod.NCM := AItem.NCM;
  ADet.Prod.CEST := AItem.CEST;
  ADet.Prod.EXTIPI := AItem.EXTIPI;
  ADet.Prod.CFOP := AItem.CFOP;
  ADet.Prod.cBenef := AItem.CodigoBeneficio;
  ADet.Prod.cEAN := AItem.GTIN;
  ADet.Prod.cEANTrib := AItem.GTINTributavel;
  ADet.Prod.uCom := AItem.Unidade;
  ADet.Prod.uTrib := AItem.UnidadeTributavel;
  ADet.Prod.qCom := AItem.Quantidade;
  ADet.Prod.qTrib := AItem.QuantidadeTributavel;
  ADet.Prod.vUnCom := AItem.ValorUnitario;
  ADet.Prod.vUnTrib := AItem.ValorUnitarioTributavel;
  ADet.Prod.vProd := AItem.ValorProdutos;
  ADet.Prod.vDesc := AItem.Desconto;
  ADet.Prod.vFrete := AItem.Frete;
  ADet.Prod.vSeg := AItem.Seguro;
  ADet.Prod.vOutro := AItem.OutrasDespesas;
  ADet.Prod.xPed := AItem.Pedido;
  if AItem.CompoeTotal then ADet.Prod.IndTot := itSomaTotalNFe
  else ADet.Prod.IndTot := itNaoSomaTotalNFe;
  if AItem.ItemPedido <> 0 then ADet.Prod.nItemPed := IntToStr(AItem.ItemPedido);
  ADet.infAdProd := AItem.InformacoesAdicionais;
  ADet.Imposto.vTotTrib := AItem.Impostos.ValorAproximadoTributos;
  if not AItem.Impostos.ISSQN.Informado then
  begin
    ExigirConversao(TryStrToOrig(IntToStr(AItem.Impostos.ICMS.Origem), Origem), 'Origem');
    ADet.Imposto.ICMS.orig := Origem;
    if AItem.Impostos.ICMS.CST <> '' then
    begin
      ExigirConversao(TryStrToCSTICMS(AItem.Impostos.ICMS.CST, CSTICMS), 'CST ICMS');
      ADet.Imposto.ICMS.CST := CSTICMS;
    end;
    if AItem.Impostos.ICMS.CSOSN <> '' then
    begin
      ExigirConversao(TryStrToCSOSNIcms(AItem.Impostos.ICMS.CSOSN, CSOSN), 'CSOSN');
      ADet.Imposto.ICMS.CSOSN := CSOSN;
    end;
    ADet.Imposto.ICMS.modBC := StrTomodBC(Ok, IntToStr(AItem.Impostos.ICMS.ModalidadeBase));
    ExigirConversao(Ok, 'Modalidade da base ICMS');
    ADet.Imposto.ICMS.modBCST := StrTomodBCST(Ok, IntToStr(AItem.Impostos.ICMS.ModalidadeBaseST));
    ExigirConversao(Ok, 'Modalidade da base ST');
    ADet.Imposto.ICMS.vBC := AItem.Impostos.ICMS.BaseCalculo;
    ADet.Imposto.ICMS.vICMS := AItem.Impostos.ICMS.Valor;
    ADet.Imposto.ICMS.vBCST := AItem.Impostos.ICMS.BaseST;
    ADet.Imposto.ICMS.vICMSST := AItem.Impostos.ICMS.ValorST;
    ADet.Imposto.ICMS.vBCFCPST := AItem.Impostos.ICMS.BaseFCPST;
    ADet.Imposto.ICMS.vFCPST := AItem.Impostos.ICMS.ValorFCPST;
    ADet.Imposto.ICMS.vCredICMSSN := AItem.Impostos.ICMS.ValorCreditoSN;
    ADet.Imposto.ICMS.pICMS := AItem.Impostos.ICMS.Aliquota;
    ADet.Imposto.ICMS.pICMSST := AItem.Impostos.ICMS.AliquotaST;
    ADet.Imposto.ICMS.pMVAST := AItem.Impostos.ICMS.MargemValorAdicionadoST;
    ADet.Imposto.ICMS.pRedBC := AItem.Impostos.ICMS.ReducaoBase;
    ADet.Imposto.ICMS.pFCPST := AItem.Impostos.ICMS.AliquotaFCPST;
    ADet.Imposto.ICMS.pCredSN := AItem.Impostos.ICMS.AliquotaCreditoSN;
    if (AItem.Impostos.ICMS.CST = '60') or (AItem.Impostos.ICMS.CSOSN = '500') then
    begin
      ADet.Imposto.ICMS.vBCSTRet := AItem.Impostos.ICMS.BaseST;
      ADet.Imposto.ICMS.vICMSSTRet := AItem.Impostos.ICMS.ValorST;
      ADet.Imposto.ICMS.vBCFCPSTRet := AItem.Impostos.ICMS.BaseFCPST;
      ADet.Imposto.ICMS.pFCPSTRet := AItem.Impostos.ICMS.AliquotaFCPST;
      ADet.Imposto.ICMS.vFCPSTRet := AItem.Impostos.ICMS.ValorFCPST;
    end;
  end;
  if AItem.Impostos.PIS.CST <> '' then
  begin
    ExigirConversao(TryStrToCSTPIS(AItem.Impostos.PIS.CST, CSTPIS), 'CST PIS');
    ADet.Imposto.PIS.CST := CSTPIS;
    ADet.Imposto.PIS.vBC := AItem.Impostos.PIS.BaseCalculo;
    ADet.Imposto.PIS.vPIS := AItem.Impostos.PIS.Valor;
    ADet.Imposto.PIS.pPIS := AItem.Impostos.PIS.Aliquota;
    ADet.Imposto.PIS.qBCProd := AItem.Impostos.PIS.QuantidadeBase;
    ADet.Imposto.PIS.vAliqProd := AItem.Impostos.PIS.AliquotaUnitaria;
  end;
  if AItem.Impostos.COFINS.CST <> '' then
  begin
    ExigirConversao(TryStrToCSTCOFINS(AItem.Impostos.COFINS.CST, CSTCOFINS), 'CST COFINS');
    ADet.Imposto.COFINS.CST := CSTCOFINS;
    ADet.Imposto.COFINS.vBC := AItem.Impostos.COFINS.BaseCalculo;
    ADet.Imposto.COFINS.vCOFINS := AItem.Impostos.COFINS.Valor;
    ADet.Imposto.COFINS.pCOFINS := AItem.Impostos.COFINS.Aliquota;
    ADet.Imposto.COFINS.qBCProd := AItem.Impostos.COFINS.QuantidadeBase;
    ADet.Imposto.COFINS.vAliqProd := AItem.Impostos.COFINS.AliquotaUnitaria;
  end;
  if AItem.Impostos.PISST.Informado then
  begin
    ADet.Imposto.PISST.vBC := AItem.Impostos.PISST.BaseCalculo;
    ADet.Imposto.PISST.vPIS := AItem.Impostos.PISST.Valor;
    ADet.Imposto.PISST.pPIS := AItem.Impostos.PISST.Aliquota;
    ADet.Imposto.PISST.qBCProd := AItem.Impostos.PISST.QuantidadeBase;
    ADet.Imposto.PISST.vAliqProd := AItem.Impostos.PISST.AliquotaUnitaria;
  end;
  if AItem.Impostos.COFINSST.Informado then
  begin
    ADet.Imposto.COFINSST.vBC := AItem.Impostos.COFINSST.BaseCalculo;
    ADet.Imposto.COFINSST.vCOFINS := AItem.Impostos.COFINSST.Valor;
    ADet.Imposto.COFINSST.pCOFINS := AItem.Impostos.COFINSST.Aliquota;
    ADet.Imposto.COFINSST.qBCProd := AItem.Impostos.COFINSST.QuantidadeBase;
    ADet.Imposto.COFINSST.vAliqProd := AItem.Impostos.COFINSST.AliquotaUnitaria;
  end;
  if AItem.Impostos.IPI.Informado then
  begin
    ADet.Imposto.IPI.CST := StrToCSTIPI(Ok, AItem.Impostos.IPI.CST);
    ExigirConversao(Ok, 'CST IPI');
    ADet.Imposto.IPI.cEnq := AItem.Impostos.IPI.Enquadramento;
    ADet.Imposto.IPI.vBC := AItem.Impostos.IPI.BaseCalculo;
    ADet.Imposto.IPI.vIPI := AItem.Impostos.IPI.Valor;
    ADet.Imposto.IPI.pIPI := AItem.Impostos.IPI.Aliquota;
    ADet.Imposto.IPI.qUnid := AItem.Impostos.IPI.Quantidade;
    ADet.Imposto.IPI.vUnid := AItem.Impostos.IPI.ValorUnidade;
  end;
  if AItem.Impostos.ISSQN.Informado then
  begin
    ADet.Imposto.ISSQN.vBC := AItem.Impostos.ISSQN.BaseCalculo;
    ADet.Imposto.ISSQN.vISSQN := AItem.Impostos.ISSQN.Valor;
    ADet.Imposto.ISSQN.vAliq := AItem.Impostos.ISSQN.Aliquota;
    ADet.Imposto.ISSQN.cListServ := AItem.Impostos.ISSQN.ListaServico;
    ADet.Imposto.ISSQN.cMunFG := StrToInt(AItem.Impostos.ISSQN.CodMunicipio);
    if AItem.Impostos.ISSQN.SituacaoTributaria <> '' then
    begin
      ADet.Imposto.ISSQN.cSitTrib := StrToISSQNcSitTrib(Ok, AItem.Impostos.ISSQN.SituacaoTributaria);
      ExigirConversao(Ok, 'Situacao tributaria ISSQN');
    end;
  end;
  if AItem.Impostos.DIFAL.Informado then
  begin
    ADet.Imposto.ICMSUFDest.vBCUFDest := AItem.Impostos.DIFAL.BaseCalculo;
    ADet.Imposto.ICMSUFDest.vBCFCPUFDest := AItem.Impostos.DIFAL.BaseFCP;
    ADet.Imposto.ICMSUFDest.vFCPUFDest := AItem.Impostos.DIFAL.ValorFCP;
    ADet.Imposto.ICMSUFDest.vICMSUFDest := AItem.Impostos.DIFAL.ValorDestino;
    ADet.Imposto.ICMSUFDest.vICMSUFRemet := AItem.Impostos.DIFAL.ValorRemetente;
    ADet.Imposto.ICMSUFDest.pFCPUFDest := AItem.Impostos.DIFAL.AliquotaFCP;
    ADet.Imposto.ICMSUFDest.pICMSUFDest := AItem.Impostos.DIFAL.AliquotaDestino;
    ADet.Imposto.ICMSUFDest.pICMSInter := AItem.Impostos.DIFAL.AliquotaInterestadual;
    ADet.Imposto.ICMSUFDest.pICMSInterPart := AItem.Impostos.DIFAL.PartilhaDestino;
  end;
  if AItem.Impostos.IBSCBS.Informado then
  begin
    ExigirConversao(TryStrToCSTIBSCBS(AItem.Impostos.IBSCBS.CST, CSTIBS), 'CST IBS/CBS');
    ADet.Imposto.IBSCBS.CST := CSTIBS;
    ADet.Imposto.IBSCBS.cClassTrib := AItem.Impostos.IBSCBS.ClassificacaoTributaria;
    ADet.Imposto.IBSCBS.gIBSCBS.vBC := AItem.Impostos.IBSCBS.BaseCalculo;
    ADet.Imposto.IBSCBS.gIBSCBS.vIBS := AItem.Impostos.IBSCBS.ValorIBS;
    ADet.Imposto.IBSCBS.gIBSCBS.gIBSUF.pIBSUF := AItem.Impostos.IBSCBS.IBSUF.Aliquota;
    ADet.Imposto.IBSCBS.gIBSCBS.gIBSUF.vIBSUF := AItem.Impostos.IBSCBS.IBSUF.Valor;
    ADet.Imposto.IBSCBS.gIBSCBS.gIBSUF.gRed.pRedAliq := AItem.Impostos.IBSCBS.IBSUF.ReducaoAliquota;
    ADet.Imposto.IBSCBS.gIBSCBS.gIBSUF.gRed.pAliqEfet := AItem.Impostos.IBSCBS.IBSUF.AliquotaEfetiva;
    ADet.Imposto.IBSCBS.gIBSCBS.gIBSMun.pIBSMun := AItem.Impostos.IBSCBS.IBSMunicipio.Aliquota;
    ADet.Imposto.IBSCBS.gIBSCBS.gIBSMun.vIBSMun := AItem.Impostos.IBSCBS.IBSMunicipio.Valor;
    ADet.Imposto.IBSCBS.gIBSCBS.gIBSMun.gRed.pRedAliq := AItem.Impostos.IBSCBS.IBSMunicipio.ReducaoAliquota;
    ADet.Imposto.IBSCBS.gIBSCBS.gIBSMun.gRed.pAliqEfet := AItem.Impostos.IBSCBS.IBSMunicipio.AliquotaEfetiva;
    ADet.Imposto.IBSCBS.gIBSCBS.gCBS.pCBS := AItem.Impostos.IBSCBS.CBS.Aliquota;
    ADet.Imposto.IBSCBS.gIBSCBS.gCBS.vCBS := AItem.Impostos.IBSCBS.CBS.Valor;
    ADet.Imposto.IBSCBS.gIBSCBS.gCBS.gRed.pRedAliq := AItem.Impostos.IBSCBS.CBS.ReducaoAliquota;
    ADet.Imposto.IBSCBS.gIBSCBS.gCBS.gRed.pAliqEfet := AItem.Impostos.IBSCBS.CBS.AliquotaEfetiva;
    if AItem.Impostos.IBSCBS.TributacaoRegular.Informado then
    begin
      ExigirConversao(TryStrToCSTIBSCBS(AItem.Impostos.IBSCBS.TributacaoRegular.CST, CSTIBS), 'CST regular IBS/CBS');
      ADet.Imposto.IBSCBS.gIBSCBS.gTribRegular.CSTReg := CSTIBS;
      ADet.Imposto.IBSCBS.gIBSCBS.gTribRegular.cClassTribReg := AItem.Impostos.IBSCBS.TributacaoRegular.ClassificacaoTributaria;
      ADet.Imposto.IBSCBS.gIBSCBS.gTribRegular.pAliqEfetRegIBSUF := AItem.Impostos.IBSCBS.TributacaoRegular.AliquotaEfetivaIBSUF;
      ADet.Imposto.IBSCBS.gIBSCBS.gTribRegular.pAliqEfetRegIBSMun := AItem.Impostos.IBSCBS.TributacaoRegular.AliquotaEfetivaIBSMunicipio;
      ADet.Imposto.IBSCBS.gIBSCBS.gTribRegular.pAliqEfetRegCBS := AItem.Impostos.IBSCBS.TributacaoRegular.AliquotaEfetivaCBS;
      ADet.Imposto.IBSCBS.gIBSCBS.gTribRegular.vTribRegIBSUF := AItem.Impostos.IBSCBS.TributacaoRegular.ValorIBSUF;
      ADet.Imposto.IBSCBS.gIBSCBS.gTribRegular.vTribRegIBSMun := AItem.Impostos.IBSCBS.TributacaoRegular.ValorIBSMunicipio;
      ADet.Imposto.IBSCBS.gIBSCBS.gTribRegular.vTribRegCBS := AItem.Impostos.IBSCBS.TributacaoRegular.ValorCBS;
    end;
  end;
  for Lote in AItem.Especifico.Lotes do
    with ADet.Prod.rastro.New do
    begin
      nLote := Lote.Numero;
      qLote := Lote.Quantidade;
      dFab := Lote.Fabricacao;
      dVal := Lote.Validade;
    end;
  if AItem.Especifico.Medicamento.Informado then
    with ADet.Prod.med.New do
    begin
      cProdANVISA := AItem.Especifico.Medicamento.CodigoANVISA;
      xMotivoIsencao := AItem.Especifico.Medicamento.MotivoIsencao;
      vPMC := AItem.Especifico.Medicamento.PrecoMaximoConsumidor;
    end;
  if AItem.Especifico.Combustivel.Informado then
  begin
    ADet.Prod.comb.cProdANP := StrToInt(AItem.Especifico.Combustivel.CodigoANP);
    ADet.Prod.comb.descANP := AItem.Especifico.Combustivel.DescricaoANP;
    ADet.Prod.comb.UFcons := AItem.Especifico.Combustivel.UFConsumo;
    ADet.Prod.comb.pGLP := AItem.Especifico.Combustivel.PercentualGLP;
    ADet.Prod.comb.pGNn := AItem.Especifico.Combustivel.PercentualGasNacional;
    ADet.Prod.comb.pGNi := AItem.Especifico.Combustivel.PercentualGasImportado;
    ADet.Prod.comb.vPart := AItem.Especifico.Combustivel.ValorPartida;
  end;
  for Importacao in AItem.Especifico.Importacoes do
  begin
    DI := ADet.Prod.DI.New;
    DI.nDi := Importacao.Numero;
    DI.dDi := Importacao.Registro;
    DI.xLocDesemb := Importacao.LocalDesembaraco;
    DI.UFDesemb := Importacao.UFDesembaraco;
    DI.dDesemb := Importacao.Desembaraco;
    DI.cExportador := Importacao.CodigoExportador;
    DI.vAFRMM := Importacao.ValorAFRMM;
    DI.UFTerceiro := Importacao.UFTerceiro;
    DI.CNPJ := DocumentoNormalizado(Importacao.CNPJAdquirente);
    DI.tpViaTransp := StrToTipoViaTransp(Ok, IntToStr(Importacao.ViaTransporte));
    ExigirConversao(Ok, 'Via de transporte da importacao');
    DI.tpIntermedio := StrToTipoIntermedio(Ok, IntToStr(Importacao.TipoIntermediacao));
    ExigirConversao(Ok, 'Intermediacao da importacao');
    for Adicao in Importacao.Adicoes do
      with DI.adi.New do
      begin
        nAdicao := Adicao.Numero;
        nSeqAdi := Adicao.Sequencia;
        cFabricante := Adicao.CodigoFabricante;
        vDescDI := Adicao.Desconto;
      end;
  end;
end;

procedure TACBrEmissor.PreencherComplementos(const ANota: TNotaFiscal; ANFe: TNFe);
var
  I, J: Integer;
  Ok, Existe: Boolean;
  Receita: TReceituarioNotaFiscal;
  Referencia: TReferenciaECFNotaFiscal;
  Observacao: TObservacaoNotaFiscal;
  Documento: String;
begin
  for Referencia in ANota.Complementos.ReferenciasECF do
    with ANFe.Ide.NFref.New.refECF do
    begin
      modelo := StrToECFModRef(Ok, Referencia.Modelo);
      ExigirConversao(Ok, 'Modelo ECF');
      nECF := Referencia.NumeroECF;
      nCOO := Referencia.NumeroCOO;
    end;
  ANFe.InfAdic.infAdFisco := ANota.Complementos.InformacoesFisco;
  ANFe.InfAdic.infCpl := ANota.Complementos.InformacoesComplementares;
  for Observacao in ANota.Complementos.Observacoes do
    with ANFe.InfAdic.obsCont.New do
    begin
      xCampo := Observacao.Campo;
      xTexto := Observacao.Texto;
    end;
  for Documento in ANota.Complementos.AutorizadosXML do
    ANFe.autXML.New.CNPJCPF := DocumentoNormalizado(Documento);
  ANFe.infIntermed.CNPJ := DocumentoNormalizado(ANota.Complementos.Intermediador.CNPJ);
  ANFe.infIntermed.idCadIntTran := ANota.Complementos.Intermediador.IdentificacaoCadastro;
  if ANota.Complementos.ResponsavelTecnico.Informado then
  begin
    ANFe.infRespTec.CNPJ := DocumentoNormalizado(ANota.Complementos.ResponsavelTecnico.CNPJ);
    ANFe.infRespTec.xContato := ANota.Complementos.ResponsavelTecnico.Contato;
    ANFe.infRespTec.email := ANota.Complementos.ResponsavelTecnico.Email;
    ANFe.infRespTec.fone := ANota.Complementos.ResponsavelTecnico.Telefone;
    if ANota.Complementos.ResponsavelTecnico.IdCSRT <> 0 then
    begin
      TValidacaoNotaFiscal.Exigir(FConfig.CSRT <> '', 'Segredo CSRT obrigatorio para conferir/gerar HashCSRT.');
      FACBr.Configuracoes.RespTec.IdCSRT := ANota.Complementos.ResponsavelTecnico.IdCSRT;
      FACBr.Configuracoes.RespTec.CSRT := FConfig.CSRT;
    end;
  end;
  if ANota.Complementos.Exportacao.Informada then
  begin
    ANFe.exporta.UFSaidaPais := ANota.Complementos.Exportacao.UFSaidaPais;
    ANFe.exporta.xLocExporta := ANota.Complementos.Exportacao.LocalExportacao;
    ANFe.exporta.xLocDespacho := ANota.Complementos.Exportacao.LocalDespacho;
  end;
  for I := 0 to ANota.QuantidadeItens - 1 do
    for Receita in ANota.Itens[I].Especifico.Receituarios do
    begin
      Existe := False;
      for J := 0 to ANFe.agropecuario.defensivo.Count - 1 do
        if (ANFe.agropecuario.defensivo[J].nReceituario = Receita.Numero) and
          (ANFe.agropecuario.defensivo[J].CPFRespTec = DocumentoNormalizado(Receita.CPFResponsavel)) then
          Existe := True;
      if not Existe then
      begin
        TValidacaoNotaFiscal.Exigir(ANFe.agropecuario.defensivo.Count < 20, 'Limite de 20 receituarios distintos por nota.');
        with ANFe.agropecuario.defensivo.New do
        begin
          nReceituario := Receita.Numero;
          CPFRespTec := DocumentoNormalizado(Receita.CPFResponsavel);
        end;
      end;
    end;
end;

end.
