SCALE_FACTOR?=1
PATH_BKP?=$(abspath $(CURDIR)/..)/tpch-bkp
TABLES = customer lineitem nation orders partsupp part region supplier
TABLE_FILES = $(foreach table, $(TABLES), $(PATH_BKP)/tpch-dbgen/$(table).tbl)

$(PATH_BKP)/TPC-H.db: $(TABLE_FILES)
	./create_db.sh $(PATH_BKP) $(TABLES) 

$(TABLE_FILES): $(PATH_BKP)/tpch-dbgen/dbgen
	cd $(PATH_BKP)/tpch-dbgen && $(PATH_BKP)/tpch-dbgen/dbgen -v -f -s $(SCALE_FACTOR)
	chmod +r $(TABLE_FILES)

$(PATH_BKP)/tpch-dbgen/dbgen: $(PATH_BKP)/tpch-dbgen/makefile
	cd $(PATH_BKP)/tpch-dbgen && $(MAKE)

clean:
	rm -rf $(PATH_BKP)/TPC-H.db $(TABLE_FILES) $(PATH_BKP)/tpch-dbgen/dbgen

all: $(PATH_BKP)/TPC-H.db
