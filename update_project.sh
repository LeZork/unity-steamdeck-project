#!/bin/bash

# Скрипт для обновления файлов Unity проекта на Steam Deck
# Загружает файлы из репозитория https://github.com/LeZork/unity-steamdeck-project

echo "=== Обновление Unity проекта для Steam Deck ==="

# Конфигурация
PROJECT_DIR="/home/deck/Emulation/roms/ps2/steamdeck"
REPO_URL="https://github.com/LeZork/unity-steamdeck-project.git"
VERSION_FILE="$PROJECT_DIR/.version_info"
RAW_VERSION_URL="https://raw.githubusercontent.com/LeZork/unity-steamdeck-project/main/version.txt"

# Переходим в директорию проекта
cd "$PROJECT_DIR" || {
    echo "Ошибка: Не удалось перейти в директорию $PROJECT_DIR"
    echo "Убедитесь, что проект находится в правильном месте"
    exit 1
}

echo "Текущая директория: $(pwd)"

# Проверяем наличие локального файла версии
if [ -f "$VERSION_FILE" ]; then
    source "$VERSION_FILE"
    echo "Текущая локальная версия: $LOCAL_VERSION (от $LOCAL_DATE)"
    echo "Последние изменения: $LOCAL_CHANGES"
else
    echo "Информация о локальной версии не найдена. Будет выполнено первое обновление."
    LOCAL_VERSION="0.0.0"
    LOCAL_DATE="never"
fi

# Получаем информацию о версии из репозитория
echo ""
echo "Проверка последней версии в репозитории..."
REMOTE_VERSION_INFO=$(curl -s "$RAW_VERSION_URL")

if [ -z "$REMOTE_VERSION_INFO" ] || [[ "$REMOTE_VERSION_INFO" == *"404: Not Found"* ]]; then
    echo "Предупреждение: Не удалось получить version.txt из репозитория"
    echo "Будет выполнено обновление без проверки версии"
    REMOTE_VERSION="unknown"
    FORCE_UPDATE=true
else
    # Парсим version.txt
    REMOTE_VERSION=$(echo "$REMOTE_VERSION_INFO" | grep "^VERSION=" | cut -d'=' -f2)
    REMOTE_DATE=$(echo "$REMOTE_VERSION_INFO" | grep "^DATE=" | cut -d'=' -f2)
    REMOTE_CHANGES=$(echo "$REMOTE_VERSION_INFO" | grep "^CHANGES=" | cut -d'=' -f2)
    
    echo "Последняя версия в репозитории: $REMOTE_VERSION (от $REMOTE_DATE)"
    echo "Изменения: $REMOTE_CHANGES"
    FORCE_UPDATE=false
fi

# Функция сравнения версий
version_gt() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

# Проверяем, нужно ли обновление
if [ "$FORCE_UPDATE" = false ] && [ "$REMOTE_VERSION" = "$LOCAL_VERSION" ]; then
    echo ""
    echo "✅ У вас уже установлена последняя версия ($LOCAL_VERSION)"
    echo "Обновление не требуется."
    exit 0
elif [ "$FORCE_UPDATE" = false ] && version_gt "$REMOTE_VERSION" "$LOCAL_VERSION"; then
    echo ""
    echo "🔄 Доступна новая версия: $REMOTE_VERSION (текущая: $LOCAL_VERSION)"
    echo "Изменения: $REMOTE_CHANGES"
    echo ""
    echo "Хотите обновить? (y/n)"
    read -r answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "Обновление отменено пользователем"
        exit 0
    fi
elif [ "$FORCE_UPDATE" = true ]; then
    echo ""
    echo "⚠️  Выполняется обновление без проверки версии"
else
    echo ""
    echo "⚠️  Версии отличаются (локальная: $LOCAL_VERSION, удаленная: $REMOTE_VERSION)"
    echo "Хотите продолжить обновление? (y/n)"
    read -r answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "Обновление отменено пользователем"
        exit 0
    fi
fi

# Создаем временную папку для загрузки
TEMP_DIR=$(mktemp -d)
echo ""
echo "Создана временная директория: $TEMP_DIR"

# Переходим во временную директорию
cd "$TEMP_DIR" || exit 1

# Клонируем репозиторий
echo "Загрузка файлов из репозитория..."
git clone "$REPO_URL"

if [ $? -ne 0 ]; then
    echo "❌ Ошибка при клонировании репозитория"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Переходим в директорию с загруженными файлами
cd unity-steamdeck-project || exit 1

# Проверяем наличие файлов
echo "Проверка загруженных файлов..."
MISSING_FILES=0
for file in libdecor-0.so.0 libdecor-cairo.so my_project.x86_64 UnityPlayer.so; do
    if [ ! -f "$file" ]; then
        echo "❌ Отсутствует файл: $file"
        MISSING_FILES=1
    fi
done

if [ $MISSING_FILES -eq 1 ]; then
    echo "Ошибка: Не все необходимые файлы найдены в репозитории"
    echo "Найдены файлы:"
    ls -la
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Возвращаемся в директорию проекта
cd "$PROJECT_DIR" || exit 1

# Создаем резервную копию текущих файлов
BACKUP_DIR="${PROJECT_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
echo ""
echo "Создание резервной копии в: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Копируем существующие файлы в резервную копию
for file in libdecor-0.so.0 libdecor-cairo.so my_project.x86_64 UnityPlayer.so README.md; do
    [ -f "$file" ] && cp -f "$file" "$BACKUP_DIR/" 2>/dev/null && echo "  ✓ Сохранен: $file"
done

# Копируем папку с данными, если существует
if [ -d "my_project_Data" ]; then
    cp -rf my_project_Data "$BACKUP_DIR/" 2>/dev/null
    echo "  ✓ Сохранена папка: my_project_Data"
fi

echo "✅ Резервная копия создана"

# Копируем новые файлы
echo ""
echo "Копирование новых файлов..."
cp -f "$TEMP_DIR/unity-steamdeck-project/libdecor-0.so.0" ./ && echo "  ✓ libdecor-0.so.0"
cp -f "$TEMP_DIR/unity-steamdeck-project/libdecor-cairo.so" ./ && echo "  ✓ libdecor-cairo.so"
cp -f "$TEMP_DIR/unity-steamdeck-project/my_project.x86_64" ./ && echo "  ✓ my_project.x86_64"
cp -f "$TEMP_DIR/unity-steamdeck-project/UnityPlayer.so" ./ && echo "  ✓ UnityPlayer.so"

# Копируем папку с данными, если она существует в репозитории
if [ -d "$TEMP_DIR/unity-steamdeck-project/my_project_Data" ]; then
    echo "Копирование папки my_project_Data..."
    rm -rf my_project_Data 2>/dev/null
    cp -rf "$TEMP_DIR/unity-steamdeck-project/my_project_Data" ./
    echo "  ✓ my_project_Data"
fi

# Копируем README, если есть
if [ -f "$TEMP_DIR/unity-steamdeck-project/README.md" ]; then
    cp -f "$TEMP_DIR/unity-steamdeck-project/README.md" ./
    echo "  ✓ README.md"
fi

# Копируем version.txt для локального хранения
if [ -f "$TEMP_DIR/unity-steamdeck-project/version.txt" ]; then
    cp -f "$TEMP_DIR/unity-steamdeck-project/version.txt" ./
    echo "  ✓ version.txt"
fi

# Устанавливаем права на выполнение для исполняемых файлов
echo ""
echo "Установка прав на выполнение..."
chmod +x my_project.x86_64
chmod +x UnityPlayer.so
echo "✅ Права установлены"

# Сохраняем информацию о версии локально
if [ "$FORCE_UPDATE" = false ]; then
    cat > "$VERSION_FILE" << EOF
# Информация о версии проекта
LOCAL_VERSION="$REMOTE_VERSION"
LOCAL_DATE="$REMOTE_DATE"
LOCAL_CHANGES="$REMOTE_CHANGES"
UPDATE_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
EOF
    echo ""
    echo "✅ Информация о версии сохранена"
fi

# Удаляем временную директорию
echo "Очистка временных файлов..."
rm -rf "$TEMP_DIR"

# Проверяем результат
echo ""
echo "=== Обновление успешно завершено ==="
echo "📁 Содержимое директории проекта после обновления:"
ls -la

echo ""
echo "📋 Информация о версии:"
if [ "$FORCE_UPDATE" = false ]; then
    echo "  Установлена версия: $REMOTE_VERSION"
    echo "  Дата релиза: $REMOTE_DATE"
    echo "  Изменения: $REMOTE_CHANGES"
else
    echo "  Версия не определена (обновление без version.txt)"
fi
echo "  Дата обновления: $(date '+%Y-%m-%d %H:%M:%S')"

echo ""
echo "💾 Резервная копия сохранена в: $BACKUP_DIR"
echo "🚀 Для запуска игры выполните: ./my_project.x86_64"
echo ""
echo "⚠️  Если игра не запускается, вы можете восстановить резервную копию:"
echo "   cp -rf $BACKUP_DIR/* $PROJECT_DIR/"