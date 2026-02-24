#!/bin/bash

# Скрипт для обновления файлов Unity проекта на Steam Deck
# Загружает файлы из репозитория https://github.com/LeZork/unity-steamdeck-project

echo "=== Обновление Unity проекта для Steam Deck ==="

# Переходим в директорию проекта
cd /home/deck/Emulation/roms/ps2/steamdeck || {
    echo "Ошибка: Не удалось перейти в директорию /home/deck/Emulation/roms/ps2/steamdeck"
    echo "Убедитесь, что проект находится в правильном месте"
    exit 1
}

echo "Текущая директория: $(pwd)"

# Создаем временную папку для загрузки
TEMP_DIR=$(mktemp -d)
echo "Создана временная директория: $TEMP_DIR"

# Переходим во временную директорию
cd "$TEMP_DIR" || exit 1

# Клонируем репозиторий
echo "Загрузка файлов из репозитория..."
git clone https://github.com/LeZork/unity-steamdeck-project.git

if [ $? -ne 0 ]; then
    echo "Ошибка при клонировании репозитория"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Переходим в директорию с загруженными файлами
cd unity-steamdeck-project || exit 1

# Проверяем наличие файлов
echo "Проверка загруженных файлов..."
if [ ! -f "libdecor-0.so.0" ] || [ ! -f "libdecor-cairo.so" ] || [ ! -f "my_project.x86_64" ] || [ ! -f "UnityPlayer.so" ]; then
    echo "Ошибка: Не все необходимые файлы найдены в репозитории"
    echo "Найдены файлы:"
    ls -la
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Возвращаемся в директорию проекта
cd /home/deck/My_project || exit 1

# Создаем резервную копию текущих файлов (опционально)
BACKUP_DIR="/home/deck/Emulation/roms/ps2/steamdeck_$(date +%Y%m%d_%H%M%S)"
echo "Создание резервной копии в: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -f libdecor-0.so.0 "$BACKUP_DIR/" 2>/dev/null
cp -f libdecor-cairo.so "$BACKUP_DIR/" 2>/dev/null
cp -f my_project.x86_64 "$BACKUP_DIR/" 2>/dev/null
cp -f UnityPlayer.so "$BACKUP_DIR/" 2>/dev/null
cp -rf my_project_Data "$BACKUP_DIR/" 2>/dev/null
echo "Резервная копия создана"

# Копируем новые файлы
echo "Копирование новых файлов..."
cp -f "$TEMP_DIR/unity-steamdeck-project/libdecor-0.so.0" ./
cp -f "$TEMP_DIR/unity-steamdeck-project/libdecor-cairo.so" ./
cp -f "$TEMP_DIR/unity-steamdeck-project/my_project.x86_64" ./
cp -f "$TEMP_DIR/unity-steamdeck-project/UnityPlayer.so" ./

# Копируем папку с данными, если она существует в репозитории
if [ -d "$TEMP_DIR/unity-steamdeck-project/my_project_Data" ]; then
    echo "Копирование папки my_project_Data..."
    cp -rf "$TEMP_DIR/unity-steamdeck-project/my_project_Data" ./
fi

# Копируем README, если есть
if [ -f "$TEMP_DIR/unity-steamdeck-project/README.md" ]; then
    cp -f "$TEMP_DIR/unity-steamdeck-project/README.md" ./
fi

# Устанавливаем права на выполнение для исполняемых файлов
echo "Установка прав на выполнение..."
chmod +x my_project.x86_64
chmod +x UnityPlayer.so

# Удаляем временную директорию
echo "Очистка временных файлов..."
rm -rf "$TEMP_DIR"

# Проверяем результат
echo "=== Обновление завершено ==="
echo "Содержимое директории проекта после обновления:"
ls -la

echo ""
echo "Резервная копия сохранена в: $BACKUP_DIR"
echo "Для запуска игры выполните: ./my_project.x86_64"