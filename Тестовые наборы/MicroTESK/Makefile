# Makefile для MicroTESK: запуск тестов и сбор покрытия

MICROTESK_HOME ?= $(CURDIR)

.PHONY: all clean examples algorithms synthetics run

all: examples algorithms synthetics
	@echo "Все тесты выполнены."

# Запуск тестов по папкам
examples:
	@echo "Запуск тестов из examples/..."
	make -C examples

algorithms:
	@echo "Запуск тестов из algorithms/..."
	make -C algorithms

synthetics:
	@echo "Запуск тестов из synthetics/..."
	make -C synthetics

# Запуск основного тестового скрипта
run:
	@echo "Запуск run_microtesk_tests.sh..."
	./run_microtesk_tests.sh
	@echo "Тесты завершены."

# Очистка сгенерированных файлов и coverage_html
clean:
	@echo "Очистка output/ и coverage_html/..."
	if [ -d $(MICROTESK_HOME)/output ]; then \
		rm -r -f $(MICROTESK_HOME)/output/*; \
	fi
	if [ -d $(MICROTESK_HOME)/coverage_html ]; then \
		rm -r -f $(MICROTESK_HOME)/coverage_html/*; \
	fi
	@echo "Очистка завершена."
