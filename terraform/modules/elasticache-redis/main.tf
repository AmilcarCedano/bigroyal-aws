# SG de Redis — ingress desde VPC CIDR — CKV2_AWS_5
resource "aws_security_group" "redis" {
  name        = "${var.resource_prefix}-redis-sg"
  description = "SG ElastiCache Redis - ingress from VPC CIDR"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Redis desde Lambdas en VPC"
  }

  tags = merge(var.common_tags, { Name = "${var.resource_prefix}-redis-sg" })
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.resource_prefix}-redis-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = var.common_tags
}

resource "aws_elasticache_cluster" "this" {
  cluster_id           = "${var.resource_prefix}-redis"
  engine               = "redis"
  node_type            = var.node_type
  num_cache_nodes      = var.num_cache_nodes
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.redis.id]

  snapshot_retention_limit = 7
  snapshot_window          = "03:00-04:00"

  tags = var.common_tags
}
