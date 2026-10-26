unit NotaFiscal.Types;

interface

type
  TModeloNotaFiscal = (mNFE = 55, mNFCe = 65);
  // Os valores correspondem aos codigos fiscais, nao aos ordinais do ACBr.
  TTipoNota = (teEntrada = 0, teSaida = 1);
  TTipoFinalidade = (tfNormal = 1, tfComplementar = 2, tfAjuste = 3,
    tfDevolucao = 4, tfCredito = 5, tfDebito = 6);
  TTipoEmissao = (temNormal = 1, temContingenciaFSIA = 2, temSCAN = 3,
    temEPEC = 4, temContingenciaFSDA = 5, temSVCAN = 6, temSVCRS = 7,
    temContingenciaOffline = 9);
  TTipoAmbiente = (taProducao = 1, taHomologacao = 2);
  TTipoIntermediador = (tiSemIntermediador = 0, tiComIntermediador = 1);
  TTipoDestinoOperacao = (tdInterna = 1, tdInterestadual = 2, tdExterior = 3);
  TTipoConsumidorFinal = (tcNaoFinal = 0, tcFinal = 1);
  TTipoPresencaConsumidor = (tpNaoSeAplica = 0, tpPresencial = 1,
    tpInternet = 2, tpTeleatendimento = 3, tpEntregaDomicilio = 4,
    tpPresencialForaEstabelecimento = 5, tpOutros = 9);
  TRegimeTributario = (rtSimplesNacional = 1, rtSimplesExcessoSublimite = 2,
    rtRegimeNormal = 3, rtMEI = 4);
  TIndicadorIEDestinatario = (ieContribuinte = 1, ieIsento = 2,
    ieNaoContribuinte = 9);
  TModalidadeFrete = (mfEmitente = 0, mfDestinatario = 1, mfTerceiros = 2,
    mfProprioRemetente = 3, mfProprioDestinatario = 4, mfSemFrete = 9);
  TIndicadorPagamento = (ipVista = 0, ipPrazo = 1);
  TIntegracaoPagamento = (itNaoInformada = 0, itIntegrado = 1, itNaoIntegrado = 2);
  TTipoEvento = (teCancelamento, teCartaCorrecao);
  TStatusEvento = (
    steIndeterminado,
    steRejeitado,
    steRegistradoComVinculo,
    steRegistradoSemVinculo);
  TStatusEmissao = (
    sePendente,
    seAutorizada,
    seRejeitada,
    seIndeterminada,
    seCancelada);

implementation

end.
