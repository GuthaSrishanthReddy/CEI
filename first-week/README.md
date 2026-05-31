# Pandas Data Exploration and Cleaning

## Objective

The objective of this notebook is to learn basic Python and Pandas operations by loading a CSV dataset, exploring it, cleaning missing values, performing simple filtering/selection, removing duplicates, creating a derived column, and saving the cleaned data as a new CSV file.

## Files Used

- `Combined_dataset.csv`: Original dataset used for analysis.
- `main.ipynb`: Jupyter Notebook containing the complete work.
- `cleaned_Combined_dataset.csv`: Cleaned dataset generated from the notebook.

## Work Done in the Notebook

### 1. Loaded the CSV Dataset

I started by importing Pandas and loading the dataset into a DataFrame:

```python
import pandas as pd

df = pd.read_csv("Combined_dataset.csv")
df.head(3)
```

I used `head(3)` to quickly to see the first few rows.

### 2. Explored the Data

I explored the dataset using:

```python
df.shape
df.columns
df.dtypes
df.isnull().sum()
```

This helped me understand:

- how many rows and columns are present
- what columns are available
- which columns are numeric or text-based
- which columns contain missing values

The dataset has product-related columns like `product_id`, `title`, `rating`, `ratings_count`, `initial_price`, `discount`, `final_price`, `seller_name`, `videos`, `variations`, and `category`.

### 3. Handled Missing Values

I created a copy of the original DataFrame before cleaning:

```python
df1 = df.copy()
```

This keeps the original dataset unchanged and allows all cleaning operations to happen on `df1`.

I filled missing values in text/categorical columns with meaningful placeholder values:

```python
df1["what_customers_said"] = df1["what_customers_said"].fillna("No comments")
df1["seller_name"] = df1["seller_name"].fillna("Unknown")
df1["seller_information"] = df1["seller_information"].fillna("Unknown")
df1["videos"] = df1["videos"].fillna("No Video")
df1["variations"] = df1["variations"].fillna("No Variants")
```

As the columns are mostly text-based, so using mean or median would not make sense. Placeholder values clearly show that the information was missing or unavailable.

For `discount`, I filled missing values with a `0`:

I treated missing discount values as products with no discount.

I also created a helper column:

```python
df1["has_variations"] = df1["variations"].notna()
```

The purpose of this column is to make it easier to filter products based on whether variation information exists.

### 4. Performed Basic Operations

I selected useful columns from the cleaned dataset:

```python
selected_columns = df1[["product_id", "title", "category", "rating", "initial_price", "discount"]]
```

Then I filtered products with a rating greater than `4` and more than `70` ratings:

```python
high_rated = selected_columns[(df1["rating"] > 4) & (df1["ratings_count"] > 70)]
high_rated.head(3)
```

This helped identify products that are both highly rated and have a good number of customer ratings.

### 5. Removed Duplicates

I removed duplicate products using `product_id`:

```python
df1 = df1.drop_duplicates(subset=["product_id"])
df1.shape
```

I used `product_id` because it is the unique identifier for each product. Repeated brand names or titles should not be treated as duplicates because different products can have the same brand name.

### 6. Created a Derived Column

The assignment example mentions:

```python
total_amount = price * quantity
```

However, this dataset does not contain `price` and `quantity` columns. So I created a derived column that fits this dataset:

```python
df1["calculated_final_price"] = df1["initial_price"] - (df1["initial_price"] * df1["discount"] / 100)
```

This calculates the expected final price after applying the discount percentage to the initial price.

Formula used:

```text
calculated_final_price = initial_price - (initial_price * discount / 100)
```

### 7. Saved the Cleaned Dataset

Finally, I saved the cleaned DataFrame as a new CSV file:

```python
df1.to_csv("cleaned_Combined_dataset.csv", index=False)
```

I used `index=False` so that Pandas does not add an extra index column to the saved CSV file.

## Brief Summary

In this notebook, I worked with the combined product dataset and went through the basic Pandas workflow step by step. First, I loaded the CSV file and checked the first few rows to understand what kind of data I was dealing with. After that, I explored the shape, column names, data types, and missing values so I could decide what needed cleaning.

For missing values, I used simple and understandable replacements. Since most of the missing columns were text-based, I filled them with values like `Unknown`, `No Video`, `No Variants`, and `No comments`. For missing discounts, I used `0` because a blank discount can be treated as no discount. I also removed duplicate products using `product_id`, filtered some high-rated products, and created a new column called `calculated_final_price` to calculate the price after discount.

At the end, I saved the cleaned dataset as `cleaned_Combined_dataset.csv`. This makes the data easier to use for future analysis, visualization, or any further project work.
