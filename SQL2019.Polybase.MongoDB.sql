
/* *** *** *** */
-- Check installation
SELECT SERVERPROPERTY ('IsPolyBaseInstalled') AS IsPolyBaseInstalled; 

-- Enable polybase
EXEC sp_configure @configname = 'polybase enabled', @configvalue = 1;
RECONFIGURE WITH OVERRIDE;  

-- Check polybase 
exec sp_configure 'polybase enabled'

--> restart SQL Server Service and PolyBase services
/* *** *** *** */

/*
--> on MongoDB:

use admin
db.createUser(
  {
    user: "admin",
    pwd: "admin123",
    roles: [ { role: "userAdminAnyDatabase", db: "admin" }, "readWriteAnyDatabase" ]
  }
)
*/


--> external table for MongoDB
USE [PolybaseDemo]
GO

-- 1. Crate Database Master key – Specify the password for encryption
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'password@123';

-- 2. Create a Database scoped credential
CREATE DATABASE SCOPED CREDENTIAL myMongoDBCredential
WITH IDENTITY = 'admin', Secret = 'admin123';

-- 3. Create external data source 
-- In this step, you need to specify the mongodb location. 
-- It is the change in the external table configuration as compared with SQL and Oracle data source 
-- LOCATION format '<type>://<server>[:<port>]'.
 
 --> drop EXTERNAL DATA SOURCE MongoDBSource
CREATE EXTERNAL DATA SOURCE MongoDBSource
WITH 
(
	LOCATION = 'mongodb://127.0.0.1:27017',
	CREDENTIAL = myMongoDBCredential -- specify credential created in step 2
	, CONNECTION_OPTIONS = 'ssl=false;'
);

-- 4. Create an external table
-- In the external table create the columns as per the document in the MongoDB. 
-- Here you can find the sample query to create an external table

--> drop EXTERNAL TABLE MongoDB_Products
CREATE EXTERNAL TABLE MongoDB_Products
(
	[_id] NVARCHAR(24) COLLATE Latin1_General_CI_AS NOT NULL, 
	[item] NVARCHAR(4000) COLLATE Latin1_General_CI_AS, 
	[qty] FLOAT(53), 
	[type] NVARCHAR(4000) COLLATE Latin1_General_CI_AS
)
WITH (
	LOCATION='DemoPolybase.products',
	DATA_SOURCE= MongoDBSource
);

-- 5. optional --> create stats for performance
-- CREATE STATISTICS statistics_item ON MongoDB_Products (item) WITH FULLSCAN;



--> (1)
SELECT * FROM [dbo].[MongoDB_Products] ORDER BY qty
GO

--> (2)
SELECT * FROM [dbo].[MongoDB_Products] 
WHERE cast(qty as int) > 15
ORDER BY qty
GO

--> (3)
SELECT 
	M.item, M.qty, M.type
FROM [dbo].[MongoDB_Products] M
WHERE cast(type as varchar(250)) like 'Item Type P %'
OPTION(DISABLE EXTERNALPUSHDOWN)
GO
SELECT 
	M.item, M.qty, M.type
FROM [dbo].[MongoDB_Products] M
WHERE cast(type as varchar(250)) like 'Item Type P %'
GO

--> (4)
select * from MongoDB_Products
UNION
select * from SQLServer_Products
GO

--> (5)
SELECT 
	C.Category,
	M.item, M.qty, M.type
FROM [dbo].[MongoDB_Products] M
JOIN Categories C on C.productName = M.item
WHERE cast(type as varchar(250)) like 'Item Type P %'
GO



-- shows all the external tables in the current database: 
select * from sys.external_tables

SELECT execution_id, status,st.text, dr.total_elapsed_time  
FROM sys.dm_exec_distributed_requests  dr  
cross apply sys.dm_exec_sql_text(sql_handle) st  
ORDER BY total_elapsed_time DESC;

-- information about the data source
SELECT name, location, type FROM sys.external_data_sources


/*
-- Query with predicate without pushdown:
SELECT ...
  FROM ...
  where ...
  order by ...
  OPTION(DISABLE EXTERNALPUSHDOWN)

	/*
	When we create an external data source for external table, 
	we have the option to specify the value for PUSHDOWN as ON or OFF. 
	The default value for pushdown is ON. 
	Therefore, we do not need to specify a pushdown value if we want to enable it. 
	Using PUSHDOWN, we can choose to move the computation to source system or not. 
	*/
*/
