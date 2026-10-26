program ACBrEmissorTests;
{$APPTYPE CONSOLE}
{$ASSERTIONS ON}
uses
  System.SysUtils, System.Classes, System.IOUtils, System.DateUtils,
  ACBrEmissor, EmissorNotaFiscal.Intf, EmitirNotaFiscal, CancelarNotaFiscal,
  CartaCorrecaoNotaFiscal, ConsultarStatusServico, ConsultarNotaFiscal, SefazStatus,
  NotaFiscal, NotaFiscal.Types, NotaFiscal.Endereco, NotaFiscal.Item,
  NotaFiscal.Impostos, NotaFiscal.RetornoEmissao, NotaFiscal.RetornoEvento,
  NotaFiscal.Validacao, ACBrNFe, ACBrNFe.Classes, ACBrNFeNotasFiscais,
  ACBrNFeWebServices, ACBrDFe.Conversao, ACBrDFeUtil, ACBrUtil.Strings,
  pcnConversaoNFe;

type
  TStatusSimulado = class(TNFeStatusServico)
    procedure Carregar(const AXML: String);
  end;
  TConsultaSimulada = class(TNFeConsulta)
    procedure Carregar(const AXML: String);
  end;
  TRecepcaoSimulada = class(TNFeRecepcao)
    procedure Carregar(const AXML: String);
  end;
  TEventoSimulado = class(TNFeEnvEvento)
    procedure Carregar(const AXML, AEnvio: String);
  end;
  TEmissorSimulado = class(TACBrEmissor)
  protected
    procedure AssinarEValidar; override;
    procedure TransmitirNota; override;
    procedure TransmitirEvento; override;
    procedure ConsultarStatus; override;
    procedure ConsultarNota; override;
    procedure ValidarXMLAssinado; override;
    procedure GravarTemporario(const ACaminho, AXML: String); override;
  public
    CodigoEmissao, CodigoEvento, CodigoStatus, CodigoConsulta: Integer;
    Consultas, Assinaturas, ValidacoesXML: Integer;
    Envios, Eventos, Gravacoes, FalharGravacao: Integer;
    UltimoTemporario: String;
    FalharEnvio, FalharAssinatura, FalharDepoisResposta, SemProtocolo,
      SemIndividual, EventoDivergente, FalharStatus, ChaveDivergente,
      AmbienteDivergente, AmbienteProtocoloDivergente, SemXMLProcessado,
      FalharConsulta, FalharValidacaoXML: Boolean;
    constructor Create(AConfig: TACBrEmissorConfig);
    function ACBr: TACBrNFe;
    procedure Gravar(const AXML, ANome, APasta: String);
  end;

var
  Verificacoes, NumeroNota: Integer;
  Pasta: String;

procedure Checar(ACondicao: Boolean; const AMensagem: String);
begin
  Inc(Verificacoes);
  if not ACondicao then raise Exception.Create('FALHOU: ' + AMensagem);
end;

procedure Contem(const ATexto, ATrecho, AMensagem: String);
begin
  Checar(Pos(ATrecho, ATexto) > 0, AMensagem + ': ' + ATrecho);
end;

function XMLUTF8(const ATexto: String): String;
begin
  Result := String(NativeStringToUTF8(ATexto));
end;

procedure TStatusSimulado.Carregar(const AXML: String);
begin
  FPRetornoWS := XMLUTF8('<nfeResultMsg>' + AXML + '</nfeResultMsg>');
  TratarResposta;
end;

procedure TConsultaSimulada.Carregar(const AXML: String);
begin
  FPRetornoWS := XMLUTF8('<nfeResultMsg>' + AXML + '</nfeResultMsg>');
  TratarResposta;
end;

procedure TRecepcaoSimulada.Carregar(const AXML: String);
begin
  InicializarServico;
  Sincrono := True;
  FPRetornoWS := XMLUTF8('<nfeResultMsg>' + AXML + '</nfeResultMsg>');
  TratarResposta;
end;

procedure TEventoSimulado.Carregar(const AXML, AEnvio: String);
begin
  FPDadosMsg := AEnvio;
  FPRetornoWS := XMLUTF8('<nfeResultMsg>' + AXML + '</nfeResultMsg>');
  TratarResposta;
end;

constructor TEmissorSimulado.Create(AConfig: TACBrEmissorConfig);
begin
  inherited Create(AConfig);
  Componente.WebServices.StatusServico.Free;
  Componente.WebServices.StatusServico := TStatusSimulado.Create(Componente);
  Componente.WebServices.Enviar.Free;
  Componente.WebServices.Enviar := TRecepcaoSimulada.Create(Componente, Componente.NotasFiscais);
  Componente.WebServices.EnvEvento.Free;
  Componente.WebServices.EnvEvento := TEventoSimulado.Create(Componente, Componente.EventoNFe);
  Componente.WebServices.Consulta.Free;
  Componente.WebServices.Consulta := TConsultaSimulada.Create(Componente, Componente.NotasFiscais);
  CodigoConsulta := 100;
  CodigoEmissao := 100;
  CodigoEvento := 135;
  CodigoStatus := 107;
end;

function TEmissorSimulado.ACBr: TACBrNFe;
begin
  Result := Componente;
end;

procedure TEmissorSimulado.AssinarEValidar;
begin
  Inc(Assinaturas);
  Gravacoes := 0;
  if FalharAssinatura then raise Exception.Create('Falha de assinatura simulada.');
  // Sem criptografia: somente o XML e a leitura das respostas sao reais nestes testes.
  Componente.NotasFiscais[0].XMLOriginal := StringReplace(Componente.NotasFiscais[0].GerarXML,
    '</NFe>', '<Signature xmlns="http://www.w3.org/2000/09/xmldsig#">' +
    '<SignedInfo><Reference URI="#NFe' + Componente.NotasFiscais[0].NumID + '">' +
    '<DigestValue>U0lNVUxBRE8=</DigestValue></Reference></SignedInfo>' +
    '<SignatureValue>U0lNVUxBRE8=</SignatureValue>' +
    '<KeyInfo><X509Data><X509Certificate>U0lNVUxBRE8=</X509Certificate></X509Data></KeyInfo>' +
    '</Signature></NFe>', []);
end;

procedure TEmissorSimulado.TransmitirNota;
var
  Protocolo, XML, Chave, Ambiente, AmbienteProtocolo: String;
begin
  Inc(Envios);
  if FalharEnvio then raise Exception.Create('Timeout simulado.');
  Protocolo := '<nProt>135260000000001</nProt>';
  if SemProtocolo then Protocolo := '';
  Chave := Componente.NotasFiscais[0].NumID;
  if ChaveDivergente then
    Chave[44] := Char(Ord('0') + (Ord(Chave[44]) - Ord('0') + 1) mod 10);
  Ambiente := '2';
  if AmbienteDivergente then Ambiente := '1';
  AmbienteProtocolo := Ambiente;
  if AmbienteProtocoloDivergente then AmbienteProtocolo := '1';
  XML := '<retEnviNFe versao="4.00" xmlns="http://www.portalfiscal.inf.br/nfe">' +
    '<tpAmb>' + Ambiente + '</tpAmb><verAplic>SIMULADO</verAplic><cStat>104</cStat>' +
    '<xMotivo>Lote processado</xMotivo><cUF>35</cUF><dhRecbto>2026-10-26T10:00:00-03:00</dhRecbto>';
  if not SemIndividual then
    XML := XML + '<protNFe versao="4.00"><infProt><tpAmb>' + AmbienteProtocolo + '</tpAmb><verAplic>SIMULADO</verAplic>' +
      '<chNFe>' + Chave + '</chNFe>' +
      '<dhRecbto>2026-10-26T10:00:00-03:00</dhRecbto>' + Protocolo +
      '<cStat>' + IntToStr(CodigoEmissao) + '</cStat><xMotivo>Resposta individual</xMotivo></infProt></protNFe>';
  XML := XML + '</retEnviNFe>';
  TRecepcaoSimulada(Componente.WebServices.Enviar).Carregar(XML);
  if SemXMLProcessado then Componente.NotasFiscais[0].NFe.procNFe.XML_prot := '';
  if FalharDepoisResposta then raise Exception.Create('Falha posterior a resposta.');
end;

procedure TEmissorSimulado.TransmitirEvento;
var
  XML, Chave, Protocolo, Tipo, Sequencia: String;
begin
  Gravacoes := 0;
  Inc(Eventos);
  if FalharEnvio then raise Exception.Create('Timeout de evento simulado.');
  Checar(Componente.NotasFiscais.Count = 0, 'Evento nao exige XML da nota');
  with Componente.EventoNFe.Evento[0].infEvento do
  begin
    Chave := chNFe;
    Checar(CNPJ = Copy(Chave, 7, 14), 'CNPJ do evento vem da chave');
    Tipo := TpEventoToStr(tpEvento);
    Sequencia := IntToStr(nSeqEvento);
  end;
  if EventoDivergente then Sequencia := '99';
  Protocolo := '<nProt>135260000000002</nProt>';
  if SemProtocolo then Protocolo := '';
  XML := '<retEnvEvento versao="1.00" xmlns="http://www.portalfiscal.inf.br/nfe">' +
    '<idLote>1</idLote><tpAmb>2</tpAmb><verAplic>SIMULADO</verAplic><cOrgao>35</cOrgao>' +
    '<cStat>128</cStat><xMotivo>Lote de evento processado</xMotivo>';
  if not SemIndividual then
    XML := XML + '<retEvento versao="1.00"><infEvento><tpAmb>2</tpAmb><verAplic>SIMULADO</verAplic>' +
      '<cOrgao>35</cOrgao><cStat>' + IntToStr(CodigoEvento) + '</cStat>' +
      '<xMotivo>Evento recebido: ação</xMotivo><chNFe>' + Chave + '</chNFe>' +
      '<tpEvento>' + Tipo + '</tpEvento><xEvento>Evento</xEvento><nSeqEvento>' + Sequencia + '</nSeqEvento>' +
      '<dhRegEvento>2026-10-26T10:01:00-03:00</dhRegEvento>' + Protocolo + '</infEvento></retEvento>';
  XML := XML + '</retEnvEvento>';
  Componente.EventoNFe.GerarXML;
  TEventoSimulado(Componente.WebServices.EnvEvento).Carregar(XML, Componente.EventoNFe.XmlEnvio);
  if FalharDepoisResposta then raise Exception.Create('Falha posterior ao evento.');
end;

procedure TEmissorSimulado.ConsultarStatus;
begin
  if FalharStatus then raise Exception.Create('Falha de status simulada.');
  TStatusSimulado(Componente.WebServices.StatusServico).Carregar(
    '<retConsStatServ versao="4.00" xmlns="http://www.portalfiscal.inf.br/nfe">' +
    '<tpAmb>2</tpAmb><verAplic>SIMULADO</verAplic><cStat>' + IntToStr(CodigoStatus) + '</cStat>' +
    '<xMotivo>Servico em operacao</xMotivo><cUF>35</cUF><dhRecbto>2026-10-26T10:00:00-03:00</dhRecbto>' +
    '<tMed>2</tMed><dhRetorno>2026-10-26T10:01:00-03:00</dhRetorno><xObs>Observacao</xObs></retConsStatServ>');
end;

procedure TEmissorSimulado.ValidarXMLAssinado;
begin
  Gravacoes := 0;
  Inc(ValidacoesXML);
  if FalharValidacaoXML then raise ENotaFiscalInvalida.Create('Assinatura/XML invalido simulado.');
end;

procedure TEmissorSimulado.ConsultarNota;
var
  XML, Chave, Ambiente, Protocolo: String;
begin
  Inc(Consultas);
  if FalharConsulta then raise Exception.Create('Timeout de consulta simulado.');
  Checar(Componente.NotasFiscais.Count = 0, 'Consulta nao exige XML local');
  Chave := Componente.WebServices.Consulta.NFeChave;
  if ChaveDivergente then
    Chave[44] := Char(Ord('0') + (Ord(Chave[44]) - Ord('0') + 1) mod 10);
  Ambiente := '2';
  if AmbienteDivergente then Ambiente := '1';
  Protocolo := '<nProt>135260000000003</nProt>';
  if SemProtocolo then Protocolo := '';
  XML := '<retConsSitNFe versao="4.00" xmlns="http://www.portalfiscal.inf.br/nfe">' +
    '<tpAmb>' + Ambiente + '</tpAmb><verAplic>SIMULADO</verAplic><cStat>' +
    IntToStr(CodigoConsulta) + '</cStat><xMotivo>Consulta da nota</xMotivo><cUF>35</cUF>' +
    '<dhRecbto>2026-10-26T10:00:00-03:00</dhRecbto><chNFe>' + Chave + '</chNFe>';
  if not SemIndividual then
    XML := XML + '<protNFe versao="4.00"><infProt><tpAmb>' + Ambiente + '</tpAmb>' +
      '<verAplic>SIMULADO</verAplic><chNFe>' + Chave + '</chNFe>' +
      '<dhRecbto>2026-10-26T10:00:00-03:00</dhRecbto>' + Protocolo +
      '<cStat>100</cStat><xMotivo>Autorizado</xMotivo></infProt></protNFe>';
  XML := XML + '</retConsSitNFe>';
  TConsultaSimulada(Componente.WebServices.Consulta).Carregar(XML);
  if FalharDepoisResposta then raise Exception.Create('Falha apos consulta simulada.');
end;

procedure TEmissorSimulado.GravarTemporario(const ACaminho, AXML: String);
begin
  Inc(Gravacoes);
  UltimoTemporario := ACaminho;
  if Gravacoes = FalharGravacao then
  begin
    TFile.WriteAllText(ACaminho, Copy(AXML, 1, Length(AXML) div 2), TEncoding.UTF8);
    raise EWriteError.Create('Escrita interrompida simulada.');
  end;
  inherited;
end;

procedure TEmissorSimulado.Gravar(const AXML, ANome, APasta: String);
begin
  SalvarDocumento(AXML, ANome, APasta);
end;

function Config: TACBrEmissorConfig;
begin
  Result := Default(TACBrEmissorConfig);
  Result.UF := 'SP';
  Result.Ambiente := NotaFiscal.Types.taHomologacao;
  Result.PathSalvar := Pasta;
  Result.PathSchemas := 'C:\ACBr\Exemplos\ACBrDFe\Schemas\NFe';
end;

procedure Endereco(AEndereco: TNotaFiscalEndereco);
begin
  AEndereco.Logradouro := 'Rua de teste';
  AEndereco.Numero := '10';
  AEndereco.Complemento := 'Sala 1';
  AEndereco.Bairro := 'Centro';
  AEndereco.CodMunicipio := '3550308';
  AEndereco.Municipio := 'Sao Paulo';
  AEndereco.UF := 'SP';
  AEndereco.CEP := '01001000';
  AEndereco.Telefone := '11999999999';
end;

function NovaNota: TNotaFiscal;
begin
  Inc(NumeroNota, 100);
  Result := TNotaFiscal.Create;
  Result.NroNota := NumeroNota;
  Result.Serie := 1;
  Result.CodigoNumerico := 12345678;
  Result.NaturezaOperacao := 'VENDA';
  Result.VersaoProcesso := '1.0';
  Result.DtEmissao := EncodeDate(2026, 10, 26) + EncodeTime(10, 0, 0, 0);
  Result.NFConfiguracao.UF := 'SP';
  Result.NFConfiguracao.CodMunicipio := '3550308';
  Result.Emitente.CNPJCPF := '11.222.333/0001-81';
  Result.Emitente.IE := '123456789';
  Result.Emitente.RazaoSocial := 'EMITENTE DE TESTE';
  Result.Emitente.NomeFantasia := 'FANTASIA';
  Result.Emitente.RegimeTributario := NotaFiscal.Types.rtRegimeNormal;
  Endereco(Result.Emitente.Endereco);
  Result.Destinatario.Informado := True;
  Result.Destinatario.CNPJCPF := '529.982.247-25';
  Result.Destinatario.Nome := 'DESTINATARIO DE TESTE';
  Result.Destinatario.Email := 'teste@example.com';
  Result.Destinatario.IndicadorIE := ieNaoContribuinte;
  Endereco(Result.Destinatario.Endereco);
  with Result.AdicionarItem do
  begin
    CodigoProduto := 'P001';
    Descricao := 'PRODUTO DE TESTE';
    NCM := '61091000';
    CFOP := '5102';
    GTIN := 'SEM GTIN';
    GTINTributavel := 'SEM GTIN';
    Unidade := 'UN';
    UnidadeTributavel := 'UN';
    Quantidade := 1;
    QuantidadeTributavel := 1;
    ValorUnitario := 100;
    ValorUnitarioTributavel := 100;
    ValorProdutos := 100;
    Impostos.ICMS.CST := '00';
    Impostos.ICMS.ModalidadeBase := 3;
    Impostos.ICMS.BaseCalculo := 100;
    Impostos.ICMS.Aliquota := 18;
    Impostos.ICMS.Valor := 18;
    Impostos.PIS.CST := '01';
    Impostos.PIS.BaseCalculo := 100;
    Impostos.PIS.Aliquota := 1.65;
    Impostos.PIS.Valor := 1.65;
    Impostos.COFINS.CST := '01';
    Impostos.COFINS.BaseCalculo := 100;
    Impostos.COFINS.Aliquota := 7.6;
    Impostos.COFINS.Valor := 7.6;
  end;
  Result.Totais.ValorProdutos := 100;
  Result.Totais.ValorNota := 100;
  Result.Totais.BaseICMS := 100;
  Result.Totais.ValorICMS := 18;
  Result.Totais.ValorPIS := 1.65;
  Result.Totais.ValorCOFINS := 7.6;
  SetLength(Result.Cobranca.Pagamentos, 1);
  Result.Cobranca.Pagamentos[0].Meio := '01';
  Result.Cobranca.Pagamentos[0].Valor := 100;
end;

procedure EsperarInvalido(const AAcao: TProc; const AMensagem: String);
var
  Invalidou: Boolean;
begin
  Invalidou := False;
  try AAcao; except on E: ENotaFiscalInvalida do Invalidou := True; end;
  Checar(Invalidou, AMensagem);
end;

procedure TestarConfiguracao;
var
  C: TACBrEmissorConfig;
  E: TEmissorSimulado;
begin
  E := TEmissorSimulado.Create(Config);
  try
    Checar(E.ACBr.Configuracoes.WebServices.TimeOut = 30000, 'Timeout padrao');
    Checar(E.ACBr.Configuracoes.Geral.ModeloDF = moNFe, 'Modelo padrao');
    Checar(E.ACBr.Configuracoes.Geral.VersaoQRCode = veqr300, 'QR Code padrao');
    Checar(E.ACBr.Configuracoes.Arquivos.PathEvento = Pasta, 'Fallback pasta eventos');
    Checar(not E.ACBr.Configuracoes.Arquivos.Salvar and not E.ACBr.Configuracoes.Arquivos.SalvarEvento, 'Gravacao protegida pelo adaptador');
  finally E.Free; end;
  C := Config; C.UF := '';
  EsperarInvalido(procedure begin E := TEmissorSimulado.Create(C); E.Free; end, 'UF obrigatoria');
  C := Config; C.Ambiente := Default(NotaFiscal.Types.TTipoAmbiente);
  EsperarInvalido(procedure begin E := TEmissorSimulado.Create(C); E.Free; end, 'Ambiente obrigatorio');
  C := Config; C.ArquivoPFX := 'teste.pfx'; C.NumeroSerie := '123';
  EsperarInvalido(procedure begin E := TEmissorSimulado.Create(C); E.Free; end, 'Certificados mutuamente exclusivos');
  C := Config; C.Timeout := -1;
  EsperarInvalido(procedure begin E := TEmissorSimulado.Create(C); E.Free; end, 'Timeout negativo');
end;

procedure TestarCasosDeUso;
var
  E: TEmissorSimulado;
  I: IEmissorNotaFiscal;
  N: TNotaFiscal;
  R: TNotaFiscalRetornoEmissao;
  V: TNotaFiscalRetornoEvento;
  S: TSefazStatus;
  Emitir: TEmitirNotaFiscal;
  Cancelar: TCancelarNotaFiscal;
  Corrigir: TCartaCorrecaoNotaFiscal;
  Status: TConsultarStatusServico;
begin
  E := TEmissorSimulado.Create(Config); I := E;
  N := NovaNota;
  Emitir := TEmitirNotaFiscal.Create(I);
  Cancelar := TCancelarNotaFiscal.Create(I);
  Corrigir := TCartaCorrecaoNotaFiscal.Create(I);
  Status := TConsultarStatusServico.Create(I);
  try
    R := Emitir.Emitir(N);
    Checar(R.ErroTecnico = '', 'Emissao: ' + R.ErroTecnico);
    Checar((R.CStat = 100) and (R.Status = seAutorizada), 'Autorizacao individual');
    Checar(Length(R.ChaveAcesso) = 44, 'Chave gerada');
    Checar(R.Protocolo = '135260000000001', 'Protocolo individual');
    Checar(R.DtRecebimento > 0, 'Data de recebimento');
    Contem(R.Documento, '<nfeProc', 'XML processado');
    Contem(R.Documento, '<CNPJ>11222333000181</CNPJ>', 'CNPJ normalizado');
    Contem(R.Documento, '<mod>55</mod>', 'Modelo NF-e');
    Contem(R.Documento, '<modBC>3</modBC>', 'Modalidade convertida');
    Contem(R.Documento, '<tPag>01</tPag>', 'Pagamento convertido');
    Checar(FileExists(TPath.Combine(Pasta, R.ChaveAcesso + '-nfe.xml')), 'Arquivo gravado');
    V := Cancelar.Cancelar(R.ChaveAcesso, 'Cancelamento solicitado pelo cliente', R.Protocolo);
    Checar(V.CStat = 135, 'Cancelamento individual: ' + IntToStr(V.CStat) + ' ' + V.ErroTecnico);
    Checar(V.TipoEvento = NotaFiscal.Types.teCancelamento, 'Tipo cancelamento');
    Checar(V.ErroTecnico = '', 'Cancelamento: ' + V.ErroTecnico);
    Contem(V.Documento, '<procEventoNFe', 'XML do evento');
    Contem(V.Documento, 'ação', 'UTF-8 no XML do evento');
    Contem(V.DtRegistro, '2026-10-26T', 'Data ISO');
    V := Corrigir.CartaCorrecao(R.ChaveAcesso, 'Corrigir informacao complementar da nota', 2);
    Checar(V.CStat = 135, 'CC-e individual');
    Checar(V.TipoEvento = teCartaCorrecao, 'Tipo CC-e');
    Contem(V.Documento, '<nSeqEvento>2</nSeqEvento>', 'Sequencia informada');
    Checar(V.ErroTecnico = '', 'CC-e: ' + V.ErroTecnico);
    S := Status.Consultar;
    try
      Checar((S.CStat = 107) and (S.UF = 'SP'), 'Status codigo/UF');
      Checar((S.TempoMedio = 2) and (S.VersaoAplicacao = 'SIMULADO'), 'Status metadados');
      Checar((S.DtRecebimento > 0) and (S.DtRetorno > 0) and (S.Observacao = 'Observacao'), 'Status datas/observacao');
    finally S.Free; end;
    Checar(E.ACBr.NotasFiscais.Count = 0, 'Status limpa notas');
    Checar(E.ACBr.EventoNFe.Evento.Count = 0, 'Status limpa eventos');
  finally
    Status.Free; Corrigir.Free; Cancelar.Free; Emitir.Free;
    N.Free; I := nil;
  end;
end;

procedure TestarFalhas;
const
  CodigosEmissao: array[0..2] of Integer = (204, 539, 778);
  CodigosEvento: array[0..3] of Integer = (136, 155, 218, 573);
var
  E: TEmissorSimulado;
  N: TNotaFiscal;
  R: TNotaFiscalRetornoEmissao;
  V: TNotaFiscalRetornoEvento;
  S: TSefazStatus;
  Chave: String;
  C: Integer;
begin
  E := TEmissorSimulado.Create(Config); N := NovaNota;
  try
    E.FalharGravacao := 1;
    R := E.Emitir(N);
    Checar((E.Envios = 0) and (R.ErroTecnico <> ''), 'Disco antes do envio impede transmissao');
    E.FalharGravacao := 0; E.FalharEnvio := True;
    R := E.Emitir(N);
    Checar((R.CStat = 0) and (R.ErroTecnico <> '') and (R.Documento <> '') and
      (R.Status = seIndeterminada), 'Timeout preserva XML e exige reconciliacao');
    Chave := R.ChaveAcesso;
    E.FalharEnvio := False; E.FalharGravacao := 2;
    R := E.Emitir(N);
    Checar((R.CStat = 100) and (R.Protocolo <> '') and (R.ErroTecnico <> '') and
      (R.Status = seAutorizada), 'Disco apos autorizacao preserva resultado');
    Checar(Pos('<nfeProc', TFile.ReadAllText(TPath.Combine(Pasta, R.ChaveAcesso + '-nfe.xml'),
      TEncoding.UTF8)) = 0, 'Escrita parcial conserva XML assinado anterior');
    Checar(not FileExists(E.UltimoTemporario), 'Temporario parcial removido apos autorizacao');
    Contem(R.Documento, '<nfeProc', 'XML autorizado conservado');
    N.NroNota := N.NroNota + 1; E.FalharGravacao := 0; E.FalharDepoisResposta := True;
    R := E.Emitir(N);
    Checar((R.CStat = 100) and (R.Protocolo <> '') and (R.ErroTecnico <> '') and
      (R.Status = seAutorizada), 'Excecao apos resposta preserva autorizacao');
    E.FalharDepoisResposta := False; E.SemProtocolo := True; N.NroNota := N.NroNota + 1;
    R := E.Emitir(N);
    Checar((R.CStat = 100) and (R.Protocolo = '') and (R.ErroTecnico <> '') and
      (R.Status = seIndeterminada), 'Autorizacao incompleta nao confirma');
    E.SemProtocolo := False; E.SemIndividual := True; N.NroNota := N.NroNota + 1;
    R := E.Emitir(N);
    Checar((R.CStat = 104) and (R.Protocolo = '') and (R.ErroTecnico <> '') and
      (R.Status = seIndeterminada), 'Lote sem nota nao confirma');
    E.SemIndividual := False;
    for C in CodigosEmissao do
    begin
      E.CodigoEmissao := C; N.NroNota := N.NroNota + 1;
      R := E.Emitir(N);
      Checar((R.CStat = C) and (R.ErroTecnico = ''), 'Resposta fiscal preservada ' + IntToStr(C));
      if (C = 204) or (C = 539) then
        Checar(R.Status = seIndeterminada, 'Duplicidade exige reconciliacao')
      else
        Checar(R.Status = seRejeitada, 'Rejeicao tem estado proprio');
    end;
    E.SemIndividual := True;
    V := E.Cancelar(Chave, 'Cancelamento solicitado pelo cliente', '135260000000001');
    Checar((V.CStat = 128) and (V.Protocolo = '') and (V.ErroTecnico <> ''), 'Lote 128 sem evento');
    E.SemIndividual := False;
    for C in CodigosEvento do
    begin
      E.CodigoEvento := C;
      V := E.Cancelar(Chave, 'Cancelamento solicitado pelo cliente', '135260000000001');
      Checar(V.CStat = C, 'Codigo individual preservado ' + IntToStr(C));
    end;
    E.CodigoEvento := 135; E.SemProtocolo := True;
    V := E.CartaCorrecao(Chave, 'Corrigir informacoes complementares da nota', 3);
    Checar((V.CStat = 135) and (V.ErroTecnico <> ''), 'Evento incompleto');
    E.SemProtocolo := False; E.EventoDivergente := True;
    V := E.CartaCorrecao(Chave, 'Corrigir informacoes complementares da nota', 3);
    Checar((V.CStat = 0) and (V.ErroTecnico <> ''), 'Evento divergente');
    E.EventoDivergente := False; E.FalharGravacao := 1;
    V := E.CartaCorrecao(Chave, 'Corrigir informacoes complementares da nota', 4);
    Checar((V.CStat = 135) and (V.Protocolo <> '') and (V.Documento <> '') and (V.ErroTecnico <> ''), 'Evento preservado apos falha de disco');
    E.FalharEnvio := True;
    V := E.CartaCorrecao(Chave, 'Corrigir informacoes complementares da nota', 5);
    Checar((V.CStat = 0) and (V.ErroTecnico <> '') and (V.Protocolo = ''), 'Timeout de evento sem retorno anterior');
    E.FalharEnvio := False;
    E.FalharStatus := True;
    S := E.StatusServico;
    try Checar((S.CStat = 0) and (S.ErroTecnico <> ''), 'Status tecnico sem cStat inventado'); finally S.Free; end;
    E.FalharStatus := False; E.CodigoStatus := 108;
    S := E.StatusServico;
    try Checar((S.CStat = 108) and (S.ErroTecnico = ''), 'Status indisponivel e resposta fiscal'); finally S.Free; end;
  finally N.Free; E.Free; end;
end;

procedure TestarNFCeERegimes;
const
  Regimes: array[0..3] of NotaFiscal.Types.TRegimeTributario =
    (NotaFiscal.Types.rtSimplesNacional, rtSimplesExcessoSublimite, NotaFiscal.Types.rtRegimeNormal, rtMEI);
var
  E: TEmissorSimulado;
  N: TNotaFiscal;
  R: TNotaFiscalRetornoEmissao;
  V: TNotaFiscalRetornoEvento;
  Regime: NotaFiscal.Types.TRegimeTributario;
  C: TACBrEmissorConfig;
begin
  E := TEmissorSimulado.Create(Config);
  try
    for Regime in Regimes do
    begin
      N := NovaNota;
      try
        N.Emitente.RegimeTributario := Regime;
        if (Regime = NotaFiscal.Types.rtSimplesNacional) or (Regime = rtMEI) then
        begin
          N.Itens[0].Impostos.ICMS.CST := '';
          N.Itens[0].Impostos.ICMS.CSOSN := '102';
        end;
        R := E.Emitir(N);
        Checar((R.CStat = 100) and (R.ErroTecnico = ''), 'Regime ' + IntToStr(Ord(Regime)));
        Contem(R.Documento, '<CRT>' + IntToStr(Ord(Regime)) + '</CRT>', 'CRT fiscal');
        if (Regime = NotaFiscal.Types.rtSimplesNacional) or (Regime = rtMEI) then
          Contem(R.Documento, '<CSOSN>102</CSOSN>', 'CSOSN fiscal');
      finally N.Free; end;
    end;
    N := NovaNota;
    try
      N.Modelo := mNFCe;
      N.Destinatario.Informado := False;
      R := E.Emitir(N);
      Checar((R.CStat = 100) and (R.ErroTecnico = ''), 'NFC-e online');
      Contem(R.Documento, '<mod>65</mod>', 'Modelo NFC-e');
      Checar(Pos('<dest>', R.Documento) = 0, 'Destinatario ausente na NFC-e');
      V := E.CartaCorrecao(R.ChaveAcesso, 'Corrigir informacao complementar', 1);
      Checar((V.CStat = 0) and (V.ErroTecnico <> ''), 'NFC-e bloqueia CC-e');
      V := E.Cancelar(R.ChaveAcesso, 'Cancelamento solicitado pelo cliente', '135260000000001');
      Checar((V.CStat = 135) and (V.ErroTecnico = ''), 'Cancelamento NFC-e');
      N.NroNota := N.NroNota + 1;
      N.NFConfiguracao.TipoEmissao := temContingenciaOffline;
      N.NFConfiguracao.DtContingencia := N.DtEmissao;
      N.NFConfiguracao.JustificativaContingencia := 'Sem comunicacao com o autorizador';
      E.Envios := 0;
      R := E.Emitir(N);
      Checar((R.CStat = 0) and (R.ErroTecnico = '') and (R.Protocolo = '') and
      (R.Status = sePendente), 'Offline continua pendente');
      Checar(E.Envios = 0, 'Offline nao transmite');
      Contem(R.Documento, '<tpEmis>9</tpEmis>', 'Forma offline convertida');
      Contem(R.Motivo, 'pendente', 'Pendencia explicita');
      N.Modelo := mNFE;
      R := E.Emitir(N);
      Checar((R.CStat = 0) and (R.ErroTecnico <> ''), 'NF-e nao aceita offline');
    finally N.Free; end;
    N := NovaNota;
    try
      R := E.Emitir(N);
      Checar(E.ACBr.Configuracoes.Geral.ModeloDF = moNFe, 'Modelo restaurado entre operacoes');
      Checar(E.ACBr.Configuracoes.Geral.FormaEmissao = ACBrDFe.Conversao.teNormal, 'Forma restaurada entre operacoes');
    finally N.Free; end;
  finally E.Free; end;
  C := Config; C.VersaoQRCode := 2;
  E := TEmissorSimulado.Create(C); N := NovaNota;
  try
    N.Modelo := mNFCe; N.Destinatario.Informado := False;
    R := E.Emitir(N);
    Checar((R.CStat = 0) and (R.ErroTecnico <> ''), 'QR Code 2 exige CSC');
    Checar(E.Envios = 0, 'QR Code invalido nao transmite');
  finally N.Free; E.Free; end;
end;

procedure TestarMapeamento;
var
  E: TEmissorSimulado;
  N: TNotaFiscal;
  D: TNotaFiscalItem;
  R: TNotaFiscalRetornoEmissao;
  C: TACBrEmissorConfig;
  Chave, Arquivo, XML: String;
  Receitas: Integer;
begin
  C := Config; C.CSRT := 'SEGREDO-APENAS-TESTE';
  E := TEmissorSimulado.Create(C); N := NovaNota;
  try
    D := N.Itens[0];
    N.DtSaidaEmissao := N.DtEmissao + 1;
    N.NFConfiguracao.DestinoOperacao := tdInterestadual;
    N.NFConfiguracao.PresencaConsumidor := tpInternet;
    N.NFConfiguracao.Intermediador := tiComIntermediador;
    N.Destinatario.Endereco.UF := 'RJ';
    N.Destinatario.Endereco.CodMunicipio := '3304557';
    N.Destinatario.Endereco.Municipio := 'Rio de Janeiro';
    D.CFOP := '6102';
    D.CEST := '1234567'; D.EXTIPI := '123'; D.CodigoBeneficio := 'SP123456';
    D.Pedido := 'PEDIDO1'; D.ItemPedido := 2;
    D.InformacoesAdicionais := 'Informacao do item';
    D.Desconto := 1; D.Frete := 2; D.Seguro := 3; D.OutrasDespesas := 4;
    D.Impostos.ICMS.CST := '10';
    D.Impostos.ICMS.ModalidadeBaseST := 4;
    D.Impostos.ICMS.BaseST := 80; D.Impostos.ICMS.ValorST := 6;
    D.Impostos.ICMS.AliquotaST := 7.5; D.Impostos.ICMS.MargemValorAdicionadoST := 20;
    D.Impostos.ICMS.BaseFCPST := 70; D.Impostos.ICMS.AliquotaFCPST := 10;
    D.Impostos.ICMS.ValorFCPST := 7;
    D.Impostos.IPI.Informado := True; D.Impostos.IPI.CST := '50';
    D.Impostos.IPI.Enquadramento := '999'; D.Impostos.IPI.BaseCalculo := 100;
    D.Impostos.IPI.Aliquota := 5; D.Impostos.IPI.Valor := 5;
    D.Impostos.PISST.Informado := True; D.Impostos.PISST.BaseCalculo := 100;
    D.Impostos.PISST.Aliquota := 1; D.Impostos.PISST.Valor := 1;
    D.Impostos.COFINSST.Informado := True; D.Impostos.COFINSST.BaseCalculo := 100;
    D.Impostos.COFINSST.Aliquota := 2; D.Impostos.COFINSST.Valor := 2;
    D.Impostos.DIFAL.Informado := True; D.Impostos.DIFAL.BaseCalculo := 100;
    D.Impostos.DIFAL.BaseFCP := 100; D.Impostos.DIFAL.AliquotaFCP := 2;
    D.Impostos.DIFAL.ValorFCP := 2; D.Impostos.DIFAL.ValorDestino := 10;
    D.Impostos.DIFAL.ValorRemetente := 3; D.Impostos.DIFAL.AliquotaDestino := 18;
    D.Impostos.DIFAL.AliquotaInterestadual := 12; D.Impostos.DIFAL.PartilhaDestino := 100;
    D.Impostos.IBSCBS.Informado := True; D.Impostos.IBSCBS.CST := '200';
    D.Impostos.IBSCBS.ClassificacaoTributaria := '200001';
    D.Impostos.IBSCBS.BaseCalculo := 100; D.Impostos.IBSCBS.ValorIBS := 0.1;
    D.Impostos.IBSCBS.IBSUF.Aliquota := 0.1; D.Impostos.IBSCBS.IBSUF.Valor := 0.04;
    D.Impostos.IBSCBS.IBSUF.ReducaoAliquota := 60; D.Impostos.IBSCBS.IBSUF.AliquotaEfetiva := 0.04;
    D.Impostos.IBSCBS.IBSMunicipio.Aliquota := 0.1; D.Impostos.IBSCBS.IBSMunicipio.Valor := 0.06;
    D.Impostos.IBSCBS.IBSMunicipio.ReducaoAliquota := 40; D.Impostos.IBSCBS.IBSMunicipio.AliquotaEfetiva := 0.06;
    D.Impostos.IBSCBS.CBS.Aliquota := 0.9; D.Impostos.IBSCBS.CBS.Valor := 0.45;
    D.Impostos.IBSCBS.CBS.ReducaoAliquota := 50; D.Impostos.IBSCBS.CBS.AliquotaEfetiva := 0.45;
    D.Impostos.IBSCBS.TributacaoRegular.Informado := True;
    D.Impostos.IBSCBS.TributacaoRegular.CST := '000';
    D.Impostos.IBSCBS.TributacaoRegular.ClassificacaoTributaria := '000001';
    D.Impostos.IBSCBS.TributacaoRegular.AliquotaEfetivaIBSUF := 0.1;
    D.Impostos.IBSCBS.TributacaoRegular.AliquotaEfetivaIBSMunicipio := 0.1;
    D.Impostos.IBSCBS.TributacaoRegular.AliquotaEfetivaCBS := 0.9;
    D.Impostos.IBSCBS.TributacaoRegular.ValorIBSUF := 0.1;
    D.Impostos.IBSCBS.TributacaoRegular.ValorIBSMunicipio := 0.1;
    D.Impostos.IBSCBS.TributacaoRegular.ValorCBS := 0.9;
    N.Totais.Desconto := 1; N.Totais.Frete := 2; N.Totais.Seguro := 3;
    N.Totais.OutrasDespesas := 4; N.Totais.BaseICMSST := 80;
    N.Totais.ValorICMSST := 6; N.Totais.ValorFCPST := 7; N.Totais.ValorIPI := 5;
    N.Totais.ValorNota := 126; N.Totais.BaseIBSCBS := 100;
    N.Totais.ValorIBSUF := 0.04; N.Totais.ValorIBSMunicipio := 0.06;
    N.Totais.ValorIBS := 0.1; N.Totais.ValorCBS := 0.45;
    N.Totais.ValorFCPDestino := 2; N.Totais.ValorICMSDestino := 10; N.Totais.ValorICMSRemetente := 3;
    N.Totais.BaseIRRF := 10; N.Totais.ValorIRRF := 1;
    N.Cobranca.Pagamentos[0].Meio := '03'; N.Cobranca.Pagamentos[0].Valor := 128;
    N.Cobranca.Pagamentos[0].Indicador := NotaFiscal.Types.ipPrazo;
    N.Cobranca.Pagamentos[0].Integracao := itIntegrado;
    N.Cobranca.Pagamentos[0].CNPJInstituicao := '11222333000181';
    N.Cobranca.Pagamentos[0].BandeiraCartao := '99'; N.Cobranca.Pagamentos[0].Autorizacao := 'ABC123';
    N.Cobranca.Troco := 2;
    N.Cobranca.Fatura.Informada := True; N.Cobranca.Fatura.Numero := 'FAT1';
    N.Cobranca.Fatura.ValorOriginal := 126; N.Cobranca.Fatura.ValorLiquido := 126;
    SetLength(N.Cobranca.Duplicatas, 1);
    N.Cobranca.Duplicatas[0].Numero := '001'; N.Cobranca.Duplicatas[0].Vencimento := N.DtEmissao + 30;
    N.Cobranca.Duplicatas[0].Valor := 126;
    N.Transporte.ModalidadeFrete := mfTerceiros;
    N.Transporte.CNPJCPF := '11222333000181'; N.Transporte.Nome := 'TRANSPORTADOR';
    N.Transporte.IE := '123'; N.Transporte.Endereco := 'Rua do transportador';
    N.Transporte.Municipio := 'Sao Paulo'; N.Transporte.UF := 'SP';
    N.Transporte.Placa := 'ABC1234'; N.Transporte.UFPlaca := 'SP'; N.Transporte.RNTC := '12345678';
    N.Transporte.CFOPRetencao := '5353'; N.Transporte.CodMunicipioRetencao := '3550308';
    N.Transporte.ValorServicoRetencao := 10; N.Transporte.BaseRetencao := 10;
    N.Transporte.AliquotaRetencao := 12; N.Transporte.ValorICMSRetido := 1.2;
    SetLength(N.Transporte.Volumes, 1);
    N.Transporte.Volumes[0].Quantidade := 3; N.Transporte.Volumes[0].Especie := 'CX';
    N.Transporte.Volumes[0].Marca := 'MARCA'; N.Transporte.Volumes[0].Numeracao := '001';
    N.Transporte.Volumes[0].PesoLiquido := 2; N.Transporte.Volumes[0].PesoBruto := 3;
    N.Entrega.Informado := True; N.Entrega.CNPJCPF := '52998224725';
    N.Entrega.Nome := 'LOCAL DE ENTREGA'; Endereco(N.Entrega.Endereco);
    N.Complementos.InformacoesFisco := 'Informacoes ao fisco';
    N.Complementos.InformacoesComplementares := 'Informação complementar: ação';
    SetLength(N.Complementos.Observacoes, 1);
    N.Complementos.Observacoes[0].Campo := 'CAMPO'; N.Complementos.Observacoes[0].Texto := 'TEXTO';
    SetLength(N.Complementos.AutorizadosXML, 1); N.Complementos.AutorizadosXML[0] := '52998224725';
    SetLength(N.Complementos.ReferenciasECF, 1);
    N.Complementos.ReferenciasECF[0].Modelo := '2D'; N.Complementos.ReferenciasECF[0].NumeroECF := '001';
    N.Complementos.ReferenciasECF[0].NumeroCOO := '000123';
    N.Complementos.Intermediador.CNPJ := '11222333000181'; N.Complementos.Intermediador.IdentificacaoCadastro := 'LOJA';
    N.Complementos.ResponsavelTecnico.Informado := True;
    N.Complementos.ResponsavelTecnico.CNPJ := '11222333000181';
    N.Complementos.ResponsavelTecnico.Contato := 'CONTATO';
    N.Complementos.ResponsavelTecnico.Email := 'contato@example.com';
    N.Complementos.ResponsavelTecnico.Telefone := '11999999999';
    N.Complementos.ResponsavelTecnico.IdCSRT := 1;
    Chave := GerarChaveAcesso(35, N.DtEmissao, '11222333000181', N.Serie, N.NroNota, 1, N.CodigoNumerico, 55);
    N.Complementos.ResponsavelTecnico.HashCSRT := CalcularHashCSRT(C.CSRT, Chave);
    N.AdicionarReferencia(GerarChaveAcesso(35, N.DtEmissao, '11222333000181', 1, 999999, 1, 87654321, 55));
    N.Complementos.Exportacao.Informada := True; N.Complementos.Exportacao.UFSaidaPais := 'SP';
    N.Complementos.Exportacao.LocalExportacao := 'SANTOS'; N.Complementos.Exportacao.LocalDespacho := 'PORTO';
    SetLength(D.Especifico.Lotes, 1);
    D.Especifico.Lotes[0].Numero := 'LOTE1'; D.Especifico.Lotes[0].Quantidade := 1;
    D.Especifico.Lotes[0].Fabricacao := N.DtEmissao - 30; D.Especifico.Lotes[0].Validade := N.DtEmissao + 365;
    D.Especifico.Medicamento.Informado := True; D.Especifico.Medicamento.CodigoANVISA := 'ISENTO';
    D.Especifico.Medicamento.MotivoIsencao := 'ISENCAO DE TESTE'; D.Especifico.Medicamento.PrecoMaximoConsumidor := 100;
    SetLength(D.Especifico.Importacoes, 1);
    with D.Especifico.Importacoes[0] do
    begin
      Numero := '1234567890'; Registro := N.DtEmissao - 10; Desembaraco := N.DtEmissao - 5;
      LocalDesembaraco := 'SANTOS'; UFDesembaraco := 'SP'; CodigoExportador := 'EXP1';
      ViaTransporte := 1; TipoIntermediacao := 2; CNPJAdquirente := '11222333000181';
      UFTerceiro := 'SP'; ValorAFRMM := 1;
      SetLength(Adicoes, 1); Adicoes[0].Numero := 1; Adicoes[0].Sequencia := 1;
      Adicoes[0].CodigoFabricante := 'FAB1'; Adicoes[0].Desconto := 0.1;
    end;
    SetLength(D.Especifico.Receituarios, 2);
    D.Especifico.Receituarios[0].Numero := 'RECEITA1'; D.Especifico.Receituarios[0].CPFResponsavel := '529.982.247-25';
    D.Especifico.Receituarios[1] := D.Especifico.Receituarios[0];
    R := E.Emitir(N);
    Checar((R.CStat = 100) and (R.ErroTecnico = ''), 'Mapeamento completo: ' + R.ErroTecnico);
    Checar(R.ChaveAcesso = Chave, 'Identidade da nota preservada');
    Contem(R.Documento, '<IBSCBS>', 'Grupo IBS/CBS');
    Contem(R.Documento, '<cClassTrib>200001</cClassTrib>', 'Classificacao preservada');
    Contem(R.Documento, '<pRedAliq>60.0000</pRedAliq>', 'Reducao IBS/CBS');
    Contem(R.Documento, '<IBSCBSTot>', 'Totais IBS/CBS');
    Contem(R.Documento, '<gTribRegular>', 'Tributacao regular');
    Contem(R.Documento, '<hashCSRT>' + N.Complementos.ResponsavelTecnico.HashCSRT + '</hashCSRT>', 'Hash CSRT nativo');
    Contem(R.Documento, '<nECF>001</nECF>', 'Referencia ECF preserva zeros');
    Contem(R.Documento, '<refNFe>', 'Referencia NF-e');
    Contem(R.Documento, '<nDI>1234567890</nDI>', 'Declaracao de importacao');
    Contem(R.Documento, '<cFabricante>FAB1</cFabricante>', 'Adicao da importacao');
    Contem(R.Documento, '<cProdANVISA>ISENTO</cProdANVISA>', 'Medicamento');
    Contem(R.Documento, '<nLote>LOTE1</nLote>', 'Rastreabilidade');
    Contem(R.Documento, '<ICMSUFDest>', 'DIFAL');
    Contem(R.Documento, '<PISST>', 'PIS ST'); Contem(R.Documento, '<COFINSST>', 'COFINS ST');
    Contem(R.Documento, '<IPI>', 'IPI');
    Contem(R.Documento, '<nDup>001</nDup>', 'Duplicatas');
    Contem(R.Documento, '<tpIntegra>1</tpIntegra>', 'Integracao convertida');
    Contem(R.Documento, '<tBand>99</tBand>', 'Bandeira convertida');
    Contem(R.Documento, '<vTroco>2.00</vTroco>', 'Troco');
    Contem(R.Documento, '<modFrete>2</modFrete>', 'Frete convertido');
    Contem(R.Documento, '<placa>ABC1234</placa>', 'Veiculo');
    Contem(R.Documento, '<qVol>3</qVol>', 'Volumes');
    Contem(R.Documento, '<entrega>', 'Entrega'); Contem(R.Documento, '<autXML>', 'Autorizados XML');
    Contem(R.Documento, '<infIntermed>', 'Intermediador');
    Contem(R.Documento, '<exporta>', 'Exportacao');
    Checar(E.ACBr.NotasFiscais[0].NFe.agropecuario.defensivo.Count = 1, 'Receituarios distintos');
    Arquivo := TPath.Combine(Pasta, Chave + '-nfe.xml');
    XML := TFile.ReadAllText(Arquivo, TEncoding.UTF8);
    Checar(XML = R.Documento, 'Arquivo e retorno possuem o mesmo XML processado');
    Contem(R.Documento, 'Informação complementar: ação', 'UTF-8 no retorno');
    Contem(XML, 'Informação complementar: ação', 'UTF-8 sem perda');
    N.NroNota := N.NroNota + 1;
    R := E.Emitir(N);
    Checar((R.CStat = 0) and (R.ErroTecnico <> ''), 'Hash CSRT antigo bloqueado para outra chave');
    N.Complementos.ResponsavelTecnico.Informado := False;
    R := E.Emitir(N);
    Checar((R.ErroTecnico = '') and (Pos('<hashCSRT>', R.Documento) = 0), 'Responsavel nao informado ignorado');
    SetLength(D.Especifico.Receituarios, 21);
    for Receitas := 0 to 20 do
    begin
      D.Especifico.Receituarios[Receitas].Numero := IntToStr(Receitas + 1);
      D.Especifico.Receituarios[Receitas].CPFResponsavel := '52998224725';
    end;
    R := E.Emitir(N);
    Checar((R.CStat = 0) and (R.ErroTecnico <> ''), 'Limite global de receituarios');
  finally N.Free; E.Free; end;
end;

procedure TestarValidacoesEGrupos;
var
  E: TEmissorSimulado;
  N: TNotaFiscal;
  R: TNotaFiscalRetornoEmissao;
  V: TNotaFiscalRetornoEvento;
  Chave, Antes: String;
  Falhou: Boolean;
begin
  E := TEmissorSimulado.Create(Config); N := NovaNota;
  try
    R := E.Emitir(nil);
    Checar((R.CStat = 0) and (R.ErroTecnico <> ''), 'Nota obrigatoria');
    N.NFConfiguracao.TipoAmbiente := NotaFiscal.Types.taProducao;
    R := E.Emitir(N);
    Checar((R.CStat = 0) and (R.ErroTecnico <> ''), 'Ambiente divergente');
    N.NFConfiguracao.TipoAmbiente := NotaFiscal.Types.taHomologacao;
    Chave := GerarChaveAcesso(35, N.DtEmissao, '11222333000181', N.Serie, N.NroNota, 1, N.CodigoNumerico, 55);
    V := E.Cancelar('123', 'Justificativa de cancelamento', '135260000000001');
    Checar((V.CStat = 0) and (V.ErroTecnico <> ''), 'Chave invalida');
    V := E.Cancelar(Chave, 'Curto', '135260000000001');
    Checar((V.CStat = 0) and (V.ErroTecnico <> ''), 'Justificativa curta');
    V := E.Cancelar(Chave, 'Justificativa de cancelamento', '123');
    Checar((V.CStat = 0) and (V.ErroTecnico <> ''), 'Protocolo invalido');
    V := E.CartaCorrecao(Chave, 'Correcao de informacao complementar', 0);
    Checar((V.CStat = 0) and (V.ErroTecnico <> ''), 'Sequencia minima');
    V := E.CartaCorrecao(Chave, 'Correcao de informacao complementar', 21);
    Checar((V.CStat = 0) and (V.ErroTecnico <> ''), 'Sequencia maxima');
    Checar((E.Envios = 0) and (E.Eventos = 0), 'Invalidos nao acessam transporte');
    N.Itens[0].Especifico.Combustivel.Informado := True;
    N.Itens[0].Especifico.Combustivel.CodigoANP := '210203001';
    N.Itens[0].Especifico.Combustivel.DescricaoANP := 'GLP';
    N.Itens[0].Especifico.Combustivel.UFConsumo := 'SP';
    N.Itens[0].Especifico.Combustivel.PercentualGLP := 60;
    N.Itens[0].Especifico.Combustivel.PercentualGasNacional := 30;
    N.Itens[0].Especifico.Combustivel.PercentualGasImportado := 10;
    N.Itens[0].Especifico.Combustivel.ValorPartida := 1;
    N.Itens[0].Impostos.IPI.Valor := 999; // Informado=False: nao deve vazar ao XML.
    R := E.Emitir(N);
    Checar(R.ErroTecnico = '', 'Combustivel: ' + R.ErroTecnico);
    Contem(R.Documento, '<cProdANP>210203001</cProdANP>', 'Codigo ANP');
    Contem(R.Documento, '<pGLP>60.0000</pGLP>', 'Composicao GLP');
    Checar(E.ACBr.NotasFiscais[0].NFe.Det[0].Imposto.IPI.vIPI = 0, 'IPI nao informado ignorado');
    Antes := TFile.ReadAllText(TPath.Combine(Pasta, R.ChaveAcesso + '-nfe.xml'), TEncoding.UTF8);
    E.Envios := 0;
    R := E.Emitir(N);
    Checar((E.Envios = 0) and (R.ErroTecnico <> '') and (R.Status = seIndeterminada),
      'XML autorizado existente exige reconciliacao e nao transmite');
    Checar(Antes = TFile.ReadAllText(TPath.Combine(Pasta, R.ChaveAcesso + '-nfe.xml'), TEncoding.UTF8), 'Arquivo autorizado preservado');
    N.NroNota := N.NroNota + 1;
    N.Itens[0].Especifico.Combustivel.Informado := False;
    N.Itens[0].Impostos.IPI.Valor := 0;
    N.Itens[0].Impostos.ISSQN.Informado := True;
    N.Itens[0].Impostos.ISSQN.CodMunicipio := '3550308';
    N.Itens[0].Impostos.ISSQN.ListaServico := '01.01';
    N.Itens[0].Impostos.ISSQN.SituacaoTributaria := 'N';
    N.Itens[0].Impostos.ISSQN.BaseCalculo := 100;
    N.Itens[0].Impostos.ISSQN.Aliquota := 5; N.Itens[0].Impostos.ISSQN.Valor := 5;
    N.Itens[0].NCM := '00';
    N.Totais.ValorProdutos := 0; N.Totais.ValorServicos := 100;
    N.Totais.BaseISSQN := 100; N.Totais.ValorISSQN := 5;
    R := E.Emitir(N);
    Checar(R.ErroTecnico = '', 'Servico ISSQN: ' + R.ErroTecnico);
    Contem(R.Documento, '<ISSQN>', 'ISSQN do item');
    Contem(R.Documento, '<ISSQNtot>', 'Totais ISSQN');
    Checar(Pos('<ICMS>', R.Documento) = 0, 'ISSQN sem ICMS do item');
    Falhou := False;
    try TSefazStatus.Create(0, '', 'SP', 0, 0).Free; except on EErro: ENotaFiscalInvalida do Falhou := True; end;
    Checar(Falhou, 'CStat zero exige erro tecnico no status');
  finally N.Free; E.Free; end;
end;

procedure TestarRetencaoECredito;
var
  E: TEmissorSimulado;
  N: TNotaFiscal;
  R: TNotaFiscalRetornoEmissao;
  Caso: Integer;
begin
  E := TEmissorSimulado.Create(Config);
  try
    for Caso := 1 to 3 do
    begin
      N := NovaNota;
      try
        N.Itens[0].Impostos.ICMS.CST := '60';
        if Caso > 1 then
        begin
          N.Emitente.RegimeTributario := NotaFiscal.Types.rtSimplesNacional;
          N.Itens[0].Impostos.ICMS.CST := '';
          N.Itens[0].Impostos.ICMS.CSOSN := '500';
        end;
        N.Itens[0].Impostos.ICMS.BaseST := 90;
        N.Itens[0].Impostos.ICMS.ValorST := 9;
        N.Itens[0].Impostos.ICMS.BaseFCPST := 90;
        N.Itens[0].Impostos.ICMS.AliquotaFCPST := 2;
        N.Itens[0].Impostos.ICMS.ValorFCPST := 1.8;
        if Caso = 3 then
        begin
          N.Itens[0].Impostos.ICMS.CSOSN := '101';
          N.Itens[0].Impostos.ICMS.AliquotaCreditoSN := 3;
          N.Itens[0].Impostos.ICMS.ValorCreditoSN := 3;
        end;
        R := E.Emitir(N);
        Checar(R.ErroTecnico = '', 'Retencao/credito: ' + R.ErroTecnico);
        if Caso < 3 then
        begin
          Contem(R.Documento, '<vBCSTRet>90.00</vBCSTRet>', 'Base ST retida');
          Contem(R.Documento, '<vICMSSTRet>9.00</vICMSSTRet>', 'Valor ST retido');
          Contem(R.Documento, '<vFCPSTRet>1.80</vFCPSTRet>', 'FCP retido');
        end
        else
          Contem(R.Documento, '<vCredICMSSN>3.00</vCredICMSSN>', 'Credito Simples');
      finally N.Free; end;
    end;
    N := NovaNota;
    try
      E.FalharAssinatura := True;
      E.Envios := 0;
      R := E.Emitir(N);
      Checar((R.CStat = 0) and (R.ErroTecnico <> '') and (E.Envios = 0), 'Falha na assinatura nao transmite');
      Checar((R.Documento <> '') and (Length(R.ChaveAcesso) = 44), 'Dados disponiveis antes da assinatura preservados');
    finally N.Free; end;
  finally E.Free; end;
end;

procedure TestarGravacaoSegura;
var
  E: TEmissorSimulado;
  Bloqueio: TFileStream;
  Caminho, Antes: String;
  Falhou: Boolean;
begin
  E := TEmissorSimulado.Create(Config);
  try
    Caminho := TPath.Combine(Pasta, 'preservado.xml');
    E.Gravar('<NFe>original</NFe>', 'preservado.xml', Pasta);
    Antes := TFile.ReadAllText(Caminho, TEncoding.UTF8);
    E.FalharGravacao := E.Gravacoes + 1;
    Falhou := False;
    try E.Gravar('<nfeProc>novo</nfeProc>', 'preservado.xml', Pasta);
    except on EErro: EWriteError do Falhou := True; end;
    Checar(Falhou, 'Escrita interrompida depois de criar o temporario');
    Checar(TFile.ReadAllText(Caminho, TEncoding.UTF8) = Antes, 'Escrita parcial preserva original');
    Checar(not FileExists(E.UltimoTemporario), 'Temporario parcial removido');
    E.FalharGravacao := 0;
    Bloqueio := TFileStream.Create(Caminho, fmOpenRead or fmShareExclusive);
    try
      Falhou := False;
      try E.Gravar('<nfeProc>novo</nfeProc>', 'preservado.xml', Pasta);
      except on EErro: EOSError do Falhou := True; end;
      Checar(Falhou, 'Substituicao do arquivo bloqueado falha');
    finally Bloqueio.Free; end;
    Checar(TFile.ReadAllText(Caminho, TEncoding.UTF8) = Antes, 'Arquivo bloqueado preservado');
    Checar(not FileExists(E.UltimoTemporario), 'Temporario removido apos falha de substituicao');
    E.Gravar('<nfeProc>novo</nfeProc>', 'preservado.xml', Pasta);
    Checar(TFile.ReadAllText(Caminho, TEncoding.UTF8) = '<nfeProc>novo</nfeProc>', 'Substituicao completa');
  finally E.Free; end;
end;

procedure TestarChaveAlfanumerica;
var
  Chave: String;
  Codigo: Integer;
begin
  TValidacaoNotaFiscal.Documento('12.ABC.345/01DE-35', 'CNPJ alfanumerico');
  for Codigo := 1 to 20 do
  begin
    Chave := GerarChaveAcesso(35, EncodeDate(2026, 10, 26), '12ABC34501DE35', 1, 1, 1, Codigo, 55);
    TValidacaoNotaFiscal.Chave(Chave);
    Checar(Length(Chave) = 44, 'Chave alfanumerica do ACBr aceita');
    Chave[44] := Char(Ord('0') + (Ord(Chave[44]) - Ord('0') + 1) mod 10);
    EsperarInvalido(procedure begin TValidacaoNotaFiscal.Chave(Chave); end, 'DV alfanumerico alterado');
  end;
end;

procedure TestarEstadosEmissao;
const
  Monofasicos: array[0..3] of String = ('02', '15', '53', '61');
var
  E: TEmissorSimulado;
  N: TNotaFiscal;
  R: TNotaFiscalRetornoEmissao;
  Caso: Integer;
  CST: String;
begin
  E := TEmissorSimulado.Create(Config); N := NovaNota;
  try
    for Caso := 1 to 6 do
    begin
      E.ChaveDivergente := Caso = 1;
      E.AmbienteDivergente := Caso = 2;
      E.SemProtocolo := (Caso = 4) or (Caso = 5);
      E.AmbienteProtocoloDivergente := Caso = 6;
      E.SemXMLProcessado := Caso = 3;
      E.FalharDepoisResposta := Caso = 5;
      R := E.Emitir(N);
      Checar((R.Status = seIndeterminada) and (R.ErroTecnico <> ''),
        'Retorno incompleto/divergente nao autoriza, inclusive apos excecao: ' + IntToStr(Caso));
      N.NroNota := N.NroNota + 1;
    end;
    E.ChaveDivergente := False; E.AmbienteDivergente := False;
    E.SemProtocolo := False; E.SemXMLProcessado := False; E.FalharDepoisResposta := False;
    E.AmbienteProtocoloDivergente := False;
    E.Envios := 0;
    for CST in Monofasicos do
    begin
      N.Itens[0].Impostos.ICMS.CST := CST;
      R := E.Emitir(N);
      Checar((R.Status = seRejeitada) and (R.CStat = 0) and (E.Envios = 0),
        'ICMS monofasico sem suporte nao transmite: ' + CST);
      Contem(R.ErroTecnico, 'monofasico nao suportado', 'Diagnostico de suporte monofasico');
    end;
  finally N.Free; E.Free; end;
end;


procedure TestarConsultaPorChave;
var
  E: TEmissorSimulado;
  I: IEmissorNotaFiscal;
  Consulta: TConsultarNotaFiscal;
  R: TNotaFiscalRetornoEmissao;
  Chave: String;
begin
  E := TEmissorSimulado.Create(Config); I := E;
  Consulta := TConsultarNotaFiscal.Create(I);
  try
    Chave := GerarChaveAcesso(35, EncodeDate(2026, 10, 26), '12ABC34501DE35', 1, 1, 1, 12345678, 55);
    R := Consulta.Consultar(Chave);
    Checar((R.Status = seAutorizada) and (R.CStat = 100) and (R.ChaveAcesso = Chave) and
      (R.Protocolo = '135260000000003') and (R.DtRecebimento > 0) and
      (R.ErroTecnico = ''), 'Consulta por chave alfanumerica autorizada: ' + R.ErroTecnico);
    Contem(R.Documento, '<retConsSitNFe', 'XML da resposta de consulta');
    Checar((E.Gravacoes = 0) and (E.Envios = 0) and (E.Eventos = 0), 'Consulta nao grava nem transmite nota/evento');
    E.FalharDepoisResposta := True;
    R := Consulta.Consultar(Chave);
    Checar((R.Status = seAutorizada) and (R.ErroTecnico <> ''), 'Consulta preserva resposta apos excecao');
    E.FalharDepoisResposta := False; E.SemProtocolo := True;
    R := Consulta.Consultar(Chave);
    Checar((R.Status = seIndeterminada) and (R.ErroTecnico <> ''), 'Consulta incompleta nao autoriza');
    E.SemProtocolo := False; E.AmbienteDivergente := True;
    R := Consulta.Consultar(Chave);
    Checar((R.Status = seIndeterminada) and (R.ErroTecnico <> ''), 'Consulta de outro ambiente nao autoriza');
    E.AmbienteDivergente := False; E.ChaveDivergente := True;
    R := Consulta.Consultar(Chave);
    Checar((R.Status = seIndeterminada) and (R.ErroTecnico <> ''), 'Consulta de outra chave nao autoriza');
    E.ChaveDivergente := False; E.CodigoConsulta := 101;
    R := Consulta.Consultar(Chave);
    Checar((R.Status = seCancelada) and (R.CStat = 101) and (R.ErroTecnico = ''), 'Consulta distingue nota cancelada');
    E.CodigoConsulta := 217; E.SemIndividual := True;
    R := Consulta.Consultar(Chave);
    Checar((R.Status = sePendente) and (R.CStat = 217) and (R.ErroTecnico = ''), 'Consulta nao encontrada preserva cStat');
    E.FalharConsulta := True;
    R := Consulta.Consultar(Chave);
    Checar((R.Status = seIndeterminada) and (R.CStat = 0) and (R.Protocolo = '') and
      (R.ErroTecnico <> ''), 'Timeout da consulta nao reutiliza resposta anterior');
    E.FalharConsulta := False; E.SemIndividual := False; E.CodigoConsulta := 100;
    R := Consulta.Consultar('123');
    Checar((R.Status = seRejeitada) and (R.ErroTecnico <> ''), 'Consulta invalida recusada localmente');
    Chave := GerarChaveAcesso(35, EncodeDate(2026, 10, 26), '11222333000181', 1, 2, 9, 12345678, 65);
    R := Consulta.Consultar(Chave);
    Checar((R.Status = seAutorizada) and (E.ACBr.Configuracoes.Geral.ModeloDF = moNFCe), 'Consulta NFC-e seleciona modelo');
    Chave := GerarChaveAcesso(35, EncodeDate(2026, 10, 26), '11222333000181', 1, 3, 7, 12345678, 55);
    R := Consulta.Consultar(Chave);
    Checar((R.Status = seAutorizada) and (E.ACBr.Configuracoes.Geral.ModeloDF = moNFe) and
      (E.ACBr.Configuracoes.Geral.FormaEmissao = ACBrDFe.Conversao.teSVCRS), 'Consulta seleciona SVC pela chave');
  finally Consulta.Free; I := nil; end;
end;

procedure TestarEmissaoPorXML;
var
  E: TEmissorSimulado;
  I: IEmissorNotaFiscal;
  Emitir: TEmitirNotaFiscal;
  N: TNotaFiscal;
  R: TNotaFiscalRetornoEmissao;
  XML, Assinado, Chave: String;
begin
  E := TEmissorSimulado.Create(Config); I := E;
  Emitir := TEmitirNotaFiscal.Create(I); N := NovaNota;
  try
    N.Complementos.InformacoesComplementares := 'XML: a' + #$00E7 + #$00E3 + 'o';
    E.FalharEnvio := True;
    R := E.Emitir(N);
    Assinado := R.Documento;
    Chave := R.ChaveAcesso;
    E.FalharEnvio := False;
    R := Emitir.EmitirPorXML(Assinado);
    Checar((R.Status = seAutorizada) and (R.ChaveAcesso = Chave) and (R.ErroTecnico = ''),
      'Emissao por XML assinado: ' + R.ErroTecnico);
    Contem(R.Documento, N.Complementos.InformacoesComplementares, 'UTF-8 no XML carregado');
    Checar((E.Assinaturas = 1) and (E.ValidacoesXML = 1), 'XML ja assinado e verificado sem nova assinatura');
    Contem(R.Documento, Trim(Assinado.Substring(Pos('<NFe', Assinado) - 1)), 'XML assinado preservado no processado');
    E.FalharEnvio := True; N.NroNota := N.NroNota + 1;
    R := E.Emitir(N); Assinado := R.Documento;
    XML := UTF8ToNativeString(AnsiString(E.ACBr.NotasFiscais[0].GerarXML));
    E.FalharEnvio := False;
    R := Emitir.EmitirPorXML(XML);
    Checar((R.Status = seAutorizada) and (R.ErroTecnico = ''), 'Emissao por XML sem assinatura: ' + R.ErroTecnico);
    Checar(E.Assinaturas = 3, 'XML sem assinatura foi assinado');
    XML := R.Documento;
    E.Envios := 0;
    R := Emitir.EmitirPorXML(XML);
    Checar((R.Status = seRejeitada) and (R.ErroTecnico <> '') and (E.Envios = 0), 'XML processado nao e retransmitido');
    R := Emitir.EmitirPorXML('');
    Checar((R.Status = seRejeitada) and (R.ErroTecnico <> ''), 'XML vazio recusado');
    R := Emitir.EmitirPorXML('<quebrado>');
    Checar((R.Status = seRejeitada) and (R.ErroTecnico <> ''), 'XML invalido recusado');
    R := Emitir.EmitirPorXML(Assinado + Assinado);
    Checar((R.Status = seRejeitada) and (R.ErroTecnico <> ''), 'Mais de uma nota recusada');
    R := Emitir.EmitirPorXML(StringReplace(Assinado, '<tpAmb>2</tpAmb>', '<tpAmb>1</tpAmb>', [rfReplaceAll]));
    Checar((R.Status = seRejeitada) and (R.ErroTecnico <> ''), 'XML de outro ambiente recusado');
    R := Emitir.EmitirPorXML(StringReplace(Assinado, '<cUF>35</cUF>', '<cUF>33</cUF>', []));
    Checar((R.Status = seRejeitada) and (R.ErroTecnico <> ''), 'XML de outra UF recusado');
    E.FalharValidacaoXML := True;
    R := Emitir.EmitirPorXML(Assinado);
    Checar((R.Status = seIndeterminada) and (E.Envios = 0), 'XML local autorizado bloqueia reenvio');
    N.Modelo := mNFCe; N.Destinatario.Informado := False;
    N.NFConfiguracao.TipoEmissao := temContingenciaOffline;
    N.NFConfiguracao.DtContingencia := N.DtEmissao;
    N.NFConfiguracao.JustificativaContingencia := 'Sem comunicacao com o autorizador';
    R := E.Emitir(N); Assinado := R.Documento; Chave := R.ChaveAcesso;
    R := Emitir.EmitirPorXML(Assinado);
    Checar((R.Status = seRejeitada) and (E.Envios = 0) and (E.ValidacoesXML = 2), 'Falha na verificacao do XML nao transmite');
    E.FalharValidacaoXML := False;
    R := Emitir.EmitirPorXML(Assinado);
    Checar((R.Status = seAutorizada) and (R.ChaveAcesso = Chave) and (E.Envios = 1) and
      (R.ErroTecnico = ''), 'Transmissao posterior de NFC-e offline: ' + R.ErroTecnico);
    Contem(R.Documento, '<tpEmis>9</tpEmis>', 'Tipo de emissao offline preservado');
  finally N.Free; Emitir.Free; I := nil; end;
end;

begin
  try
    Pasta := TPath.Combine(ExtractFilePath(ParamStr(0)), 'xml-' + FormatDateTime('yyyymmdd-hhnnss-zzz', Now));
    TestarConfiguracao;
    TestarCasosDeUso;
    TestarFalhas;
    TestarNFCeERegimes;
    TestarMapeamento;
    TestarValidacoesEGrupos;
    TestarRetencaoECredito;
    TestarGravacaoSegura;
    TestarChaveAlfanumerica;
    TestarEstadosEmissao;
    TestarConsultaPorChave;
    TestarEmissaoPorXML;
    Writeln('OK: ', Verificacoes, ' verificacoes locais; sem rede ou certificado real.');
  except
    on E: Exception do begin Writeln(E.ClassName, ': ', E.Message); ExitCode := 1; end;
  end;
end.
