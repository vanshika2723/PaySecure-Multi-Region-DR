
output "table_id" {
  description = "DynamoDB table ID."
  value       = aws_dynamodb_table.this.id
}

output "table_arn" {
  description = "DynamoDB table ARN."
  value       = aws_dynamodb_table.this.arn
}

output "table_name" {
  description = "DynamoDB table name."
  value       = aws_dynamodb_table.this.name
}

output "table_stream_arn" {
  description = "DynamoDB Stream ARN."
  value       = aws_dynamodb_table.this.stream_arn
}

output "table_stream_label" {
  description = "DynamoDB Stream label."
  value       = aws_dynamodb_table.this.stream_label
}

output "hash_key" {
  description = "DynamoDB partition key."
  value       = aws_dynamodb_table.this.hash_key
}

output "range_key" {
  description = "DynamoDB sort key."
  value       = aws_dynamodb_table.this.range_key
}

output "replica_regions" {
  description = "Configured DynamoDB Global Table replica regions."
  value       = var.replica_regions
}

