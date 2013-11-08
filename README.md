sql-hashing-clr
===============

SQL Server CLR that implements hashing for 4 different algorithms that does not have SQL Server's 8000 byte input limitation. This project also includes a function that uses both the HASHBYTES() function and this CLR based on the length of the input.

###clr.cs
The actual CLR class.

###function.sql
The function that either calls SQL Server's HASHBYTES() function or the CLR based on the length of the input.

###sub8000-benchmark.sql
This script evaluates the CPU usage of the CLR vs. HASHBYTES(). Detailed information can be found in the comments for the script.

###hybrid-benchmark.sql
This script evaluates the CPU usage of the CLR vs. the hybrid function which uses a combination of the CLR and HASHBYTES(). Detailed information can be found in the script.
