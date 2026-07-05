# Spark Architecture and Efficient Data Processing -- Theory Answers

## 1. Spark Architecture

Apache Spark follows a master-worker architecture.

### Driver

       |
       |
       |
       |
       v

### Cluster Manager

       |
       |
       |
       |
       v


### Executors

       |
       |
       |
       |
       v


### Execution Modes



## 2. Lazy Evaluation

Spark records transformations and delays execution until an action such
as `show()`, `count()`, or `write()` is called. This enables query
optimization using DAG.

## 3. DAG (Directed Acyclic Graph)

A DAG is the logical execution plan created from transformations. Spark
optimizes this graph before execution.

## 4. Schema Handling

A schema defines column names, data types, and nullability. Explicit
schemas improve performance and prevent incorrect type inference.

## 5. Transformations and Actions

### Transformations

- filter()
- select()
- withColumn()
- groupBy()
- orderBy()

### Actions

- show()
- count()
- first()
- take()
- write()

## 6. Filtering and Selection

Filtering removes unwanted rows. Selection retrieves only required
columns, reducing computation.

## 7. DataFrame Modifications

- Rename columns
- Cast data types
- Add new columns
- Drop columns

## 8. Narrow vs Wide Transformations

### Narrow

No shuffle. Examples: filter(), select(), withColumn()

### Wide

Requires shuffle. Examples: groupBy(), join(), distinct(), orderBy()

## 9. Shuffle

Shuffles makes redistribution of data between partitions.

## 10. Predicate Pushdown

Filter conditions are pushed to the storage layer to reduce data read.
Supported efficiently by Parquet.

## 11. CSV vs Parquet

Feature CSV Parquet

---

Storage Row Column
Schema Not stored Stored
Compression No Yes
Read Speed Slower Faster
Predicate Pushdown No Yes
Column Pruning No Yes

## 12. Handling Null Values

- fillna()
- dropna()
- isNull()
- isNotNull()

## 13. Data Pipeline

Read → Transform → Filter → Aggregate → Write

## 14. Best Practices used in this Assignment

- Avoid collect() on large datasets.
- Use show() or take() for preview.
- Reduce shuffles.
- Filter early.
- Select only necessary columns.
- Readability throught the code (indents, variable names)

## 15. Performance Insights

- Lazy evaluation optimizes execution.
- Narrow transformations are faster.
- Wide transformations involves shuffle.
- Parquet is faster and more storage-efficient than CSV.
- But most of the operations were made on the table created from the CSV.
