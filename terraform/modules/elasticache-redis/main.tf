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
  security_group_ids = var.security_group_ids

  tags = var.common_tags
}
