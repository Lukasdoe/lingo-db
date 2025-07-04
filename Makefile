ROOT_DIR := $(dir $(abspath $(firstword $(MAKEFILE_LIST))))
NPROCS := $(shell if [ "$(shell uname)" = "Darwin" ]; then sysctl -n hw.logicalcpu; else nproc; fi)
LLVM_LIT_BINARY := lit
CMAKE_PREFIX_PATH ?= ""
CMAKE_PREFIX_PATH_FLAG := -DCMAKE_PREFIX_PATH=$(CMAKE_PREFIX_PATH)

DATA_BUILD_TYPE ?= debug
TEST_BUILD_TYPE ?= debug
SQLITE_TEST_BUILD_TYPE ?= release


build:
	mkdir -p $@


resources/data/%/.rawdata:
	@mkdir -p $@
	@dir_name=$(shell dirname $@) && \
	base_name=$$(basename $$dir_name) && \
	script_name=$$(echo $$base_name | sed -E 's/-[0-9]+$$//') && \
	scale_factor=$$(echo $$base_name | grep -oE '[0-9]+$$' || echo 1) && \
	abs_path=$$(realpath $@) && \
	if [ -f tools/generate/$$script_name.sh ]; then \
		echo "Running bash tools/generate/$$script_name.sh with $$abs_path $$scale_factor"; \
		bash tools/generate/$$script_name.sh $$abs_path $$scale_factor; \
	else \
		echo "Error: Script tools/generate/$$script_name.sh not found!" >&2; \
		exit 1; \
	fi



resources/data/%/.stamp: resources/data/%/.rawdata build/lingodb-$(DATA_BUILD_TYPE)/.buildstamp
	rm -f resources/data/$*/*.arrow
	rm -f resources/data/$*/*.hashidx
	rm -f resources/data/$*/*.lingodb
	@dir_name=$(shell dirname $@) && \
	base_name=$$(basename $$dir_name) && \
	dataset_name=$$(echo $$base_name | sed -E 's/-[0-9]+$$//') && \
	cd $(dir $@)/.rawdata && $(ROOT_DIR)/build/lingodb-$(DATA_BUILD_TYPE)/sql ../ < $(ROOT_DIR)/resources/sql/$$dataset_name/initialize.sql
	touch $@
	rm -rf resources/data/$*/.rawdata



LDB_ARGS= -DCMAKE_EXPORT_COMPILE_COMMANDS=ON  \
	   	 -DCMAKE_BUILD_TYPE=Debug

build/lingodb-debug/.stamp: build
	cmake -G Ninja . -B $(dir $@) $(LDB_ARGS) -DCMAKE_BUILD_TYPE=Debug $(CMAKE_PREFIX_PATH_FLAG)
	touch $@

build/lingodb-debug/.buildstamp: build/lingodb-debug/.stamp
	cmake --build $(dir $@) -- -j${NPROCS}
	touch $@


build/lingodb-release/.buildstamp: build/lingodb-release/.stamp
	cmake --build $(dir $@) -- -j${NPROCS}
	touch $@

build/lingodb-release/.stamp: build
	cmake -G Ninja . -B $(dir $@) $(LDB_ARGS) -DCMAKE_BUILD_TYPE=Release $(CMAKE_PREFIX_PATH_FLAG)
	touch $@

build/lingodb-asan/.buildstamp: build/lingodb-asan/.stamp
	cmake --build $(dir $@) -- -j${NPROCS}
	touch $@

build/lingodb-asan/.stamp: build
	cmake -G Ninja . -B $(dir $@) $(LDB_ARGS) -DCMAKE_BUILD_TYPE=ASAN $(CMAKE_PREFIX_PATH_FLAG)
	touch $@

build/lingodb-relwithdebinfo/.buildstamp: build/lingodb-relwithdebinfo/.stamp
	cmake --build $(dir $@) -- -j${NPROCS}
	touch $@

build/lingodb-relwithdebinfo/.stamp: build
	cmake -G Ninja . -B $(dir $@) $(LDB_ARGS) -DCMAKE_BUILD_TYPE=RelWithDebInfo $(CMAKE_PREFIX_PATH_FLAG)
	touch $@
build/lingodb-debug-coverage/.stamp: build
	cmake -G Ninja . -B $(dir $@) $(LDB_ARGS) -DCMAKE_CXX_FLAGS="-O0 -fprofile-instr-generate -fcoverage-mapping" -DCMAKE_C_FLAGS="-O0 -fprofile-instr-generate -fcoverage-mapping" -DCMAKE_CXX_COMPILER=clang++-20 -DCMAKE_C_COMPILER=clang-20 $(CMAKE_PREFIX_PATH_FLAG)
	touch $@

.PHONY: run-test
run-test: build/lingodb-$(TEST_BUILD_TYPE)/.stamp
	cmake --build $(dir $<) --target mlir-db-opt run-mlir run-sql sql-to-mlir sqlite-tester tester -- -j${NPROCS}
	$(MAKE) test-no-rebuild

test-no-rebuild: build/lingodb-$(TEST_BUILD_TYPE)/.buildstamp resources/data/test/.stamp resources/data/uni/.stamp
	${LLVM_LIT_BINARY} -v build/lingodb-$(TEST_BUILD_TYPE)/test/lit -j 1
	./build/lingodb-$(TEST_BUILD_TYPE)/tester
	find ./test/sqlite-small/ -maxdepth 1 -type f -name '*.test' | xargs -L 1 -P ${NPROCS} ./build/lingodb-$(TEST_BUILD_TYPE)/sqlite-tester

sqlite-test-no-rebuild: build/lingodb-$(SQLITE_TEST_BUILD_TYPE)/.buildstamp
	find ./test/sqlite/ -maxdepth 1 -type f -name '*.test' | xargs -L 1 -P ${NPROCS} ./build/lingodb-$(SQLITE_TEST_BUILD_TYPE)/sqlite-tester

.PHONY: test-coverage
test-coverage: build/lingodb-debug-coverage/.stamp resources/data/test/.stamp resources/data/uni/.stamp
	cmake --build $(dir $<) --target mlir-db-opt run-mlir run-sql sql-to-mlir tester -- -j${NPROCS}
	${LLVM_LIT_BINARY} -v --per-test-coverage  $(dir $<)/test/lit
	LLVM_PROFILE_FILE=$(dir $<)/tester.profraw ./build/lingodb-debug-coverage/tester
	find $(dir $<) -type f -name "*.profraw" > $(dir $<)/profraw-files
	echo $(dir $<)/tester.profraw >> $(dir $<)/profraw-files
	llvm-profdata-20 merge -o $(dir $<)/coverage.profdata --input-files=$(dir $<)/profraw-files

coverage: build/lingodb-debug-coverage/.stamp
	$(MAKE) test-coverage
	mkdir -p build/coverage-report
	llvmcov2html --exclude-dir=$(dir $<),vendored,test build/coverage-report --projectroot=$(ROOT_DIR) $(dir $<)/run-mlir $(dir $<)/run-sql $(dir $<)/mlir-db-opt $(dir $<)/sql-to-mlir $(dir $<)/tester $(dir $<)/coverage.profdata


build-docker-dev:
	DOCKER_BUILDKIT=1 docker build -f "tools/docker/Dockerfile" -t lingodb-dev --target baseimg "."

build-docker-py-dev:
	DOCKER_BUILDKIT=1 docker build -f "tools/python/bridge/Dockerfile" -t lingodb-py-dev --target devimg "."


build-release: build/lingodb-release/.buildstamp
build-debug: build/lingodb-debug/.buildstamp
build-asan: build/lingodb-asan/.buildstamp

.PHONY: clean
clean:
	rm -rf build

lint: build/lingodb-debug/.stamp
	cmake --build build/lingodb-debug --target build_includes
	@if [ "$(shell uname)" = "Darwin" ]; then \
		sed -i '' 's/-fno-lifetime-dse//g' build/lingodb-debug/compile_commands.json; \
	else \
		sed -i 's/-fno-lifetime-dse//g' build/lingodb-debug/compile_commands.json; \
	fi
	python3 tools/scripts/run-clang-tidy.py -p $(dir $<) -quiet -header-filter="$(shell pwd)/include/.*" -exclude="arrow|vendored" -clang-tidy-binary=clang-tidy-20

format:
	find include \( -name '*.cpp' -o -name '*.h' \) -exec clang-format-20 -i {} +
	find src \( -name '*.cpp' -o -name '*.h' \) -exec clang-format-20 -i {} +
	find tools \( -name '*.cpp' -o -name '*.h' \) -exec clang-format-20 -i {} +
	find test \( -name '*.cpp' -o -name '*.h' \) -exec clang-format-20 -i {} +
