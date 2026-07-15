# Deploy completo: backend (Lambda) + migracion/seed + frontend (S3 + CloudFront)
# Equivalente en PowerShell de infra/ansible/deploy.yml (para usar sin WSL).
# Requiere: terraform apply ya ejecutado, AWS CLI configurado.

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
if (-not $root) { $root = "C:\Users\ANDERSON\IdeaProjects\bigroyal-aws" }
$backendDir = Join-Path $root "backend"
$frontendDir = Join-Path $root "frontend"
$terraformDir = Join-Path $root "infra\terraform\envs\dev"
$scratch = "C:\Users\ANDERSON\AppData\Local\Temp\claude\C--Users-ANDERSON-Gordito\83d64f31-30b5-4fc8-b19b-604c29d72683\scratchpad"
$region = "us-east-1"

function Wait-Lambda {
    aws lambda wait function-updated --function-name bigroyal-dev-backend --region $region
}

Write-Host "=== 1/8 Instalando dependencias del backend ===" -ForegroundColor Cyan
Push-Location $backendDir
npm install

Write-Host "=== 2/8 Generando Prisma Client (Linux + Windows) ===" -ForegroundColor Cyan
npx prisma generate

Write-Host "=== 3/8 Generando SQL de migracion ===" -ForegroundColor Cyan
npx prisma migrate diff --from-empty --to-schema-datamodel prisma/schema.prisma --script 2>$null | Out-File -Encoding utf8 "$backendDir\prisma\migration.sql"

Write-Host "=== 4/8 Empaquetando Lambda ===" -ForegroundColor Cyan
$staging = "$scratch\lambda-backend-package"
if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
New-Item -ItemType Directory -Force -Path $staging | Out-Null
Copy-Item "$backendDir\src" "$staging\src" -Recurse
Copy-Item "$backendDir\prisma" "$staging\prisma" -Recurse
Copy-Item "$backendDir\seed.js" "$staging\seed.js"
Copy-Item "$backendDir\package.json" "$staging\package.json"
Copy-Item "$backendDir\node_modules" "$staging\node_modules" -Recurse
# Solo se necesita el motor rhel (el que usa Lambda) - quitar el resto mantiene
# el paquete bajo el limite de 250MB descomprimido de Lambda
Remove-Item "$staging\node_modules\.prisma\client\query_engine-windows.dll.node" -Force -ErrorAction SilentlyContinue
Get-ChildItem "$staging\node_modules\.prisma\client" -Filter "libquery_engine-debian*" -ErrorAction SilentlyContinue | Remove-Item -Force
Remove-Item "$staging\node_modules\@prisma\engines" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$staging\node_modules\prisma" -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem "$staging\node_modules\.bin" -Filter "prisma*" -ErrorAction SilentlyContinue | Remove-Item -Force
Remove-Item "$staging\node_modules\.cache" -Recurse -Force -ErrorAction SilentlyContinue

$zipPath = "$scratch\lambda-backend.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$staging\*" -DestinationPath $zipPath -CompressionLevel Optimal
$sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
Write-Host "ZIP: $sizeMB MB"

Pop-Location
Push-Location $terraformDir
$bucket = terraform output -raw frontend_bucket_name
$apiUrl = (terraform output -raw api_gateway_url).TrimEnd('/')

Write-Host "=== 5/8 Subiendo y desplegando codigo del backend ===" -ForegroundColor Cyan
aws s3 cp $zipPath "s3://$bucket/_deploy/lambda-backend.zip" --region $region --quiet
aws lambda update-function-code --function-name bigroyal-dev-backend --s3-bucket $bucket --s3-key _deploy/lambda-backend.zip --region $region --query "LastUpdateStatus" --output text
Wait-Lambda

Write-Host "=== 6/9 Migrando y poblando la base de datos ===" -ForegroundColor Cyan
aws lambda update-function-configuration --function-name bigroyal-dev-backend --handler src/migrate.handler --region $region --query "Handler" --output text
Wait-Lambda
aws lambda invoke --function-name bigroyal-dev-backend --region $region --cli-read-timeout 120 "$scratch\migrate-output.json" | Out-Null
Get-Content "$scratch\migrate-output.json"
aws lambda update-function-configuration --function-name bigroyal-dev-backend --handler src/handler.handler --region $region --query "Handler" --output text
Wait-Lambda

Write-Host "=== 7/9 Creando usuarios en Cognito ===" -ForegroundColor Cyan
Push-Location $terraformDir
$poolId = terraform output -raw cognito_user_pool_id
$clientId = terraform output -raw cognito_app_client_id
Pop-Location

$sedeId = "11111111-1111-1111-1111-111111111111"
$sedeNombre = "Sede Centro"

function New-CognitoUser($email, $password, $nombre, $rol, $dbId) {
    # admin-create-user falla si ya existe (UsernameExists) - se ignora y se
    # continua con set-password. EAP se baja a Continue dentro de la funcion:
    # en PS 5.1, redirigir stderr de un exe con EAP=Stop lanza NativeCommandError.
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    aws cognito-idp admin-create-user --user-pool-id $poolId --username $email `
        --user-attributes Name=email,Value=$email Name=email_verified,Value=true "Name=name,Value=$nombre" `
        "Name=custom:rol,Value=$rol" "Name=custom:db_id,Value=$dbId" `
        "Name=custom:sede_id,Value=$sedeId" "Name=custom:sede_nombre,Value=$sedeNombre" `
        --message-action SUPPRESS --region $region 2>$null | Out-Null
    aws cognito-idp admin-set-user-password --user-pool-id $poolId --username $email `
        --password $password --permanent --region $region
    $ErrorActionPreference = $prevEAP
    Write-Host "  Usuario listo: $email"
}

New-CognitoUser "admin@bigroyal.com"  "Admin123"  "Administrador" "admin"     "aaaaaaaa-0000-0000-0000-000000000001"
New-CognitoUser "cajero@bigroyal.com" "Cajero123" "Carlos Cajero" "cajero"    "aaaaaaaa-0000-0000-0000-000000000002"
New-CognitoUser "cocina@bigroyal.com" "Cocina123" "Luis Cocinero" "planchero" "aaaaaaaa-0000-0000-0000-000000000003"

Write-Host "=== 8/9 Build y deploy del frontend ===" -ForegroundColor Cyan
Pop-Location
Push-Location $frontendDir
npm install

$envContent = Get-Content "$frontendDir\.env" -Raw
$envContent = $envContent -replace "VITE_API_URL=.*", "VITE_API_URL=$apiUrl/api"
$envContent = $envContent -replace "VITE_COGNITO_CLIENT_ID=.*", "VITE_COGNITO_CLIENT_ID=$clientId"
# Sin WebSocket en AWS (Lambda no soporta conexiones persistentes) - vacio
# para que useSocket no intente conectar a localhost desde CloudFront.
$envContent = $envContent -replace "VITE_SOCKET_URL=.*", "VITE_SOCKET_URL="
Set-Content "$frontendDir\.env" $envContent -NoNewline

npm run build

Push-Location $terraformDir
$bucket = terraform output -raw frontend_bucket_name
$distId = terraform output -raw cloudfront_distribution_id
Pop-Location

aws s3 sync "$frontendDir\dist/" "s3://$bucket" --delete --region $region
aws cloudfront create-invalidation --distribution-id $distId --paths "/*" | Out-Null

Pop-Location

Write-Host "=== 9/9 Listo ===" -ForegroundColor Green
Write-Host "Login (Cognito): admin@bigroyal.com / Admin123"
Write-Host "Otros: cajero@bigroyal.com / Cajero123 - cocina@bigroyal.com / Cocina123"
