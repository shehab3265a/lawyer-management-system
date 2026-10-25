using MediatR;
using Products.Application.Products.Dtos;

namespace Products.Application.Products.Queries.GetProducts;

public record GetProductsQuery() : IRequest<IReadOnlyList<ProductDto>>;
