using MediatR;
using Products.Application.Common.Interfaces;
using Products.Application.Products.Dtos;

namespace Products.Application.Products.Queries.GetProducts;

public class GetProductsQueryHandler : IRequestHandler<GetProductsQuery, IReadOnlyList<ProductDto>>
{
    private readonly IProductRepository _products;

    public GetProductsQueryHandler(IProductRepository products)
    {
        _products = products;
    }

    public async Task<IReadOnlyList<ProductDto>> Handle(
        GetProductsQuery request,
        CancellationToken cancellationToken)
    {
        var products = await _products.GetAllAsync(cancellationToken);

        return products
            .Select(p => new ProductDto(p.Id, p.Name, p.Price))
            .ToList();
    }
}
