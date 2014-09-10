/*	This script evaluates the CPU usage of the CLR vs. hybrid 
	function that uses a combination of the CLR and HASHBYTES()
	vs fn_repl_hash_binary. We create a table of test values of 
	varying length under and over 8000 bytes, run both functions 
	over the test table many times with each common hashing 
	algorithm, and save off the CPU time.
*/

set nocount on;

/*****Create Test Value Tables*****/
if OBJECT_ID('dbo.TestValuesHybrid') is not null
	drop table dbo.TestValuesHybrid;
create table dbo.TestValuesHybrid
(
	Value VARCHAR(MAX) NOT NULL
);

/*	Populate the table with random NEWID() values.
	We achieve a semi-uniform length distribution by inserting 6000 values of
	each different lengths at multiples of 500. We'll start with 4500 and go 
	to 12000, giving us 96000 rows (16*6000, 8 over and 8 under length 8000).
*/
declare @length int = 4500;
while (@length < 12500)
BEGIN
	
	declare @c int = 0;
	while (@c < 6000)
	BEGIN

		declare @replAmt int;
		select @replAmt = @length / 36; --Figure out how many times we need to repeat

		insert into dbo.TestValuesHybrid with (tablockx)
		select REPLICATE(CAST(NEWID() AS VARCHAR(MAX)),@replAmt);

		set @c = @c + 1;

	END

	set @length = @length + 500;

END

/*****Create algorithm and output tables*****/
if OBJECT_ID('tempdb..#hashAlg') is not null
	drop table #hashAlg;
create table #hashAlg
(
	algorithm varchar(8),
	processed int
);

Insert into #hashAlg
select 'MD5',0 union all
select 'SHA1',0 union all
select 'SHA2_256',0 union all
select 'SHA2_512',0;

if OBJECT_ID('tempdb..#hashResult') is not null
	drop table #hashResult;
create table #hashResult
(
	algorithm varchar(20),
	cpu bigint
);

declare @processGoal int = 31, @startCpu bigint, @minProcessed int, @alg varchar(8);

/*****Run tests on CLR*****/
/*	We run each algorithm only once in a row. We see what the minimum
	count for all are, and run algorithms of that count, until we get
	to our goal.
*/
while exists (Select 1 from #hashAlg where processed <> @processGoal)
BEGIN

	select @minProcessed = min(processed) from #hashAlg;

	while exists (select 1 from #hashAlg where processed <> (@minProcessed + 1))
	BEGIN

		select top 1 @alg = algorithm from #hashAlg where processed = @minProcessed;
		
		--Dummy output table
		declare @outputCLR as table ( o varbinary(8000) );

		--Save off 'before' CPU stats
		select @startCpu = cpu_time from sys.dm_exec_requests where session_id = @@SPID;

		insert into @outputCLR
		select dbo.GetHash(@alg,convert(varbinary(max),Value)) from dbo.TestValuesHybrid;

		--Calculate total CPU stats and save to table
		insert into #hashResult
		select 'CLR_' + @alg, cpu_time - @startCpu from sys.dm_exec_requests where session_id = @@SPID;

		update h 
		set h.processed = h.processed + 1 
		from #hashAlg h 
		where h.algorithm = @alg;

	END
END

--reset algorithms for next test
update #hashAlg set processed = 0;

/*****Run tests on Hybrid*****/
while exists (Select 1 from #hashAlg where processed <> @processGoal)
BEGIN

	select @minProcessed = min(processed) from #hashAlg;

	while exists (select 1 from #hashAlg where processed <> (@minProcessed + 1))
	BEGIN

		select top 1 @alg = algorithm from #hashAlg where processed = @minProcessed;
		
		declare @outputHybrid as table ( o varbinary(8000) );

		select @startCpu = cpu_time from sys.dm_exec_requests where session_id = @@SPID;
		insert into @outputHybrid
		select dbo.GetHashHybrid(@alg,convert(varbinary(max),Value)) from dbo.TestValuesHybrid;

		insert into #hashResult
		select 'Hybrid_' + @alg, cpu_time - @startCpu from sys.dm_exec_requests where session_id = @@SPID;

		update h 
		set h.processed = h.processed + 1 
		from #hashAlg h 
		where h.algorithm = @alg;

	END
END

--reset algorithms for next test
update #hashAlg set processed = 0;
delete from #hashAlg where algorithm not like 'MD5';

/*****Run tests on fn_repl_hash_binary*****/
while exists (Select 1 from #hashAlg where processed <> @processGoal)
BEGIN

	select @minProcessed = min(processed) from #hashAlg;

	while exists (select 1 from #hashAlg where processed <> (@minProcessed + 1))
	BEGIN

		select top 1 @alg = algorithm from #hashAlg where processed = @minProcessed;
		
		declare @outputRepl as table ( o varbinary(8000) );

		select @startCpu = cpu_time from sys.dm_exec_requests where session_id = @@SPID;
		insert into @outputRepl
		select master.sys.fn_repl_hash_binary(convert(varbinary(max),Value)) from dbo.TestValuesHybrid;

		insert into #hashResult
		select 'Repl_' + @alg, cpu_time - @startCpu from sys.dm_exec_requests where session_id = @@SPID;

		update h 
		set h.processed = h.processed + 1 
		from #hashAlg h 
		where h.algorithm = @alg;

	END
END

/*****Get stats*****/
/*	Since SQL doesn't have a built-in median function, we can
	use the ranking functions to determine the middle row.
*/
select 
	h.algorithm
,	AVG(h.cpu) as cpuAverage
,	c.cpu as cpuMedian
,	CAST(STDEV(h.cpu) as int) as cpuStd_dev
from #hashResult h
	inner join
		(Select 
			algorithm
		,	cpu
		,	ROW_NUMBER() OVER (PARTITION BY algorithm ORDER BY cpu asc) as row
		from #hashResult) c
		on c.algorithm = h.algorithm
		and c.row = (select @processGoal / 2 + 1)
group by h.algorithm, c.cpu
order by 2 asc;