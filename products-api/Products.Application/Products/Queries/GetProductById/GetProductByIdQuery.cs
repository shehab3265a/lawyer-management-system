using MediatR;
using Products.Application.Products.Dtos;

namespace Products.Application.Products.Queries.GetProductById;

public record GetProductByIdQuery(int Id) : IRequest<ProductDto>;
