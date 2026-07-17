import os
import sqlite3
import sys
from datetime import datetime, timedelta

import pandas as pd


ROOT = os.path.dirname(os.path.dirname(__file__))
CLEAN_DIR = os.path.join(ROOT, "data", "cleaned")
SCHEMA_FILE = os.path.join(ROOT, "sql", "schema.sql")


def get_value_from_args(flag_name):
    if flag_name in sys.argv:
        position = sys.argv.index(flag_name)
        if position + 1 < len(sys.argv):
            return sys.argv[position + 1]
    return None


def get_inputs():
    report_type = get_value_from_args("--report")
    start_date = get_value_from_args("--start")
    end_date = get_value_from_args("--end")

    if report_type is None:
        report_type = input("Report type (daily/weekly/monthly): ").strip()
    if start_date is None:
        start_date = input("Start date (YYYY-MM-DD): ").strip()
    if end_date is None:
        end_date = input("End date (YYYY-MM-DD): ").strip()

    return report_type, start_date, end_date


def make_database():
    con = sqlite3.connect(":memory:")
    con.execute("PRAGMA foreign_keys = ON")

    with open(SCHEMA_FILE, "r", encoding="utf-8") as file:
        con.executescript(file.read())

    files = {
        "customers": "customers_clean.csv",
        "products": "products_clean.csv",
        "orders": "orders_clean.csv",
        "order_items": "order_items_clean.csv",
    }

    for table_name, file_name in files.items():
        path = os.path.join(CLEAN_DIR, file_name)
        df = pd.read_csv(path)
        df.to_sql(table_name, con, if_exists="append", index=False)

    return con


def print_table(headers, rows):
    if len(rows) == 0:
        print("(no rows)")
        return

    widths = []
    for i in range(len(headers)):
        biggest = len(str(headers[i]))
        for row in rows:
            if len(str(row[i])) > biggest:
                biggest = len(str(row[i]))
        widths.append(biggest)

    header_line = ""
    for i in range(len(headers)):
        header_line = header_line + str(headers[i]).ljust(widths[i]) + "  "
    print(header_line)

    for row in rows:
        line = ""
        for i in range(len(row)):
            line = line + str(row[i]).ljust(widths[i]) + "  "
        print(line)


def percent_change(current, previous):
    if previous == 0:
        return "n/a"
    change = (current - previous) * 100 / previous
    return str(round(change, 2)) + "%"


def get_period_column(report_type):
    if report_type == "daily":
        return "order_day"
    if report_type == "weekly":
        return "strftime('%Y-%W', order_date)"
    return "order_month"


def get_summary(con, start_date, end_date):
    query = """
        SELECT
            COUNT(DISTINCT order_id),
            ROUND(COALESCE(SUM(net_revenue), 0), 2),
            COUNT(DISTINCT customer_id)
        FROM v_revenue
        WHERE order_day BETWEEN ? AND ?
    """
    return con.execute(query, (start_date, end_date)).fetchone()


def get_top_products(con, start_date, end_date):
    query = """
        SELECT product_id, product_name, ROUND(SUM(net_revenue), 2) AS revenue
        FROM v_revenue
        WHERE order_day BETWEEN ? AND ?
        GROUP BY product_id, product_name
        ORDER BY revenue DESC
        LIMIT 3
    """
    return con.execute(query, (start_date, end_date)).fetchall()


def get_breakdown(con, report_type, start_date, end_date):
    period_column = get_period_column(report_type)
    query = """
        SELECT
            """ + period_column + """ AS period,
            COUNT(DISTINCT order_id) AS orders,
            ROUND(SUM(net_revenue), 2) AS revenue
        FROM v_revenue
        WHERE order_day BETWEEN ? AND ?
        GROUP BY period
        ORDER BY period
    """
    return con.execute(query, (start_date, end_date)).fetchall()


def main():
    report_type, start_date, end_date = get_inputs()

    if report_type not in ["daily", "weekly", "monthly"]:
        print("Report type must be daily, weekly, or monthly")
        return

    start = datetime.strptime(start_date, "%Y-%m-%d")
    end = datetime.strptime(end_date, "%Y-%m-%d")

    if start > end:
        print("Start date must be before end date")
        return

    days = end - start
    previous_end = start - timedelta(days=1)
    previous_start = previous_end - days

    previous_start_text = previous_start.strftime("%Y-%m-%d")
    previous_end_text = previous_end.strftime("%Y-%m-%d")

    con = make_database()

    current = get_summary(con, start_date, end_date)
    previous = get_summary(con, previous_start_text, previous_end_text)

    print(report_type.title() + " Report")
    print("Current period:", start_date, "to", end_date)
    print("Previous period:", previous_start_text, "to", previous_end_text)
    print()

    rows = [
        ("orders", current[0], previous[0], percent_change(current[0], previous[0])),
        ("revenue", current[1], previous[1], percent_change(current[1], previous[1])),
        ("unique_customers", current[2], previous[2], percent_change(current[2], previous[2])),
    ]
    print_table(["metric", "current", "previous", "change"], rows)

    print("\nTop 3 products")
    print_table(["product_id", "product_name", "revenue"], get_top_products(con, start_date, end_date))

    print("\nBreakdown")
    print_table(["period", "orders", "revenue"], get_breakdown(con, report_type, start_date, end_date))

    con.close()


if __name__ == "__main__":
    main()
