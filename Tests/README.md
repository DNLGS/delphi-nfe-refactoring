# ACBrEmissor: uso e validacao local

O adaptador recebe os valores prontos de `TNotaFiscal`; nao calcula impostos,
nao altera a nota, nao gera numeracao e nao acessa banco, telas ou impressoras.
Use uma instancia por fluxo de execucao: o componente interno possui estado e
nao deve ser compartilhado simultaneamente entre threads.

## Configuracao

Inicialize o record com `Default(TACBrEmissorConfig)` e preencha:

- `UF` e `Ambiente`: obrigatorios e iguais aos da nota. O ambiente nao e inferido
  da chave; em eventos e consultas ele deve corresponder ao documento original.
- `PathSchemas`: schemas NF-e do ACBr compativeis com os grupos utilizados.
- `PathSalvar`: obrigatorio para emitir; o adaptador salva o XML assinado antes
  do envio e o processado depois da autorizacao. Falha antes do envio impede a transmissao.
- `PathSalvarEvento`: vazio usa `PathSalvar`; o adaptador salva o evento processado.
  Falha apos registro conserva os dados fiscais e o XML de resposta disponivel.
- `ArquivoPFX` ou `NumeroSerie`, e `Senha`: selecao explicita do certificado,
  sem dialogos. Nunca preencher os dois identificadores juntos.
- `Modelo`: modelo usado pelo status; zero usa NF-e. Emissao, eventos e consulta
  selecionam o modelo da nota/XML/chave.
- `Timeout`: milissegundos; zero usa 30000.
- `VersaoQRCode`: zero usa 3; versao 2 exige `CSC` e `IdCSC` ao emitir NFC-e.
- `CSRT`: segredo opcional, exigido quando o responsavel tecnico informado na
  nota contem IdCSRT/HashCSRT. O hash deve corresponder a chave da nota.

O adaptador utiliza WinCrypt, WinINet e LibXml2. As DLLs de runtime e os schemas
precisam estar disponiveis no aplicativo consumidor; nao sao instalados pelo
adaptador. Segredos permanecem apenas na configuracao fornecida pelo chamador.

## Retornos e recuperacao

`Documento` contem XML em `String` Unicode do Delphi. O XML assinado antes do
envio e preservado e combinado com o protocolo pelo montador `TProcDFe` do ACBr,
evitando a reconversao de `XMLOriginal` no processamento do retorno.
Os arquivos sao escritos em UTF-8 pelo adaptador.
`ErroTecnico` nao substitui o cStat: uma autorizacao pode coexistir com
falha posterior de gravacao. Sempre examine cStat, chave, protocolo e documento.
Emissao, consulta, cancelamento e CC-e devolvem erros de validacao e falhas tecnicas em
`ErroTecnico`, sem propagar excecoes ao chamador e conservando os dados fiscais
disponiveis. `Motivo` preserva a mensagem fiscal recebida. Configuracao invalida
no construtor continua gerando `ENotaFiscalInvalida`.

Emissao confirmada exige retorno individual de autorizacao, chave correspondente,
protocolo e XML processado. Codigos 103/104/105 sem resultado individual nao
confirmam a nota. Nao existe reenvio automatico. Em timeout ou duplicidade,
consulte/reconcilie a situacao na SEFAZ antes de qualquer novo envio. O chamador
decide quando consultar e quando solicitar uma transmissao por XML.

NFC-e offline retorna XML assinado salvo, `CStat=0`, protocolo vazio e motivo de
pendencia. Isso nao representa autorizacao. Um XML local autorizado nao e
sobrescrito pela preparacao de outro envio com a mesma chave: a verificacao ocorre
antes da assinatura. A gravacao automatica do ACBr fica desabilitada para notas e
eventos. O adaptador escreve em um temporario na mesma pasta e substitui o destino
somente depois de concluir a escrita, conservando o anterior se houver falha.
Uma falha de disco depois da autorizacao conserva o estado autorizado e o XML no retorno.

Na emissao, `Status` so e `seAutorizada` com retorno individual completo, protocolo, chave e
ambiente correspondentes e XML processado. Rejeicoes fiscais e falhas locais
anteriores ao envio usam `seRejeitada`. Timeout de envio, autorizacao incompleta,
lote sem resultado individual, duplicidades 204/539 e bloqueio por XML autorizado
existente usam `seIndeterminada`: exigem consulta/reconciliacao antes de novo envio.
A NFC-e offline permanece `sePendente`.

Na emissao por entidade, os CSTs ICMS monofasicos 02, 15, 53 e 61 sao recusados
antes da transmissao, pois o modelo ainda nao representa seus campos especificos. O suporte exige ampliar
o modelo e o mapeamento, mantendo os calculos a cargo do chamador.

Cancelamento recebe chave, justificativa e protocolo (15 ou 17 digitos), com
sequencia 1. CC-e recebe chave NF-e modelo 55, texto e sequencia 1..20.
Justificativa: 15..255 caracteres; correcao: 15..1000. Nao e necessario XML local.
O lote 128 sozinho nao comprova evento; 136 preserva registro sem vinculo,
218/573 permanecem codigos de situacao/duplicidade, sem conversao em novo sucesso.
`Sequencia` e `Ambiente` sempre repetem os dados solicitados, inclusive em falhas locais.
`TNotaFiscalRetornoEvento.Status` usa `TStatusEvento`:

- `steRejeitado`: validacao/falha local antes da transmissao ou rejeicao fiscal.
- `steIndeterminado`: timeout, lote 128 sem retorno individual, resposta divergente,
  protocolo/XML processado ausente, indisponibilidade ou situacao/duplicidade 218/573.
  O resultado exige consulta/reconciliacao antes de um novo envio.
- `steRegistradoComVinculo`: cStat 135/155, com retorno individual correspondente,
  protocolo e XML processado.
- `steRegistradoSemVinculo`: cStat 136, com as mesmas conferencias.

Falha ao salvar o XML depois do registro conserva o status de registro e os dados
fiscais; `ErroTecnico` informa a falha de gravacao. `CStat` conserva o codigo fiscal.
Consulta continua retornando `TNotaFiscalRetornoEmissao`; nao integra `TTipoEvento`.
`DtRegistro` utiliza ISO 8601. O chamador libera o objeto `TSefazStatus` retornado.

## Identificacao na persistencia

`TSalvarDadosEmissao.Inserir/Atualizar` e
`INotaFiscalRepository.InserirEmissao/AtualizarEmissao` recebem
`AReferenciaNota: String` antes do retorno. O chamador fornece uma referencia
estavel e unica da nota no sistema de origem, incluindo o contexto de empresa
quando necessario. Ela independe da chave fiscal e deve ser a mesma ao inserir e
atualizar, inclusive se a emissao falhar antes de gerar a chave.
O caso de uso recusa referencia vazia; o repositorio deve usar essa referencia
para localizar a nota, sem tentar identifica-la apenas pelo retorno.

Exemplo: `Salvar.Inserir('empresa:1/movto:123', Retorno)`.
As implementacoes externas do repositorio e seus chamadores precisam adaptar
as duas assinaturas; o GUID da interface mudou com o contrato.
Este projeto fornece somente a interface, sem implementacao de banco.
Eventos continuam identificados por chave, tipo, sequencia e ambiente do retorno.

## Consulta por chave e emissao por XML

`IEmissorNotaFiscal.ConsultarPorChave(AChave)` retorna `TNotaFiscalRetornoEmissao`.
O caso de uso `TConsultarNotaFiscal.Consultar` expoe a mesma operacao. A consulta
recebe chave NF-e/NFC-e, confere UF/ambiente e nao exige XML local, nao salva arquivo
nem transmite nota/evento. Chaves SVC selecionam a forma de emissao correspondente.
`Documento` contem o XML da resposta `retConsSitNFe`, nao o download da NF-e.
Autorizacao exige protocolo correspondente; cancelamento retorna `seCancelada`
(novo valor ao final do enum). CStat 217 retorna `sePendente`; falha de rede ou
resposta divergente retorna `seIndeterminada`. O cStat original e sempre preservado.

`IEmissorNotaFiscal.EmitirPorXML(AXML)` e `TEmitirNotaFiscal.EmitirPorXML(AXML)`
recebem uma `String` Unicode com uma unica NF-e/NFC-e. XML vazio, invalido, com mais
de uma nota, ja processado, de outra UF ou de outro ambiente e recusado antes do envio.
XML sem assinatura e assinado pelo certificado configurado. XML ja assinado passa
pela validacao de schema, regras de negocio e verificacao criptografica do ACBr,
sem nova assinatura. A chave e a forma de emissao do documento sao preservadas.
O envio e a gravacao usam o mesmo fluxo da emissao por entidade.

Diferente de `Emitir(Nota)` em contingencia offline, `EmitirPorXML` solicita a
transmissao: pode enviar posteriormente o XML offline salvo, conservando `tpEmis=9`.
O chamador deve reconciliar timeouts e duplicidades antes de solicitar outro envio.
Esses metodos nao controlam numeracao, persistencia no ERP nem reenvio automatico.

## Compilacao e testes

Projeto console `ACBrEmissorTests.dproj`, Delphi XE7 / Win32, ACBr instalado em
`C:\ACBr\Lib\Delphi\LibD21\Win32\Release`. Ajuste essa referencia do projeto se
sua instalacao estiver em outro local. Pelo terminal do Delphi:

```text
msbuild ACBrEmissorTests.dproj /t:Build /p:Config=Debug /p:Platform=Win32
build\ACBrEmissorTests.exe
```

Os testes substituem assinatura, verificacao criptografica/schema e transporte
por simulacoes e usam a geracao de XML e os leitores reais do ACBr, com a gravacao
real do adaptador. A assinatura sintetica identifica apenas a simulacao: nao tem
validade criptografica. Nao ha acesso a certificado real,
rede ou SEFAZ, nem validacao criptografica/schema dos XMLs sinteticos.

Os cenarios conferem emissao por entidade/XML, consulta por chave, cancelamento,
CC-e, status de servico, regimes tributarios, NF-e/NFC-e,
offline, grupos opcionais, IBS/CBS/CSRT, codigos fiscais, rejeicoes, retorno
incompleto/divergente, estados de emissao, chave alfanumerica, UTF-8 e falhas de
gravacao antes/depois do envio. Uma escrita parcial do temporario e a substituicao
de um destino bloqueado verificam a preservacao do arquivo anterior e a limpeza
dos temporarios. A consulta cobre autorizacao, cancelamento, nota nao encontrada,
resposta divergente e timeout. A emissao por XML cobre assinatura existente/ausente,
validacao recusada, preservacao do documento e transmissao posterior de NFC-e offline.
Os XMLs de cada execucao ficam em `build/xml-<data-hora>` para inspecao.
Combinacoes fiscais reais que exijam dados alem dos campos modelados precisam
ser ajustadas no chamador e validadas pelos schemas/regras do ACBr.
