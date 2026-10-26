# Refatoração de rotinas de nota fiscal em Delphi

Projeto de refatoração de rotinas fiscais e estudo de arquitetura de software, com foco na separação de responsabilidades entre domínio, casos de uso e integração com o ACBr.

O código reúne operações de NF-e e NFC-e em Delphi. A proposta é evoluir a organização de uma rotina existente e estudar suas fronteiras, contratos e dependências. O repositório contém unidades para integração em uma aplicação consumidora; não oferece um ERP ou uma aplicação de usuário final.

## Operações disponíveis

- Emissão a partir de `TNotaFiscal` ou de uma string XML.
- Consulta de nota pela chave de acesso.
- Consulta do status do serviço.
- Cancelamento por chave, justificativa e protocolo de autorização.
- Carta de Correção de NF-e por chave, texto e sequência.
- Casos de uso para inserir e atualizar retornos de emissão e eventos por meio de um contrato de repositório.

## Organização

| Pasta | Responsabilidade |
| --- | --- |
| `Domain/Entitys` | Modelo da nota, itens, impostos, participantes, configuração, validações e retornos fiscais. |
| `Domain/Interfaces` | Contrato `INotaFiscalRepository` para persistência dos retornos. |
| `Application` | Casos de uso de emissão, consulta, cancelamento, CC-e e gravação de retornos. |
| `Infrastructure/Interfaces` | Contrato `IEmissorNotaFiscal`, utilizado pelos casos de uso fiscais. |
| `Infrastructure/Services` | Adaptador `TACBrEmissor`, responsável pelo mapeamento para o ACBr, comunicação fiscal e gravação de XML. |
| `Tests` | Projeto console de verificações locais com transporte e assinatura simulados. |
| `graphify-out` | Grafo de conhecimento para navegação e análise do projeto. |

Os casos de uso recebem as dependências pelo construtor. Por exemplo, `TEmitirNotaFiscal` utiliza `IEmissorNotaFiscal`, implementada por `TACBrEmissor`; `TSalvarDadosEmissao` utiliza `INotaFiscalRepository`.

A separação está em evolução: atualmente o contrato do emissor fica em `Infrastructure/Interfaces`, e a aplicação referencia essa unidade. A estrutura expressa o estudo de arquitetura, sem pressupor isolamento completo entre as camadas.

## Responsabilidades do sistema consumidor

O chamador fornece os dados da nota e os valores fiscais já calculados. Também controla numeração, sequência de CC-e, configuração do ambiente e certificado, persistência no sistema de origem e reconciliação de resultados indeterminados.

Este projeto fornece a interface de repositório, mas não uma implementação de banco de dados. Para salvar emissões, o chamador informa uma referência estável e única da nota, inclusive quando ainda não existe chave fiscal.

O adaptador possui estado: use uma instância por fluxo de execução, sem compartilhamento simultâneo entre threads.

## Ambiente e uso

- Delphi XE7 e Windows. O projeto de testes está configurado para Win32.
- ACBr com as unidades de NF-e disponíveis no caminho de busca.
- Schemas compatíveis e DLLs exigidas pelo ACBr para uso com WinCrypt, WinINet e LibXml2.
- Para operações reais: certificado, configuração fiscal e acesso aos serviços correspondentes.

O arquivo `Tests/ACBrEmissorTests.dproj` referencia o ACBr em `C:\ACBr\Lib\Delphi\LibD21\Win32\Release`. Ajuste o caminho para a instalação local.

Para integrar, adicione as pastas das unidades ao caminho de busca da aplicação, inicialize `TACBrEmissorConfig` com `Default(TACBrEmissorConfig)`, preencha a configuração e injete o emissor nos casos de uso. Não versione certificados, senhas, CSC ou CSRT.

As opções de configuração, os contratos de retorno e as instruções de compilação e execução dos testes estão em [Tests/README.md](Tests/README.md).

## Cuidados com os retornos

Examine o status, `CStat`, chave, protocolo, documento e `ErroTecnico` em conjunto. Uma falha ao salvar XML após uma autorização pode coexistir com um resultado fiscal aceito.

Não há reenvio automático. Timeouts, duplicidades e respostas incompletas exigem consulta e reconciliação antes de uma nova transmissão. NFC-e offline permanece pendente até a autorização posterior.

## Validação e limites

Os testes locais substituem assinatura, validação criptográfica/schema e transporte por simulações, utilizando partes reais do ACBr para geração e leitura de XML e a gravação real do adaptador. Eles não comprovam integração com certificado, rede ou SEFAZ.

A criação deste README foi baseada na leitura dos arquivos, sem executar compilação ou testes. A presença do projeto de testes não constitui evidência de aprovação da versão atual. Validação em homologação continua necessária antes de uso real.
