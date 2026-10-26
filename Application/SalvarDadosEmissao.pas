unit SalvarDadosEmissao;

interface

uses NotaFiscalRepository.Intf, NotaFiscal.RetornoEmissao;

type
  TSalvarDadosEmissao = class
  private
    FRepo : INotaFiscalRepository;
  public
    constructor Create(ARepo : INotaFiscalRepository);
    procedure Inserir(const AReferenciaNota: String;
      const ADadosEmissao : TNotaFiscalRetornoEmissao);
    procedure Atualizar(const AReferenciaNota: String;
      const ADadosEmissao : TNotaFiscalRetornoEmissao);
  end;

implementation

uses System.SysUtils, NotaFiscal.Validacao;

{ TSalvarDadosRetorno }

procedure TSalvarDadosEmissao.Atualizar(const AReferenciaNota: String;
  const ADadosEmissao: TNotaFiscalRetornoEmissao);
begin
  TValidacaoNotaFiscal.Exigir(Trim(AReferenciaNota) <> '', 'Referencia da nota obrigatoria.');
  FRepo.AtualizarEmissao(AReferenciaNota, ADadosEmissao);
end;

constructor TSalvarDadosEmissao.Create(ARepo: INotaFiscalRepository);
begin
  FRepo := ARepo;
end;

procedure TSalvarDadosEmissao.Inserir(const AReferenciaNota: String;
  const ADadosEmissao: TNotaFiscalRetornoEmissao);
begin
  TValidacaoNotaFiscal.Exigir(Trim(AReferenciaNota) <> '', 'Referencia da nota obrigatoria.');
  FRepo.InserirEmissao(AReferenciaNota, ADadosEmissao);
end;

end.
