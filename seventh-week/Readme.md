# Delta Lake MERGE Implementation

In this notebook, I implemented incremental data processing using Delta Lake MERGE in Databricks. I loaded the master dataset, cleaned the data, merged the incremental dataset, validated the results, and checked the final output.

## Workflow

- Imported the required PySpark and Delta Lake libraries.
- Loaded the master CSV file into a Spark DataFrame.
- Renamed the column names to snake_case so they are compatible with Unity Catalog.
- Displayed the schema and a few sample records.

- Created a Delta table from the master dataset.
- Verified that the table was created successfully.

- Checked all columns for null values.
- Updated null values in the `postal_code` column.
- Checked for duplicate records using the `row_id` column.
- Removed duplicate records if any were found.
- Verified the cleaned dataset.

- Loaded the incremental dataset.
- Renamed the columns to match the master dataset.
- Compared the master and incremental datasets to find existing and new records.

- Stored the row count before performing the MERGE operation.
- Performed the Delta Lake MERGE operation.
- Updated the existing records.
- Inserted the new records.
- Verified the row count after the MERGE.

- Checked that the expected number of new records were inserted.
- Verified that there were no duplicate records after the MERGE.
- Displayed a few updated records for verification.
- Verified that all new records were inserted successfully.

- Displayed the Delta table history to verify the transaction.
- Loaded the final Delta table.
- Displayed the schema and sample records.
- Generated summary statistics for the numeric columns.
- Displayed the category-wise record count.
- Printed the final summary of the assignment.

## Result

- Successfully loaded the master and incremental datasets.
- Cleaned the data before processing.
- Performed incremental loading using Delta Lake MERGE.
- Updated existing records and inserted new records in a single transaction.
- Validated the final dataset and confirmed the data integrity.
- Verified the Delta table history and final output.
