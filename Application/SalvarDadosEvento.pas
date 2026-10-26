unit SalvarDadosEvento;

interface

uses NotaFiscal.RetornoEvento, NotaFiscalRepository.Intf;

type
  TSalvarDadosEvento = class
  private
    FRepo : INotaFiscalRepository;
  public
    constructor Create(ARepo : INotaFiscalRepository);
    procedure Inserir(const ADados : TNotaFiscalRetornoEvento);
    procedure Atualizar(const ADados : TNotaFiscalRetornoEvento);
  end;

implementation

{ TSalvarDadosEvento }

procedure TSalvarDadosEvento.Atualizar(const ADados: TNotaFiscalRetornoEvento);
begin
  FRepo.AtualizarEvento(ADados);
end;

constructor TSalvarDadosEvento.Create(ARepo: INotaFiscalRepository);
begin
  FRepo := ARepo;
end;

procedure TSalvarDadosEvento.Inserir(const ADados: TNotaFiscalRetornoEvento);
begin
  FRepo.InserirEvento(ADados);
end;

end.
