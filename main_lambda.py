import json
import requests as req
import pandas as pd
from typing import Union


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


# Filter the data using pandas and return JSON response
def filter_data_pandas(data: Union[dict, str]) -> str | None:
    """
    Filters user data using pandas and returns a JSON response.

    Args:
        data (Union[dict, str]): The user data to filter, expected to be a dictionary.

    Returns:
        str: Returns a JSON-formatted string representing the filtered data or an error message.
    """
    if isinstance(data, dict) and "posts" in data:
        posts = data["posts"]
        if posts:
            df = pd.DataFrame(posts)
            filtered_dt = df.filter(items=["reactions", "views"])
            return filtered_dt.to_json(
                orient="index", indent=4
            )  # Convert DataFrame to JSON string
        else:
            return json.dumps({"message": "No posts found in the data"}, indent=4)
    else:
        return json.dumps(data, indent=4)  # Return error message as JSON


if __name__ == "__main__":
    user_id = input("Enter the id user to get results: ")
    URL = f"https://dummyjson.com/posts/user/{user_id}"
    data = get_user(URL)
    filtered_data = filter_data_pandas(data)
    print(filtered_data)  # Print or return the JSON response
