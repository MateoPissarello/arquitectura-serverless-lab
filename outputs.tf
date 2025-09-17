output "function_url" {
  description = "Public Function URL for POST /orders"
  value       = aws_lambda_function_url.http_url.function_url
}

output "orders_table" {
  value = aws_dynamodb_table.orders.name
}

output "orders_enriched_table" {
  value = aws_dynamodb_table.orders_enriched.name
}
