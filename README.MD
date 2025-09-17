
# 🏗️ Arquitectura Serverless Lab (AWS)

Laboratorio práctico para entender y demostrar los conceptos de **arquitectura serverless** usando **AWS Lambda + DynamoDB Streams**.  

Este proyecto crea un flujo típico:

**Cliente HTTP → Lambda HTTP → DynamoDB (orders) → Stream → Lambda Worker → DynamoDB (orders_enriched)**

## 📖 Objetivo

Implementar un sistema simple de **gestión de pedidos** en serverless:

1. **HTTP Lambda** (`POST /orders`): crea un pedido en DynamoDB (`orders`).  
2. **Stream Lambda**: cada vez que se inserta un pedido, DynamoDB Streams dispara esta función, que **enriquece el pedido** (ej. calcula IVA) y lo guarda en la tabla `orders_enriched`.  

---

## 🛠️ Requisitos

- Tener instalada la **AWS CLI** 
- Tener configurado los credenciales de la cuenta de AWS
- **Terraform ≥ 1.6** (se recomienda [terraform-bin en AUR](https://aur.archlinux.org/packages/terraform-bin) o tfenv)  
- Permisos en AWS para crear: Lambda, IAM Roles/Policies, DynamoDB, CloudWatch Logs  

---

## 📂 Estructura
```
├─ app/
│ ├─ handler_http.py # Lambda HTTP: crea pedidos
│ └─ handler_stream.py # Lambda Stream: enriquece pedidos
├─ main.tf # Infraestructura principal (Lambdas, tablas, IAM)
├─ variables.tf # Variables (región, prefix)
├─ outputs.tf # Salidas (URL de función, nombres de tablas)
└─ versions.tf # Requisitos de providers Terraform
```

## 🚀 Despliegue

### 1. Inicializar y aplicar
```bash
terraform init
terraform apply -auto-approve
```
Al finalizar, obtendrás:

- Function URL → endpoint público para POST /orders
- Nombre de las tablas DynamoDB (orders, orders_enriched)

## 🔎 Prueba rápida

### 1. Crear Pedido 
```bash
curl -s -X POST "<reemplazar por FUNCTION_URL>" \
  -H "Content-Type: application/json" \
  -d '{"customer":"mateo","amount":123.45}'
# => {"ok": true, "order_id": "...."}
```
### 2. Verificar enriquecido
```bash
ORDER_ID="<el_id_devuelto>"
aws dynamodb get-item \
  --table-name serverless-lab-orders-enriched \
  --key "{\"order_id\":{\"S\":\"$ORDER_ID\"}}" \
  --region us-east-1
```

Respuesta esperada:
```json
{
  "Item": {
    "order_id": {"S": "uuid..."},
    "subtotal": {"N": "123.45"},
    "tax": {"N": "23.46"},
    "total": {"N": "146.91"},
    "status": {"S": "ENRICHED"}
  }
}
```


## 🧹 Destruir

Para destruir la infraestructura basta con ejecutar el comando:
```bash
terraform destroy -auto-approve
```