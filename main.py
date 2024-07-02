import json
import boto3
import requests as req
import pandas as pd
from decimal import Decimal
from typing import Union


# Lambda handler function
def lambda_handler(event, context):
    try:
        if event.get("httpMethod") == "GET":
            user_id = event.get("pathParameters", {}).get("id")
            if user_id:
                return handle_data(user_id)
            else:
                return build_response(400, "Bad request: Missing user id", cors=True)
        else:
            return build_response(
                400, "Bad request: Only GET method is supported", cors=True
            )
    except Exception as e:
        print(f"Error processing request: {e}")
        return build_response(500, f"Internal server error: {e}", cors=True)


# Function to handle the data
def handle_data(user_id: str):
    bucket_name = "userdata"
    object_key = f"{user_id}_posts_data.json"
    s3 = boto3.client("s3")
    url = f"https://dummyjson.com/posts/user/{user_id}"

    data = fetch_data(url)
    if isinstance(data, dict) and "posts" in data:
        filtered_data = data_posts(data)

        # Write the data to a file
        with open("/tmp/" + object_key, "w") as file:
            json.dump(filtered_data, file)

        # Upload file to S3
        s3.upload_file("/tmp/" + object_key, bucket_name, object_key)

        # Fetch the uploaded file from S3
        resp = s3.get_object(Bucket=bucket_name, Key=object_key)
        processed_data = resp["Body"].read().decode("utf-8")
        return build_response(200, json.loads(processed_data), cors=True)
    else:
        return build_response(404, "No data found or error fetching data", cors=True)


# Fetch the data and return JSON response or error message
def fetch_data(url: str) -> Union[dict, str]:
    try:
        response = req.get(url)
        response.raise_for_status()
        return response.json()
    except req.exceptions.RequestException as e:
        return {"message": f"Error fetching data: {e}"}


# Function to process posts data
def data_posts(data: dict) -> dict:
    posts = data.get("posts", [])
    filtered_data = [
        {
            "Likes": post["reactions"].get("likes", 0),
            "Dislikes": post["reactions"].get("dislikes", 0),
            "Views": post.get("views", 0),
        }
        for post in posts
    ]
    return pd.DataFrame(filtered_data).to_dict(orient="list")


# Custom JSON encoder for Decimal type
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            if obj % 1 == 0:
                return int(obj)
            else:
                return float(obj)
        return super(DecimalEncoder, self).default(obj)


# Build the response
def build_response(status_code, body, cors=False):
    headers = {"Content-Type": "application/json"}
    if cors:
        headers.update(
            {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type",
                "Access-Control-Allow-Methods": "GET",
            }
        )

    return {
        "statusCode": status_code,
        "headers": headers,
        "body": json.dumps(body, cls=DecimalEncoder),
    }
