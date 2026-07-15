<div align="center">

# 🍔 BigRoyal — Plataforma POS SaaS en AWS

### Infraestructura como Código (IaC) con Terraform

Plataforma **SaaS multi-tenant** de punto de venta (POS) para la gestión de restaurantes de alto volumen y cadenas de múltiples sedes, desplegada íntegramente en **Amazon Web Services** mediante Infraestructura como Código.

![Terraform](https://img.shields.io/badge/Terraform-1.5+-7B42BC?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-us--east--1-FF9900?logo=amazonaws&logoColor=white)
![Checkov](https://img.shields.io/badge/Checkov-0_fallos-success?logo=checkmarx&logoColor=white)
![Tests](https://img.shields.io/badge/Tests-15_passing-success?logo=jest&logoColor=white)
![CI](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=githubactions&logoColor=white)

</div>

---

## 📋 Descripción del Proyecto

En restaurantes con alto volumen de atención y cadenas de múltiples sedes, tomar pedidos con papel o sistemas antiguos instalados en una sola computadora genera retrasos, descuadres de caja y falta de control sobre los insumos. **BigRoyal** resuelve esto con una plataforma web centralizada que sincroniza en tiempo real los pedidos entre el salón y la cocina, unifica el catálogo de productos, el costeo de recetas y la gestión de turnos de caja — y permite al dueño ver cuánto vende cada sede en el instante, desde cualquier lugar.

Toda la infraestructura está definida como código con **Terraform**, versionada en Git, validada automáticamente en cada cambio con escaneo de seguridad (**Checkov**), análisis de calidad (**SonarCloud**), pruebas unitarias (**Jest**) y planificación (**Terraform Plan**) mediante **GitHub Actions**. Se reconstruye desde cero de forma reproducible con dos comandos.

## 🎯 Objetivos del Proyecto

- Automatizar el 100% de la infraestructura en AWS usando **Terraform** (sin configuración manual en la consola).
- Garantizar **escalabilidad, disponibilidad y seguridad** mediante servicios administrados y arquitectura serverless.
- Implementar un pipeline **CI/CD** completo que bloquee cualquier configuración insegura o test fallido antes del despliegue.
- Mantener el estado versionado, con despliegues reproducibles y destrucción limpia.
- Cumplir los requerimientos no funcionales de rendimiento, seguridad, disponibilidad y observabilidad definidos en el informe de arquitectura.

## 👥 Colaboradores del Proyecto

| Integrante | Rol | Responsabilidad principal |
|---|---|---|
| **Cedano Baca, Anderson Amilcar** | Líder / Arquitecto Cloud · IaC | Terraform, CI/CD, seguridad y autenticación (Cognito, WAF, IAM) |
| **Chavez Castillo, Leonardo** | Backend / Lógica de Negocio | API Gateway, Lambdas, colas SQS/SNS, rendimiento |
| **Coronado Medina, Sergio** | Datos / Seguridad y QA | Aurora PostgreSQL, backups, cifrado KMS, observabilidad |

> **Universidad Privada Antenor Orrego (UPAO)** — Facultad de Ingeniería
> Programa de Ingeniería de Sistemas e Inteligencia Artificial
> Curso: **Infraestructura como Código** — Docente: Walter Iván Leturia Rodríguez · 2026

## 🏗️ Arquitectura

La plataforma se organiza en cuatro capas sobre la región **us-east-1 (Norte de Virginia)**:

```
                          Usuario (navegador)
                                 │
                          Route 53 (DNS + Failover)
                                 │
                          AWS WAF  ──►  CloudFront (CDN)
                                 │              │
         ┌───────────────────────┤              └──► S3 (frontend React/Vite, privado vía OAC)
         │                       │
   Amazon Cognito  ◄─────  API Gateway (JWT authorizer)
   (autenticación)               │
                          Lambda Backend (Express + Prisma)
                          ├── Lambda KDS Cocina
                          └── Lambda Workers (auditoría · alertas · inventario)
                                 │            ▲
                          Aurora PostgreSQL   │  SNS + SQS (fan-out asíncrono)
                          ElastiCache Redis   │
                          Secrets Manager · KMS
                                 │
                  CloudWatch · CloudTrail · AWS Backup  (observabilidad y gobernanza)
```

| Capa | Servicios AWS | Función |
|---|---|---|
| **Presentación** | Route 53, WAF, CloudFront, S3 | DNS con failover, firewall OWASP, CDN y frontend estático privado |
| **API y Lógica** | API Gateway, Cognito, Lambda ×5, SNS, SQS | API serverless autenticada con JWT y procesamiento asíncrono |
| **Datos** | Aurora PostgreSQL (Multi-AZ), ElastiCache Redis, Secrets Manager, KMS | Base de datos de alta disponibilidad, caché, secretos y cifrado |
| **Observabilidad y Gobernanza** | CloudWatch, CloudTrail, AWS Backup, IAM | Dashboards, alarmas, auditoría, respaldos y control de acceso |

## 📁 Estructura del Repositorio

```
infra/
├── terraform/
│   ├── envs/dev/          → punto de entrada: arma todos los módulos
│   └── modules/           → 15 módulos reutilizables (uno por servicio)
├── .github/workflows/     → ci-dev.yml (PRs) · ci-prod.yml (main)
├── ci/                    → scripts de Checkov y Terraform Plan
├── ansible/               → deploy.yml (deploy end-to-end de la aplicación)
├── scripts/               → test-waf-ataques.sh (prueba de seguridad del WAF)
├── src/                   → código de negocio + 15 tests unitarios (Jest)
├── docs/                  → PLAN-TESTS.md (planificación TDD)
└── deploy.ps1             → deploy end-to-end (equivalente Windows de Ansible)
```

## 🚀 Despliegue

### Requisitos
- Terraform ≥ 1.5, AWS CLI configurado, Node.js 20
- (Opcional) WSL + Ansible para el deploy vía playbook

### 1. Levantar la infraestructura
```powershell
cd terraform/envs/dev
terraform init
terraform plan
terraform apply
```

### 2. Desplegar la aplicación (backend + base de datos + usuarios + frontend)
```powershell
# Windows
./deploy.ps1

# o con Ansible (WSL)
ansible-playbook ansible/deploy.yml
```

### 3. Destruir todo
```powershell
aws rds modify-db-cluster --db-cluster-identifier bigroyal-dev-aurora-cluster \
  --no-deletion-protection --apply-immediately --region us-east-1
terraform destroy
```

## ✅ Calidad y Seguridad (CI/CD)

Cada Pull Request ejecuta automáticamente en **GitHub Actions**:

| Check | Herramienta | Qué valida |
|---|---|---|
| **Unit Tests** | Jest | 15 casos unitarios (patrón AAA + mocks) — bloqueante |
| **Checkov Security Scan** | Checkov | Configuraciones inseguras en el código Terraform (0 fallos) |
| **SonarCloud Analysis** | SonarCloud | Calidad de código y cobertura de tests |
| **Terraform Plan** | Terraform | Que la infraestructura se pueda crear sin errores |

Además, un **git hook `pre-push` (Husky)** ejecuta los tests localmente antes de cada push: si alguno falla, el código no sale de la máquina.

## 📊 Observabilidad

Tres **dashboards de CloudWatch** definidos como código, con indicadores basados en métricas y en **logs** (metric filters + Logs Insights):

- `bigroyal-dev-1-api-aplicacion` — tráfico, latencia, errores por Lambda y peticiones en vivo
- `bigroyal-dev-2-datos` — CPU de Aurora/Redis, conexiones, hits/misses de caché
- `bigroyal-dev-3-seguridad` — bloqueos del WAF por regla, tráfico de CloudFront, top de rutas

---

<div align="center">

**BigRoyal** · Infraestructura como Código · UPAO 2026

</div>
