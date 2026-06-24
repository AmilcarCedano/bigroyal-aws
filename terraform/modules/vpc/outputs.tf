output "vpc_id"              { value = aws_vpc.this.id }
output "private_subnet_a_id" { value = aws_subnet.private_a.id }
output "private_subnet_b_id" { value = aws_subnet.private_b.id }
output "public_subnet_a_id"  { value = aws_subnet.public_a.id }
output "private_subnet_ids"  { value = [aws_subnet.private_a.id, aws_subnet.private_b.id] }
output "vpc_cidr_block"      { value = aws_vpc.this.cidr_block }
