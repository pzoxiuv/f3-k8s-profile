select	
	l_returnflag,	
	l_linestatus,	
	sum(l_quantity) as sum_qty,	
	sum(l_extendedprice) as sum_base_price,	
	sum(l_extendedprice * (1 - l_discount)) as sum_disc_price,	
	sum(l_extendedprice * (1 - l_discount) * (1 + l_tax)) as sum_charge,	
	avg(l_quantity) as avg_qty,	
	avg(l_extendedprice) as avg_price,	
	avg(l_discount) as avg_disc,	
	count(*) as count_order	
from	
	lineitem	
where	
	l_shipdate <= date('1998-12-01', '-90 day')	
group by	
	l_returnflag,	
	l_linestatus	
order by	
	l_returnflag,	
	l_linestatus;
	
select	
	l_orderkey,	
	sum(l_extendedprice * (1 - l_discount)) as revenue,	
	o_orderdate,	
	o_shippriority	
from	
	customer,	
	orders,	
	lineitem	
where	
	c_mktsegment == 'BUILDING'	
	and c_custkey = o_custkey	
	and l_orderkey = o_orderkey	
	and o_orderdate < date('1995-03-15')	
	and l_shipdate > date('1995-03-15')	
group by	
	l_orderkey,	
	o_orderdate,	
	o_shippriority	
order by	
	revenue desc,	
	o_orderdate	
limit 100;
	
select	
	n_name,	
	sum(l_extendedprice * (1 - l_discount)) as revenue	
from	
	customer,	
	orders,	
	lineitem,	
	supplier,	
	nation,	
	region	
where	
	c_custkey = o_custkey	
	and l_orderkey = o_orderkey	
	and l_suppkey = s_suppkey	
	and c_nationkey = s_nationkey	
	and s_nationkey = n_nationkey	
	and n_regionkey = r_regionkey	
	and r_name == 'ASIA'	
	and o_orderdate >= date('1994-01-01')	
	and o_orderdate < date('1994-01-01', '+1 year')	
group by	
	n_name	
order by	
	revenue desc;
	
select	
	sum(l_extendedprice * l_discount) as revenue	
from	
	lineitem	
where	
	l_shipdate >= date('1994-01-01')	
	and l_shipdate < date('1994-01-01', '+1 year')	
	and l_discount between 0.06 - 0.01 and 0.06 + 0.01	
	and l_quantity < 24;
	
select	
	nation,	
	o_year,	
	sum(amount) as sum_profit	
from(select n_name as nation, strftime('%Y',o_orderdate) as o_year, l_extendedprice * (1 - l_discount) - ps_supplycost * l_quantity as amount from part,supplier,lineitem,partsupp,orders,nation where s_suppkey = l_suppkey and ps_suppkey = l_suppkey and ps_partkey = l_partkey and p_partkey = l_partkey and o_orderkey = l_orderkey and s_nationkey = n_nationkey and p_name like '%green%') as profit	
group by	
	nation,	
	o_year	
order by	
	nation,	
	o_year desc	
limit 100;

select	
	c_custkey,	
	c_name,	
	sum(l_extendedprice * (1 - l_discount)) as revenue,	
	c_acctbal,	
	n_name,	
	c_address,	
	c_phone,	
	c_comment	
from	
	customer,	
	orders,	
	lineitem,	
	nation	
where	
	c_custkey = o_custkey	
	and l_orderkey = o_orderkey	
	and o_orderdate >= date('1993-10-01')	
	and o_orderdate < date('1993-10-01', '+3 month')	
	and l_returnflag = 'R'	
	and c_nationkey = n_nationkey	
group by	
	c_custkey,	
	c_name,	
	c_acctbal,	
	c_phone,	
	n_name,	
	c_address,	
	c_comment	
order by	
	revenue desc	
limit 100;
