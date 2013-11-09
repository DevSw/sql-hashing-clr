sql-hashing-clr
===============

SQL Server CLR that implements hashing for 4 different algorithms that does not have SQL Server's 8000 byte input limitation. This project also includes a function that uses both the HASHBYTES() function and this CLR based on the length of the input.

###HashUtil.cs
The actual CLR class.

###GetHashHybrid.function.sql
The function that either calls SQL Server's HASHBYTES() function or the CLR based on the length of the input.

###benchmark-under8000.script.sql
This script evaluates the CPU usage of HASHBYTES(), the CLR, and the hybrid function using inputs under 8000 bytes. Detailed information can be found in the comments for the script.

###benchmark-over8000.script.sql
This script evaluates the CPU usage of the CLR vs. the hybrid function using inputes both under and over 8000 bytes. Detailed information can be found in the script.
