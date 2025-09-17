import json, os, time, uuid
from decimal import Decimal
import boto3

TABLE = os.environ.get("ORDERS_TABLE", "orders")
dynamo = boto3.resource("dynamodb").Table(TABLE)

def handler(event, context):
    method = (
        event.get("requestContext", {}).get("http", {}).get("method")
        or event.get("requestContext", {}).get("httpMethod")
        or "POST"
    )
    if method != "POST":
        return {"statusCode": 405, "body": "Method Not Allowed"}

    # Importante: parsea números JSON como Decimal
    body = json.loads(event.get("body") or "{}", parse_float=Decimal, parse_int=Decimal)

    # Normaliza/valida amount a Decimal (string -> Decimal es más seguro)
    raw_amount = body.get("amount", "0")
    try:
        amount = Decimal(str(raw_amount))
    except Exception:
        return {"statusCode": 400, "body": "amount inválido"}

    order_id = str(uuid.uuid4())
    item = {
        "order_id": order_id,
        "customer": str(body.get("customer", "anonymous")),
        "amount": amount,                # Decimal ✅
        "created_at": int(time.time())   # int también es válido
    }

    dynamo.put_item(Item=item)

    # Ojo: no devolvemos Decimals en JSON; solo strings/ints
    return {
        "statusCode": 201,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"ok": True, "order_id": order_id})
    }
