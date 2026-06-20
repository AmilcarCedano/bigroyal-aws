output "vpc_id"                { value = aws_vpc.this.id }
output "private_subnet_a_id"  { value = aws_subnet.private_a.id }
output "private_subnet_b_id"  { value = aws_subnet.private_b.id }
output "public_subnet_a_id"   { value = aws_subnet.public_a.id }
output "lambda_sg_id"         { value = aws_security_group.lambda.id }
output "db_sg_id"             { value = aws_security_group.db.id }
output "redis_sg_id"          { value = aws_security_group.redis.id }
