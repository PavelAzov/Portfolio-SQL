create database Customers_transactions;
update customers set Gender = null where Gender ='';
update customers set Age = null where Age ='';
alter table customers modify Age int null;

select * from customers;

create table transactions
(date_new date,
Id_check int,
ID_client int,
Count_products decimal(10,3),
Sum_payment decimal(10,2));

SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE "C:\\mysql_data\\TRANSACTIONS_Final.csv.csv"
INTO TABLE transactions
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(@var_date, Id_check, ID_client, Count_products, Sum_payment)
SET date_new = STR_TO_DATE(TRIM(@var_date), '%Y - %m - %d');

select * from transactions;


# Задание 1. Клиенты с непрерывной историей за год

WITH continuous_clients AS (    
    SELECT ID_client
    FROM customers_transactions.transactions
    WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY ID_client
    HAVING COUNT(DISTINCT DATE_FORMAT(date_new, '%Y-%m')) = 13
)
SELECT 
    t.ID_client,    
    SUM(t.Sum_payment) / COUNT(DISTINCT t.Id_check) AS avg_check,    
    SUM(t.Sum_payment) / COUNT(DISTINCT DATE_FORMAT(t.date_new, '%Y-%m')) AS avg_monthly_spending,    
    COUNT(*) AS total_operations
FROM customers_transactions.transactions t
JOIN continuous_clients cc ON t.ID_client = cc.ID_client
WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY t.ID_client;

# Задание 2. Аналитика в разрезе месяцев | Основные ежемесячные показатели и доли рынка

SELECT 
    DATE_FORMAT(date_new, '%Y-%m') AS month_period,    
    SUM(Sum_payment) / COUNT(DISTINCT Id_check) AS avg_check_per_month,    
    COUNT(*) / COUNT(DISTINCT ID_client) AS avg_operations_per_client,    
    COUNT(DISTINCT ID_client) AS unique_clients_count,    
    COUNT(*) / SUM(COUNT(*)) OVER() * 100 AS share_of_total_operations_pct,    
    SUM(Sum_payment) / SUM(SUM(Sum_payment)) OVER() * 100 AS share_of_total_amount_pct
FROM customers_transactions.transactions
WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY DATE_FORMAT(date_new, '%Y-%m')
ORDER BY month_period;

# Процентное соотношение M/F/NA и их доли затрат по месяцам

WITH monthly_gender_base AS (
    SELECT 
        DATE_FORMAT(t.date_new, '%Y-%m') AS month_period,
        CASE 
            WHEN c.Gender IS NULL OR c.Gender = '' THEN 'NA'
            ELSE c.Gender 
        END AS gender_group,
        t.Sum_payment
    FROM customers_transactions.transactions t
    LEFT JOIN customers_transactions.customers c ON t.ID_client = c.Id_client
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
)
SELECT 
    month_period,
    gender_group,    
    COUNT(*) / SUM(COUNT(*)) OVER(PARTITION BY month_period) * 100 AS gender_operations_share_pct,    
    SUM(Sum_payment) / SUM(SUM(Sum_payment)) OVER(PARTITION BY month_period) * 100 AS gender_spending_share_pct
FROM monthly_gender_base
GROUP BY month_period, gender_group
ORDER BY month_period, gender_group;

# Задание 3. Аналитика по возрастным группам (с шагом 10 лет) | Общие показатели за весь годовой период

WITH age_base AS (
    SELECT 
        t.Sum_payment,
        CASE 
            WHEN c.Age IS NULL THEN 'NA'
            ELSE CONCAT(FLOOR(c.Age / 10) * 10, '-', (FLOOR(c.Age / 10) * 10) + 9)
        END AS age_group
    FROM customers_transactions.transactions t
    LEFT JOIN customers_transactions.customers c ON t.ID_client = c.Id_client
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
)
SELECT 
    age_group,    
    SUM(Sum_payment) AS total_amount,    
    COUNT(*) AS total_operations
FROM age_base
GROUP BY age_group
ORDER BY age_group;

# Поквартальная динамика возрастных групп

WITH age_quarter_base AS (
    SELECT 
        CONCAT(YEAR(t.date_new), '-Q', QUARTER(t.date_new)) AS quarter_period,
        CASE 
            WHEN c.Age IS NULL THEN 'NA'
            ELSE CONCAT(FLOOR(c.Age / 10) * 10, '-', (FLOOR(c.Age / 10) * 10) + 9)
        END AS age_group,
        t.Id_check,
        t.ID_client,
        t.Sum_payment
    FROM customers_transactions.transactions t
    LEFT JOIN customers_transactions.customers c ON t.ID_client = c.Id_client
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
)
SELECT 
    quarter_period,
    age_group,    
    SUM(Sum_payment) / COUNT(DISTINCT Id_check) AS avg_check_in_quarter,    
    SUM(Sum_payment) / COUNT(DISTINCT ID_client) AS avg_spending_per_client_in_quarter,    
    SUM(Sum_payment) / SUM(SUM(Sum_payment)) OVER(PARTITION BY quarter_period) * 100 AS pct_of_quarter_amount,    
    COUNT(*) / SUM(COUNT(*)) OVER(PARTITION BY quarter_period) * 100 AS pct_of_quarter_operations
FROM age_quarter_base
GROUP BY quarter_period, age_group
ORDER BY quarter_period, age_group;
