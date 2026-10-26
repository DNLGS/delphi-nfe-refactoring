unit NotaFiscal.Item;

interface

uses
  NotaFiscal.Types, NotaFiscal.Impostos, NotaFiscal.ProdutoEspecifico;

type
  TNotaFiscalItem = class
  private
    FNumero, FItemPedido: Integer;
    FCodigoProduto, FDescricao, FNCM, FCEST, FEXTIPI, FCFOP, FCodigoBeneficio: String;
    FGTIN, FGTINTributavel, FUnidade, FUnidadeTributavel, FPedido, FInformacoesAdicionais: String;
    FQuantidade, FQuantidadeTributavel, FValorUnitario, FValorUnitarioTributavel: Double;
    FValorProdutos, FDesconto, FFrete, FSeguro, FOutrasDespesas: Currency;
    FCompoeTotal: Boolean;
    FImpostos: TNotaFiscalImpostos;
    FEspecifico: TNotaFiscalProdutoEspecifico;
  public
    constructor Create(ANumero: Integer);
    destructor Destroy; override;
    procedure Validar(ARegime: TRegimeTributario; AFinalidade: TTipoFinalidade);
    property Numero: Integer read FNumero;
    property CodigoProduto: String read FCodigoProduto write FCodigoProduto;
    property Descricao: String read FDescricao write FDescricao;
    property NCM: String read FNCM write FNCM;
    property CEST: String read FCEST write FCEST;
    property EXTIPI: String read FEXTIPI write FEXTIPI;
    property CFOP: String read FCFOP write FCFOP;
    property CodigoBeneficio: String read FCodigoBeneficio write FCodigoBeneficio;
    property GTIN: String read FGTIN write FGTIN;
    property GTINTributavel: String read FGTINTributavel write FGTINTributavel;
    property Unidade: String read FUnidade write FUnidade;
    property UnidadeTributavel: String read FUnidadeTributavel write FUnidadeTributavel;
    property Quantidade: Double read FQuantidade write FQuantidade;
    property QuantidadeTributavel: Double read FQuantidadeTributavel write FQuantidadeTributavel;
    property ValorUnitario: Double read FValorUnitario write FValorUnitario;
    property ValorUnitarioTributavel: Double read FValorUnitarioTributavel write FValorUnitarioTributavel;
    property ValorProdutos: Currency read FValorProdutos write FValorProdutos;
    property Desconto: Currency read FDesconto write FDesconto;
    property Frete: Currency read FFrete write FFrete;
    property Seguro: Currency read FSeguro write FSeguro;
    property OutrasDespesas: Currency read FOutrasDespesas write FOutrasDespesas;
    property CompoeTotal: Boolean read FCompoeTotal write FCompoeTotal;
    property Pedido: String read FPedido write FPedido;
    property ItemPedido: Integer read FItemPedido write FItemPedido;
    property InformacoesAdicionais: String read FInformacoesAdicionais write FInformacoesAdicionais;
    property Impostos: TNotaFiscalImpostos read FImpostos;
    property Especifico: TNotaFiscalProdutoEspecifico read FEspecifico;
  end;

implementation

uses
  System.SysUtils, NotaFiscal.Validacao;

constructor TNotaFiscalItem.Create(ANumero: Integer);
begin
  inherited Create;
  TValidacaoNotaFiscal.Exigir((ANumero >= 1) and (ANumero <= 990), 'Numero do item deve estar entre 1 e 990.');
  FNumero := ANumero;
  FCompoeTotal := True;
  FGTIN := 'SEM GTIN';
  FGTINTributavel := 'SEM GTIN';
  FImpostos := TNotaFiscalImpostos.Create;
  FEspecifico := TNotaFiscalProdutoEspecifico.Create;
end;

destructor TNotaFiscalItem.Destroy;
begin
  FEspecifico.Free;
  FImpostos.Free;
  inherited;
end;

procedure ValidarGTIN(const AValor: String);
var
  I, Peso, Soma, DV: Integer;
begin
  if AValor = 'SEM GTIN' then
    Exit;
  TValidacaoNotaFiscal.Exigir(Length(AValor) in [8, 12, 13, 14], 'GTIN deve ter 8, 12, 13 ou 14 digitos, ou SEM GTIN.');
  TValidacaoNotaFiscal.Digitos(AValor, 'GTIN', Length(AValor));
  TValidacaoNotaFiscal.Exigir(AValor <> StringOfChar('0', Length(AValor)), 'GTIN nao pode ser zerado.');
  Soma := 0;
  Peso := 3;
  for I := Length(AValor) - 1 downto 1 do
  begin
    Soma := Soma + (Ord(AValor[I]) - Ord('0')) * Peso;
    Peso := 4 - Peso;
  end;
  DV := (10 - Soma mod 10) mod 10;
  TValidacaoNotaFiscal.Exigir(DV = Ord(AValor[Length(AValor)]) - Ord('0'), 'Digito verificador do GTIN invalido.');
end;

procedure TNotaFiscalItem.Validar(ARegime: TRegimeTributario; AFinalidade: TTipoFinalidade);
begin
  TValidacaoNotaFiscal.Texto(FCodigoProduto, 'Codigo do produto', 60);
  TValidacaoNotaFiscal.Texto(FDescricao, 'Descricao do produto', 120);
  if FImpostos.ISSQN.Informado then
    TValidacaoNotaFiscal.Exigir(FNCM = '00', 'Servico deve informar NCM 00.')
  else
    TValidacaoNotaFiscal.Digitos(FNCM, 'NCM', 8);
  TValidacaoNotaFiscal.Digitos(FCEST, 'CEST', 7, False);
  TValidacaoNotaFiscal.Digitos(FEXTIPI, 'EX TIPI', 3, False);
  TValidacaoNotaFiscal.Digitos(FCFOP, 'CFOP', 4);
  TValidacaoNotaFiscal.Exigir(CharInSet(FCFOP[1], ['1', '2', '3', '5', '6', '7']), 'CFOP deve iniciar por 1, 2, 3, 5, 6 ou 7.');
  TValidacaoNotaFiscal.Texto(FCodigoBeneficio, 'Codigo de beneficio fiscal', 10, False);
  ValidarGTIN(FGTIN);
  ValidarGTIN(FGTINTributavel);
  TValidacaoNotaFiscal.Texto(FUnidade, 'Unidade comercial', 6);
  TValidacaoNotaFiscal.Texto(FUnidadeTributavel, 'Unidade tributavel', 6);
  TValidacaoNotaFiscal.Valores([FQuantidade, FQuantidadeTributavel, FValorUnitario,
    FValorUnitarioTributavel, FValorProdutos, FDesconto, FFrete, FSeguro,
    FOutrasDespesas], 'Valores/quantidades do item');
  if AFinalidade in [tfNormal, tfDevolucao] then
  begin
    TValidacaoNotaFiscal.Exigir((FQuantidade > 0) and (FQuantidadeTributavel > 0), 'Quantidades comercial e tributavel devem ser positivas.');
    TValidacaoNotaFiscal.Exigir(Abs(FValorProdutos - FQuantidade * FValorUnitario) <= 0.010001, 'Valor do produto difere da quantidade x valor unitario comercial.');
    TValidacaoNotaFiscal.Exigir(Abs(FValorProdutos - FQuantidadeTributavel * FValorUnitarioTributavel) <= 0.010001, 'Valor do produto difere da quantidade x valor unitario tributavel.');
  end;
  TValidacaoNotaFiscal.Exigir(FDesconto <= FValorProdutos, 'Desconto excede o valor do produto.');
  TValidacaoNotaFiscal.Texto(FPedido, 'Pedido de compra', 15, False);
  TValidacaoNotaFiscal.Exigir((FItemPedido >= 0) and (FItemPedido <= 999999), 'Item do pedido invalido.');
  TValidacaoNotaFiscal.Exigir((FItemPedido = 0) or (FPedido <> ''), 'Item do pedido exige numero do pedido.');
  TValidacaoNotaFiscal.Texto(FInformacoesAdicionais, 'Informacoes adicionais do item', 500, False);
  FImpostos.Validar(ARegime);
  FEspecifico.Validar;
end;

end.
