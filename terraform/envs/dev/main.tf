locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.env
    ManagedBy   = "terraform"
  }
}

# ─────────────────────────────────────────────
# CAPA TRANSVERSAL: KMS + IAM + CloudTrail
# ─────────────────────────────────────────────

module "kms" {
  source = "../../modules/kms"

  project_name    = var.project_name
  env             = var.env
  resource_prefix = var.resource_prefix
  common_tags     = local.common_tags
}

module "iam_users" {
  source = "../../modules/iam-users"

  project_name    = var.project_name
  env             = var.env
  resource_prefix = var.resource_prefix
  common_tags     = local.common_tags
}

module "cloudtrail" {
  source = "../../modules/cloudtrail"

  project_name    = var.project_name
  env             = var.env
  resource_prefix = var.resource_prefix
  aws_region      = var.aws_region
  common_tags     = local.common_tags
  kms_key_arn     = module.kms.key_arn
}

# ─────────────────────────────────────────────
# CAPA 3: Red (VPC)
# ─────────────────────────────────────────────

module "vpc" {
  source = "../../modules/vpc"

  project_name    = var.project_name
  env             = var.env
  resource_prefix = var.resource_prefix
  aws_region      = var.aws_region
  common_tags     = local.common_tags
}

# ─────────────────────────────────────────────
# CAPA 1 — Presentación: WAF + S3 + CloudFront + Route 53
# ─────────────────────────────────────────────

module "waf" {
  source = "../../modules/waf"

  project_name    = var.project_name
  env             = var.env
  resource_prefix = var.resource_prefix
  common_tags     = local.common_tags
}

module "s3_frontend" {
  source = "../../modules/s3-frontend"

  project_name    = var.project_name
  env             = var.env
  resource_prefix = var.resource_prefix
  common_tags     = local.common_tags
  kms_key_arn     = module.kms.key_arn
}

module "cloudfront" {
  source = "../../modules/cloudfront"

  project_name       = var.project_name
  env                = var.env
  resource_prefix    = var.resource_prefix
  aws_region         = var.aws_region
  common_tags        = local.common_tags
  s3_bucket_id       = module.s3_frontend.bucket_name
  s3_bucket_arn      = module.s3_frontend.bucket_arn
  origin_domain_name = module.s3_frontend.bucket_regional_domain_name
  web_acl_arn        = module.waf.web_acl_arn
  kms_key_arn        = module.kms.key_arn
}

module "route53" {
  source = "../../modules/route53"

  project_name      = var.project_name
  env               = var.env
  resource_prefix   = var.resource_prefix
  common_tags       = local.common_tags
  domain_name       = var.domain_name
  cloudfront_domain = module.cloudfront.cdn_domain_name
}

# ─────────────────────────────────────────────
# CAPA 2 — API y Lógica
# ─────────────────────────────────────────────

module "cognito" {
  source = "../../modules/cognito"

  project_name       = var.project_name
  env                = var.env
  resource_prefix    = var.resource_prefix
  aws_region         = var.aws_region
  common_tags        = local.common_tags
  oauth_callback_url = "https://${module.cloudfront.cdn_domain_name}/index.html"
  oauth_logout_url   = "https://${module.cloudfront.cdn_domain_name}/index.html"
}

module "secrets_manager" {
  source = "../../modules/secrets-manager"

  project_name       = var.project_name
  env                = var.env
  resource_prefix    = var.resource_prefix
  common_tags        = local.common_tags
  db_name            = var.db_name
  db_master_username = var.db_master_username
  kms_key_arn        = module.kms.key_arn
}

# Lambda principal: Pedidos y Órdenes (RNF-07: <200 ms)
module "lambda_backend" {
  source = "../../modules/lambda-backend"

  project_name       = var.project_name
  env                = var.env
  resource_prefix    = var.resource_prefix
  common_tags        = local.common_tags
  function_name      = "${var.resource_prefix}-backend"
  db_secret_arn      = module.secrets_manager.db_secret_arn
  redis_endpoint     = module.redis.endpoint
  sns_topic_arn      = module.sns_sqs.fanout_topic_arn
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.lambda_security_group_id]
  kms_key_arn        = module.kms.key_arn
}

# Lambda KDS Cocina — actualiza pantalla cocina en paralelo, <1 s (RNF-08)
module "lambda_kds_cocina" {
  source = "../../modules/lambda-kds-cocina"

  project_name       = var.project_name
  env                = var.env
  resource_prefix    = var.resource_prefix
  common_tags        = local.common_tags
  redis_endpoint     = module.redis.endpoint
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.lambda_security_group_id]
  kms_key_arn        = module.kms.key_arn
}

module "api_gateway" {
  source = "../../modules/api-gateway"

  project_name          = var.project_name
  env                   = var.env
  resource_prefix       = var.resource_prefix
  aws_region            = var.aws_region
  common_tags           = local.common_tags
  lambda_arn            = module.lambda_backend.lambda_arn
  cognito_user_pool_id  = module.cognito.user_pool_id
  cognito_app_client_id = module.cognito.app_client_id
  kms_key_arn           = module.kms.key_arn
}

module "redis" {
  source = "../../modules/elasticache-redis"

  project_name       = var.project_name
  env                = var.env
  resource_prefix    = var.resource_prefix
  common_tags        = local.common_tags
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.redis_security_group_id]
}

# SNS FanOut → 3 colas SQS: Alertas Ops / Auditoría Financiera / Inventario
module "sns_sqs" {
  source = "../../modules/sns-sqs"

  project_name    = var.project_name
  env             = var.env
  resource_prefix = var.resource_prefix
  aws_region      = var.aws_region
  common_tags     = local.common_tags
  kms_key_arn     = module.kms.key_arn
}

# Lambda Workers: Audit + Alertas Ops + Process (consumidores SQS)
module "lambda_workers" {
  source = "../../modules/lambda-workers"

  project_name                   = var.project_name
  env                            = var.env
  resource_prefix                = var.resource_prefix
  common_tags                    = local.common_tags
  subnet_ids                     = module.vpc.private_subnet_ids
  security_group_ids             = [module.vpc.lambda_security_group_id]
  db_secret_arn                  = module.secrets_manager.db_secret_arn
  alertas_ops_queue_arn          = module.sns_sqs.alertas_ops_queue_arn
  auditoria_financiera_queue_arn = module.sns_sqs.auditoria_financiera_queue_arn
  inventario_queue_arn           = module.sns_sqs.inventario_queue_arn
  ses_sender_email               = var.ses_sender_email
  kms_key_arn                    = module.kms.key_arn
}

# ─────────────────────────────────────────────
# CAPA 3 — Datos y Monitoreo
# ─────────────────────────────────────────────

module "aurora" {
  source = "../../modules/aurora-postgresql"

  project_name       = var.project_name
  env                = var.env
  resource_prefix    = var.resource_prefix
  aws_region         = var.aws_region
  common_tags        = local.common_tags
  db_name            = var.db_name
  db_master_username = var.db_master_username
  db_master_password = module.secrets_manager.db_password
  kms_key_arn        = module.kms.key_arn
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.db_security_group_id]
}

# AWS Backup: WAL continuo Aurora, RPO 5 min, retención 7 días (RNF-14)
module "aws_backup" {
  source = "../../modules/aws-backup"

  project_name      = var.project_name
  env               = var.env
  resource_prefix   = var.resource_prefix
  common_tags       = local.common_tags
  aurora_cluster_arn = module.aurora.cluster_arn
  kms_key_arn       = module.kms.key_arn
}

# CloudWatch alarms + SNS alertas equipo técnico (RNF-17: <2 min, umbral 1% errores)
module "observabilidad" {
  source = "../../modules/observabilidad"

  project_name    = var.project_name
  env             = var.env
  resource_prefix = var.resource_prefix
  common_tags     = local.common_tags
  alarm_email     = var.alarm_email
  kms_key_arn     = module.kms.key_arn

  lambda_function_names = [
    module.lambda_backend.function_name,
    module.lambda_kds_cocina.function_name,
    module.lambda_workers.audit_function_name,
    module.lambda_workers.alertas_ops_function_name,
    module.lambda_workers.process_function_name,
  ]

  api_gateway_api_id   = module.api_gateway.api_id
  enable_api_5xx_alarm = true
}
