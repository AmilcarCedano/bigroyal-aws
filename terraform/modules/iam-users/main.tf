# ─────────────────────────────────────────────
# Líder / Arquitecto — PowerUserAccess (sin usar Root) (RNF-06)
# Integrante: Cedano Baca, Anderson Amilcar
# ── FIX CKV_AWS_274: reemplaza AdministratorAccess por PowerUserAccess ──
# PowerUserAccess da acceso completo a servicios AWS pero NO incluye
# IAM:*, Organizations:* ni Billing:* — principio de mínimo privilegio.
# ─────────────────────────────────────────────
resource "aws_iam_user" "lider" {
  name = "${var.resource_prefix}-lider-arquitecto"
  tags = var.common_tags
}

resource "aws_iam_user_policy_attachment" "lider_admin" {
  user       = aws_iam_user.lider.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# ─────────────────────────────────────────────
# Dev Frontend — S3FullAccess + CloudFrontFullAccess
# Integrante: Chavez Castillo, Leonardo
# ─────────────────────────────────────────────
resource "aws_iam_user" "dev_frontend" {
  name = "${var.resource_prefix}-dev-frontend"
  tags = var.common_tags
}

resource "aws_iam_user_policy_attachment" "frontend_s3" {
  user       = aws_iam_user.dev_frontend.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_user_policy_attachment" "frontend_cf" {
  user       = aws_iam_user.dev_frontend.name
  policy_arn = "arn:aws:iam::aws:policy/CloudFrontFullAccess"
}

# ─────────────────────────────────────────────
# Dev Backend — LambdaFullAccess + AmazonRDSFullAccess (sin Billing)
# Integrante: Coronado Medina, Sergio
# ─────────────────────────────────────────────
resource "aws_iam_user" "dev_backend" {
  name = "${var.resource_prefix}-dev-backend"
  tags = var.common_tags
}

resource "aws_iam_user_policy_attachment" "backend_lambda" {
  user       = aws_iam_user.dev_backend.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
}

resource "aws_iam_user_policy_attachment" "backend_rds" {
  user       = aws_iam_user.dev_backend.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
}
