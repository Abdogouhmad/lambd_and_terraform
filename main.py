import json
import boto3
import urllib.request

s3 = boto3.client("s3")


def lambda_handler(event, context):
    api_url = f"https://dummyjson.com/posts/user/5"

    try:
        # Fetch data from the API
        with urllib.request.urlopen(api_url) as response:
            user_data = json.loads(response.read().decode())

        # Store post data with reactions and views in a list
        post_data_list = []
        for post in user_data["posts"]:
            post_data = {
                "Likes": post["reactions"]["likes"],
                "DisLikes": post["reactions"]["dislikes"],
                "views": post["views"],
            }
            post_data_list.append(post_data)

        # Store processed data in S3
        s3.put_object(
            Bucket="userdata24",
            Key="processed-user-data.json",
            Body=json.dumps(post_data_list),
            ContentType="application/json",
        )

        # Return processed data in the response body
        return {"statusCode": 200, "body": json.dumps(post_data_list)}

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Error processing data", "error": str(e)}),
        }
