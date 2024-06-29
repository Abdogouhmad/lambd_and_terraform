import json
import requests as req
import pandas as pd
from typing import Union
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

# CORS configuration to allow requests from localhost:3000
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],  # Update with your frontend URL
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Fetch the data and return JSON response or error message
def get_user(url: str) -> Union[dict, str]:
    """
    Fetches user data from the specified URL.

    Args:
        url (str): The URL to fetch user data from.

    Returns:
        Union[dict, str]: Returns a dictionary containing user data if successful,
                          or a JSON string error message if there's an exception.
    """
    try:
        response = req.get(url)
        response.raise_for_status()
        data = response.json()
        return data
    except req.exceptions.RequestException as e:
        error_message = {"message": f"Error fetching data: {e}"}
        return json.dumps(error_message, indent=4)


# function that get reatcions only
def get_reaction(data: Union[dict, str]) -> Union[dict, None]:
    if isinstance(data, dict) and "posts" in data:
        posts = data["posts"]
        if posts:
            # Extracting only relevant fields for each post
            filtered_data = [
                {
                    "Likes": post["reactions"]["likes"],
                    "Dislikes": post["reactions"]["dislikes"],
                }
                for post in posts
            ]
            df = pd.DataFrame(filtered_data).to_dict(orient="list")
            return df
        else:
            return {"message": "No data found"}
    else:
        return None  # Handle invalid data gracefully


# function that get views only
def get_views(data: Union[dict, str]) -> Union[dict, None]:
    if isinstance(data, dict) and "posts" in data:
        posts = data["posts"]
        if posts:
            # Extracting only relevant fields for each post
            filtered_data = [{"Views": post["views"]} for post in posts]
            df = pd.DataFrame(filtered_data).to_dict(orient="list")
            return df
        else:
            return {"message": "No data found"}
    else:
        return None


# create POST api for reactions
@app.get("/reactions/{id}")
def get_reactiondata(id):
    if id is not None:
        URL = f"https://dummyjson.com/posts/user/{id}"
        data = get_user(URL)
        return get_reaction(data)
    else:
        return {"message": "No id provided"}


@app.get("/views/{id}")
def get_viewsdata(id):
    if id is not None:
        URL = f"https://dummyjson.com/posts/user/{id}"
        data = get_user(URL)
        return get_views(data)
    else:
        return {"message": "No id provided"}
