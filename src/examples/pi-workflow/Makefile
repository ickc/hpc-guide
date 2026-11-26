SEEDS := $(shell seq 1 64)

# The reduce needs every count; $^ is all of them, and $@ the target, pi.txt.
pi.txt: $(SEEDS:%=results/%.txt)
	python ../pi/pi.py reduce $^ > $@

# One count task per seed; $* is the seed, the part of the name that % matched.
results/%.txt:
	@mkdir -p results
	python ../pi/pi.py count $* > $@
