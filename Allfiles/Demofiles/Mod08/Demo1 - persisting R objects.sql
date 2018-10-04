USE AirlineData

-- Create a table for storing charts:
CREATE TABLE [dbo].[charts]
(
   id    VARCHAR(200) NOT NULL PRIMARY KEY,
   value VARBINARY(MAX) NOT NULL
)