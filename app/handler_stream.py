import os, decimal, boto3

DST = os.environ.get("ENRICHED_TABLE", "orders_enriched")
dynamo = boto3.resource("dynamodb")
dst = dynamo.Table(DST)

def handler(event, context):
    for record in event.get("Records", []):
        if record.get("eventName") != "INSERT":
            continue

        new_image = record["dynamodb"]["NewImage"]
        order_id = new_image["order_id"]["S"]
        amount = float(new_image["amount"]["N"])

        tax = round(amount * 0.19, 2)  # IVA 19% (ejemplo CO)
        total = round(amount + tax, 2)

        # Idempotencia simple: sobreescribimos mismo PK con estado
        dst.put_item(Item={
            "order_id": order_id,
            "subtotal": decimal.Decimal(str(amount)),
            "tax": decimal.Decimal(str(tax)),
            "total": decimal.Decimal(str(total)),
            "status": "ENRICHED"
        })
    return {"ok": True}
