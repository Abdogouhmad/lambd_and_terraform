import json


def lambda_handler(event, context):
    http_method = event["httpMethod"]
    if http_method == "GET":
        return {"statusCode": 200, "body": json.dumps("GET method invoked!")}
    if http_method == "POST":
        return {"statusCode": 200, "body": json.dumps("POST method invoked!")}
    elif http_method == "PUT":
        return {"statusCode": 200, "body": json.dumps("PUT method invoked!")}
    elif http_method == "DELETE":
        return {"statusCode": 200, "body": json.dumps("DELETE method invoked!")}
    elif http_method == "OPTIONS":
        return {"statusCode": 200, "body": json.dumps("OPTIONS method invoked!")}
    else:
        return {"statusCode": 400, "body": json.dumps("Unsupported method")}
