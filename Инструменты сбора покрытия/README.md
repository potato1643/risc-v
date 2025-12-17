# Инструкция пользователя

**Цель:** создать первый рабочий прототип и собрать основную информацию: Spike и gcov, один тестовый пример MicroTESK и показатели покрытия. Также подготовить инструкцию по запуску и сбору результатов.

## Шаги настройки окружения

Предполагается, что переменная окружения **RISCV** указывает на путь установки инструментов RISC-V.

Все инструменты RISC-V устанавливаются в каталог:

```bash
$RISCV
```

Установка переменной окружения:

```bash
export RISCV=/opt/riscv
export PATH=$RISCV/bin:$PATH
source ~/.bashrc
```

### 1. Обновление системы

```bash
apt update && apt upgrade -y
```

### **2. Установка JDK11**

```bash
apt install openjdk-11-jdk
```

Проверка установки:

```bash
java -version
```

### **3. Установка базовых инструментов**

```bash
apt install -y git wget curl build-essential python3 python3-pip
```

### **4. Установка инструментальной цепочки RISC-V**

```bash
cd /opt
git clone https://github.com/riscv-collab/riscv-gnu-toolchain.git
cd riscv-gnu-toolchain
./configure --prefix=/opt/riscv --with-arch=rv64gc --with-abi=lp64
make -j$(nproc)

export PATH=/opt/riscv/bin:$PATH
```

Проверка:

```bash
riscv64-unknown-elf-gcc --version
riscv64-unknown-elf-objdump --version
```

### **5. Установка MicroTESK**

Скачать последнюю версию:

https://forge.ispras.ru/projects/microtesk/wiki/Installation_Guide

Имя файла вида:

```bash
microtesk-riscv-<version>.tar.gz
```

Распаковка:

```bash
cd /opt
tar -xzf microtesk-riscv-*.tar.gz
mv microtesk-riscv-* microtesk-riscv
```

Путь установки далее обозначается как:

```bash
/opt/microtesk-riscv
```

#### Добавление переменных окружения

```bash
export MICROTESK_HOME=/opt/microtesk-riscv
export PATH=$MICROTESK_HOME/bin:$PATH
```

### **6. Сборка Spike с поддержкой gcov**

```bash
apt-get install device-tree-compiler libboost-regex-dev libboost-system-dev

git clone https://github.com/riscv-software-src/riscv-isa-sim
cd riscv-isa-sim
mkdir build
cd build

../configure --prefix=$RISCV
../configure --prefix=$RISCV \
    CFLAGS="--coverage" \
    CXXFLAGS="--coverage" \
    LDFLAGS="--coverage"

make
sudo make install
```

### **7. Установка lcov**

```bash
sudo apt-get update
sudo apt-get install lcov
lcov --version
```

## **Шаги выполнения эксперимента**

### **Шаг 1: Компиляция программы RISC-V и генерация теста MicroTESK**

Переход в каталог шаблонов (пример — *torture*):

```bash
cd $MICROTESK_HOME/arch/riscv/templates/torture
```

Запуск генерации:

```bash
make
```

Будут автоматически выполнены **run.sh** и **run-toolchain.sh**.

**Путь к результатам:**

```bash
$MICROTESK_HOME/output/torture/torture/
```

### **Шаг 2: Запуск программы на Spike и получение trace**

```bash
spike -l int_divide_0000.elf > trace.txt 2>&1
```

### **Шаг 3: Сбор покрытия с помощью lcov**

Переход в каталог Spike:

```bash
cd opt/riscv-isa-sim/build
```

Сбор покрытия:

```bash
lcov --capture --directory . --output-file coverage.info --no-external
genhtml coverage.info --output-directory out
```

Структура выходного каталога:

```bash
opt/riscv-isa-sim/build/out/
├── amber.png
├── emerald.png
├── glass.png
├── gcov.css
├── index-sort-l.html
├── index-sort-f.html
├── index.html   ← ★★★ Главная HTML-страница покрытия
├── ruby.png
├── snow.png
└── updown.png
```

### **Схема процесса покрытия**

```bash
Компиляция (--coverage)
↓
Создание .gcno
↓
Запуск Spike
↓
Создание .gcda
↓
lcov → coverage.info
↓
genhtml → HTML отчёт
↓
Просмотр покрытия в браузере
```

## **Список литературы**

1. **gcov — программа анализа покрытия в составе GCC.**
   Gcov позволяет определить, какие строки кода были выполнены и сколько раз.
   https://gcc.gnu.org/onlinedocs/gcc/Gcov.html
2. **Spike — функциональный симулятор ISA RISC-V.**
   https://github.com/riscv-software-src/riscv-isa-sim
3. **lcov — графический интерфейс для gcov, собирающий и отображающий данные покрытия.**
   https://github.com/linux-test-project/lcov
4. **GNU Toolchain for RISC-V**
   https://github.com/riscv-collab/riscv-gnu-toolchain
5. **Материалы по MicroTESK**
   - https://www.microtesk.org/download/microtesk-riscv
   - https://forge.ispras.ru/projects/microtesk/wiki/Installation_Guide
   - https://github.com/ispras/microtesk
   - https://github.com/ispras/riscv-avs
6. **RISC-V Proxy Kernel (pk)**
   https://github.com/riscv-software-src/riscv-pk