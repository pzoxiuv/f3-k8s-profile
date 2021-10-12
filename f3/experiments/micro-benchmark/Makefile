all: rand.c
	gcc -DTIMING -Wall -pg --coverage -oreader reader.c
	gcc -DTIMING -Wall -pg --coverage -owriter writer.c rand.c
	gcc -DTIMING -Wall -pg --coverage -lpthread -owriter-many writer-100.c rand.c
	gcc -DTIMING -Wall -pg --coverage -lpthread -oreader-many reader-100.c

rand.c: rand.bin
	xxd -i rand.bin > rand.c

rand.bin:
	dd if=/dev/urandom of=rand.bin bs=1M count=4

copy:
	kubectl cp reader testing1-pod-kubes1:/reader -nopenwhisk
	kubectl cp reader testing1-pod-kubes3:/reader -nopenwhisk
	kubectl cp writer testing1-pod-kubes1:/writer -nopenwhisk
	kubectl cp writer testing1-pod-kubes3:/writer -nopenwhisk
	kubectl cp reader-many testing1-pod-kubes1:/reader-many -nopenwhisk
	kubectl cp reader-many testing1-pod-kubes3:/reader-many -nopenwhisk
	kubectl cp writer-many testing1-pod-kubes1:/writer-many -nopenwhisk
	kubectl cp writer-many testing1-pod-kubes3:/writer-many -nopenwhisk
