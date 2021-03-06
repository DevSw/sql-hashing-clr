CREATE FUNCTION dbo.GetHashHybrid(@algorithm NVARCHAR(4000),@input VARBINARY(MAX))
RETURNS VARBINARY(8000) WITH SCHEMABINDING
AS
BEGIN
RETURN ( 
	SELECT CASE
		WHEN DATALENGTH(@input) > 8000
			THEN dbo.GetHash(@algorithm,@input)
		ELSE
			HASHBYTES(@algorithm,@input)
		END
)
END