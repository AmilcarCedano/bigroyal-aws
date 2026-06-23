resource "aws_db_subnet_group" "this" {
  name       = "${var.resource_prefix}-db-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = var.common_tags
}

resource "aws_iam_role" "rds_monitoring" {
  name = "${var.resource_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Cluster Aurora PostgreSQL Multi-AZ (cifrado KMS — RNF-15)
resource "aws_rds_cluster" "this" {
  cluster_identifier      = "${var.resource_prefix}-aurora-cluster"
  engine                  = "aurora-postgresql"
  engine_version          = var.engine_version
  database_name           = var.db_name
  master_username         = var.db_master_username
  master_password         = var.db_master_password
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = var.security_group_ids

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"

  iam_database_authentication_enabled = true

  skip_final_snapshot = true

  tags = var.common_tags
}

# Instancia Writer en AZ-a — Multi-AZ con Standby en AZ-b (RNF-13)
resource "aws_rds_cluster_instance" "writer" {
  identifier         = "${var.resource_prefix}-aurora-writer"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  auto_minor_version_upgrade = true

  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.kms_key_arn

  tags = var.common_tags
}

# Instancia Standby AZ-b — failover automático ≤ 30 s (RNF-13)
resource "aws_rds_cluster_instance" "standby" {
  identifier         = "${var.resource_prefix}-aurora-standby"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  auto_minor_version_upgrade = true

  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.kms_key_arn

  tags = var.common_tags
}

# Asociación del plan de AWS Backup al cluster Aurora — RPO ≤ 5 min (RNF-14).
# Se referencia aws_rds_cluster.this.arn directamente para que el grafo de
# Checkov resuelva el enlace recurso→backup (CKV2_AWS_8).
resource "aws_backup_selection" "this" {
  name         = "${var.resource_prefix}-aurora-selection"
  plan_id      = var.backup_plan_id
  iam_role_arn = var.backup_role_arn

  resources = [aws_rds_cluster.this.arn]
}

# Read Replica — solo reportes, sin afectar al Writer (RNF-13)
resource "aws_rds_cluster_instance" "reader" {
  identifier         = "${var.resource_prefix}-aurora-reader"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  auto_minor_version_upgrade = true

  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.kms_key_arn

  tags = var.common_tags
}
