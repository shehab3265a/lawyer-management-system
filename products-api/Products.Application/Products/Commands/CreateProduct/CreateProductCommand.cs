using MediatR;
using Products.Application.Products.Dtos;

namespace Products.Application.Products.Commands.CreateProduct;

public record CreateProductCommand(string Name, decimal Price) : IRequest<ProductDto>;
