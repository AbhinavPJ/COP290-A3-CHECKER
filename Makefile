.PHONY: build app run clean

BUILD_DIR = ../build
SRC = sample.cpp
OUT = $(BUILD_DIR)/app

CXX = c++
CXXFLAGS = -std=c++17 -I../include
LDFLAGS = -L$(BUILD_DIR) -lleveldb -lpthread

build:
	mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 ..
	cd $(BUILD_DIR) && cmake --build . -j

app: build
	$(CXX) $(CXXFLAGS) $(SRC) $(LDFLAGS) -o $(OUT)

run: app
	rm -rf /tmp/testdb
	./$(OUT) out.txt
	@line=$$(diff ans.txt out.txt | sed -n '1s/^\([0-9]*\).*/\1/p'); \
	if [ -z "$$line" ]; then \
		echo "All tests passed"; \
	else \
		echo "Wrong answer, first mismatch at line $$line"; \
	fi

clean:
	rm -rf $(BUILD_DIR)