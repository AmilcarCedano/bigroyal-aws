# Comandos de Despliegue — BigRoyal AWS

> Referencia de comandos para levantar la infraestructura BigRoyal en AWS.
> Ejecutar en orden durante la presentación.

---

## Requisitos previos

| Herramienta | Versión mínima | Verificar con |
|---|---|---|
| Terraform | 1.6+ | `terraform --version` |
| AWS CLI | 2.x | `aws --version` |
| Ansible | 2.14+ | `ansible --version` |
| Git | cualquiera | `git --version` |

---

## 1. Clonar el repositorio

```bash
git clone https://github.com/AmilcarCedano/bigroyal-aws.git
cd bigroyal-aws
```

---

## 2. Configurar credenciales AWS

```bash
aws configure
# Ingresar cuando pida:
#   AWS Access Key ID:     <tu-access-key>
#   AWS Secret Access Key: <tu-secret-key>
#   Default region:        us-east-1
#   Output format:         json
```

Verificar que las credenciales funcionan:

```bash
aws sts get-caller-identity
```

---

## 3. Ansible — Preparar entorno (Configuración)

> Ansible configura la máquina de despliegue y valida que todo esté listo.
> **Rol de Ansible:** configuración del entorno.
> **Rol de Terraform:** aprovisionamiento de infraestructura AWS.

### Entorno DEV
```bash
ansible-playbook infra/ansible/setup.yml \
  -i infra/ansible/inventory.ini \
  -e "env=DEV"
```

### Entorno PROD
```bash
ansible-playbook infra/ansible/setup.yml \
  -i infra/ansible/inventory.ini \
  -e "env=PROD"
```

Qué hace el playbook:
- Verifica que Terraform y AWS CLI estén instalados
- Valida las credenciales AWS activas (solo PROD)
- Genera el archivo `terraform.tfvars` con las variables del entorno

---

## 4. Terraform — Desplegar infraestructura (Aprovisionamiento)

### 4.1 Inicializar Terraform
```bash
terraform -chdir=infra/terraform init
```

### 4.2 Ver qué recursos se van a crear
```bash
terraform -chdir=infra/terraform plan \
  -var-file="envs/dev/terraform.tfvars"
```

### 4.3 Desplegar en AWS
```bash
terraform -chdir=infra/terraform apply \
  -var-file="envs/dev/terraform.tfvars"
```

Escribir `yes` cuando pida confirmación.

---

## 5. Verificar recursos levantados en AWS

```bash
# Ver todos los recursos creados por Terraform
terraform -chdir=infra/terraform state list

# Ver outputs (URLs, ARNs, endpoints)
terraform -chdir=infra/terraform output
```

También verificar en AWS Console:
- **VPC** → VPC Dashboard
- **Lambda** → Lambda Functions
- **API Gateway** → API Gateway Console
- **Aurora** → RDS → Clusters
- **ElastiCache** → ElastiCache → Redis
- **CloudFront** → CloudFront Distributions
- **S3** → S3 Buckets

---

## 6. Destruir infraestructura (al finalizar)

```bash
terraform -chdir=infra/terraform destroy \
  -var-file="envs/dev/terraform.tfvars"
```

> ⚠️ Solo ejecutar al terminar la presentación para evitar costos en AWS.

---

## Recursos configurados por cada herramienta

### Terraform provee (infraestructura)
| Recurso | Módulo |
|---|---|
| VPC + Subnets + Flow Logs | `modules/vpc` |
| CloudFront + S3 Frontend | `modules/cloudfront`, `modules/s3-frontend` |
| WAF | `modules/waf` |
| Route 53 | `modules/route53` |
| API Gateway | `modules/api-gateway` |
| Lambda Backend, KDS, Workers | `modules/lambda-*` |
| Cognito | `modules/cognito` |
| ElastiCache Redis | `modules/elasticache-redis` |
| SNS + SQS | `modules/sns-sqs` |
| Aurora PostgreSQL Multi-AZ | `modules/aurora-postgresql` |
| AWS Backup | `modules/aws-backup` |
| Secrets Manager | `modules/secrets-manager` |
| KMS | `modules/kms` |
| CloudWatch + Observabilidad | `modules/observabilidad` |
| IAM Users | `modules/iam-users` |
| CloudTrail | `modules/cloudtrail` |

### Ansible configura (entorno de trabajo)
| Tarea | Cuándo |
|---|---|
| Verifica Terraform instalado | DEV y PROD |
| Verifica AWS CLI instalado | DEV y PROD |
| Genera `terraform.tfvars` | DEV y PROD |
| Valida credenciales AWS | Solo PROD |
| Confirma región configurada | Solo PROD |
