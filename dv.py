import json
import requests as req
import pandas as pd
from typing import Union
import matplotlib.pyplot as plt


# Fetch the data and return JSON response or error message
def get_user(url: str) -> Union[dict, str]:
    try:
        response = req.get(url)
        response.raise_for_status()
        data = response.json()
        return data
    except req.exceptions.RequestException as e:
        error_message = {"message": f"Error fetching data: {e}"}
        return json.dumps(error_message, indent=4)


# function that get reactions only
def get_reaction(data: Union[dict, str]) -> Union[pd.DataFrame, None]:
    if isinstance(data, dict) and "posts" in data:
        posts = data["posts"]
        if posts:
            filtered_data = [
                {
                    "Likes": post["reactions"]["likes"],
                    "Dislikes": post["reactions"]["dislikes"],
                }
                for post in posts
            ]
            df = pd.DataFrame(filtered_data)
            return df
        else:
            return None
    else:
        return None


# function that get views only
def get_views(data: Union[dict, str]) -> Union[pd.DataFrame, None]:
    if isinstance(data, dict) and "posts" in data:
        posts = data["posts"]
        if posts:
            filtered_data = [{"Views": post["views"]} for post in posts]
            df = pd.DataFrame(filtered_data)
            return df
        else:
            return None
    else:
        return None


if __name__ == "__main__":
    URL = "https://dummyjson.com/posts/user/5"
    data = get_user(URL)

    # Get reactions and views dataframes
    reactions_df = get_reaction(data)
    views_df = get_views(data)

    # Plotting reactions as grouped bar chart
    if reactions_df is not None:
        plt.figure(figsize=(10, 6))
        reactions_df.plot(kind="bar", stacked=True)
        plt.title("Reactions")
        plt.xlabel("Posts")
        plt.ylabel("Count")
        plt.xticks(rotation=0)
        plt.legend()
        plt.tight_layout()
        plt.savefig("reactions_chart.png")  # Save as PNG file
        plt.close()  # Close the figure to free memory
        print("Saved reactions chart as reactions_chart.png")
    else:
        print("No reactions data to plot.")

    # Plotting views as pie chart
    if views_df is not None:
        plt.figure(figsize=(8, 8))
        plt.pie(views_df["Views"], labels=None, autopct="%1.1f%%", startangle=140)
        plt.title("Views Distribution")
        plt.axis("equal")
        plt.tight_layout()
        plt.savefig("views_chart.png")  # Save as PNG file
        plt.close()  # Close the figure to free memory
        print("Saved views chart as views_chart.png")
    else:
        print("No views data to plot.")
